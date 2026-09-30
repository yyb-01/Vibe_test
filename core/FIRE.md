# 발사 입력과 후보 검증

`fire_intent.*`는 사양 B.6의 34B를 padding 없이 little-endian으로 직렬화한다.
inputSeq/fireSeq/clientFireTick은 u32 wrap을 허용한다. yaw는 65536 단위/회전이고
pitch는 ±16384(±90°)다. buttons 1은 trigger-on, 2는 trigger-off이며 다른 값은
예약되어 거절한다. generation 0도 유효하다. 클라이언트는 총구 위치·탄속·피해를 보내지 않는다.

`validate_fire_candidate`는 부작용 없이 유효한 발사 후보의 서버 시각을 반환한다.
`FireAuthority`는 인증된 연결, 소유 무기와 현재 조립 revision, 장전실/FSM,
역사 pose와 몸→총구 차폐 검사, 승인된 clock estimator에서 구성해야 한다.
payload를 이 구조체에 복사해 권위 값으로 사용하면 안 된다. 이 상태 공급자는 아직 미연결이다.

시간은 60Hz의 unwrapped Q16 tick이다. 원격 clientFireTick에는 서버가 승인한 정수
offset을 적용하고 미래 입력, 보간 지연 포함 12프레임 초과, 유효 시각 역전을 거절한다.
view delay는 서버 승인값과 같아야 한다. 로컬 방장은 입력 tick과 remote offset을
사용하지 않고 서버 now를 발사 시각으로 쓴다. 승인된 화면 보간 지연은 유지한다.
lastAcceptedQ16은 수신/승인 시각이며 최소 발사 간격은 이 값에 적용하여 지연 burst를 막는다.
inputSeq/fireSeq의 비교는 기존 half-range serial 규칙을 사용한다.

trigger-off는 wire에서 표현하지만 사격 후보가 아니다. 자동화기 trigger 상태·서버 타이머는
다음 통합 단계다. `hasPrevious`와 이전 시각/sequence는 클라이언트가
초기화할 수 없다. 재시도는 검증 전에 영속 결과를 조회해야 하며 새 사격으로 적용하면 안 된다.

이 API는 `ShotAccepted`를 발행하지 않는다. 후보를 원자적으로 예약/재검증하고 탄약·
내구도·shot event를 같은 critical 커밋에 저장한 뒤에만 탄도/피해를 공개해야 한다.
2026-09-30: `Operation::Fire`의 탄약·내구도·발사 데이터 영속 경로를 연결했다.
HostSession의 FireIntent dispatch와 HostTransport의 TCP 분기를 연결했다.
무기 FSM/프로파일 공급과 피해 처리는 아직 미연결이다.

## 원자적 발사 저장

서버가 두 MoveEntry(지정 탄약, 무기)를 현재 행 revision으로 구성한다. 각 수량은 1이고
source=target, 좌표/socket/rotation은 0이다. `ShotData`에는 34B intent, 권위 launch 위치/속도,
질량·유효 시각·ammoDef·visualSeed·내구도 비용을 넣는다. `approve_fire`는 후보 검증 후
정확한 요청 바이트를 Access에 결합한다. item ID↔net ID, 장전실 탄약, launch/profile은 서버가
제공해야 하며 클라이언트의 완성된 Request를 승인하면 안 된다.

Inventory가 권한·행 revision·루트 예약을 다시 검사하고 탄약 1개와 내구도를 같은 변경 집합으로
차감한다. 지정 탄약은 해당 무기의 실제 장전실에 있는 수량 1인 아이템이어야 한다.
가방의 느슨한 탄약 스택은 승인 바이트가 있어도 발사할 수 없다.
소비된 탄약은 tombstone과 placement 제거로 처리한다. 요청 payload 자체가 발사
데이터 기록이며 기존 SavedRequest 결과와 같은 SQLite 커밋에 저장된다. applied 결과의
sequence가 해당 월드의 shotId다. 거절 기록은 발사 사건이 아니며 Pending 동안 메모리도 미공개다.

Fire 요청 ID는 `{fire_request_namespace, fireSeq}`로 고정하여 동일 계정의 같은 fireSeq가
다른 requestId로 재소비되지 않게 한다. account actionSeq는 인벤토리와 함께 진행한다.
기존 result_for/재시도/복구 경로를 재사용한다. 기록 한도 65,536건은 기존과 같으며 대규모
실전 배포에는 사건 압축·retention 설계가 필요하다.

일반 거래 바이트는 그대로다. Fire 저장 요청은 operation=6, 확장 version=1, 2개 MoveEntry와
108B ShotData로 총 328B다. 일반 InventoryRequest 패킷의 encode/decode는 Fire를 거절한다.
일반 checkpoint는 v1, 새 탄약 컨테이너 없이 발사 기록만 있는 기존 저장은 v2다.
장전실/탄창이 있으면 비어 있어도 v3를 쓴다. v1/v2/v3를 읽으며 내용에 맞는 버전만
허용한다. 기존 reader는 v3를 거절하므로 새 탄약 위치를 일반 슬롯으로 해석해 덮어쓰지 않는다.

실행 검증: 코어 `atomic fire commit`, `./scripts/test-sqlite.ps1`의 발사 rollback/lost ACK/
재시작 및 fire-crash-before/fire-crash-after/fire-recover. 커밋 뒤 [서버 탄환 처리](COMBAT.md)는
정적 충돌 출력까지 연결했다. 영속 피해 event·사망/loot 순서화와 비행 상태 복구는 남아 있다.

## 사격 세션 진입점

`encode_fire_packet`/`decode_fire_packet`은 MessageType=7의 32B 공통 헤더와 34B intent를
사용한다. `HostSession::receive_fire`와 `fire_local`은 연결의 account/Pawn을 결합하고
기존 admission/요청 예산을 적용한다. 클라이언트가 account, 로컬 여부, launch 데이터를 정하지 않는다.

새 발사는 신뢰된 `FireObservation`에서 무기/탄약 ID와 소유 인벤토리 root, pose/clock/FSM/
프로파일을 받는다. 해당 root의 현재 불변 snapshot으로 두 항목과 revision을 구성하고
원자 저장에 제출한다. Fire의 내부 lease 값은 epoch이며, 상자 열람 lease를 발사 권한으로 쓰지 않는다.
관측의 ammo ID는 실제 장전실 원장과 같아야 한다. chambered 캐시는 발사 권한을 부여하지
않으며 세션이 현재 원장에서 다시 계산한다. 관측 공급자는 권위 weapon net ID↔item ID
매핑, 나머지 FSM과 profile/pose를 제공해야 한다.
세션은 아래 승인 이력과 cooldown을 유지하며 외부 관측의 hasPrevious 값을 사용하지 않는다.

`recorded_fire(account, fireSeq)`는 저장/대기 중인 원본을 조회한다. 재시도는 intent 전체가
원본과 같아야 하며 현재 관측이 바뀌어도 원본 revision·launch로 결과를 해결한다. 다른 계정은
같은 fireSeq의 기록에 접근하지 못한다. 새 연결로 재시도할 수 있고 폐기된 연결은 거절한다.

서버 내부 `FireResult.accepted`는 durable Ok에서만 존재한다. Pending/실패에서는 비어 있다.
동일 결과를 재전달하므로 효과 소비자는 월드와 result.sequence로 중복을 제거해야 한다.
HostTransport가 아래 wire 응답으로 변환하고 ClientTransport가 추적/재전송한다.
확정 결과는 서버 탄환 처리에서 한 번 소비한다. 시각 효과와 자동화기 서버 타이머는 남았으며
현재 입력은 기존 공통 예산
(초당 10회, burst 20)을 공유한다.

검증: `fire session admission`은 비동기 대기·재접속·변조·계정/Pawn 격리·로컬 rollback을
검사한다. SQLite 복구 후 `recorded_fire`가 저장 당시 원본을 반환하는지도 검사한다.

## TCP 발사 응답

MessageType=8의 FireReceipt는 공통 헤더 32B 뒤 fireSeq(u32), status(u8),
reason(u16), reserved=0(u8)를 담는다. 상태/거절 이유는 기존 거래 receipt와 같다.
Committed만 ShotAccepted 58B를 추가한다. 따라서 대기/거절/불확실 응답은 40B,
승인은 98B다. ShotAccepted 순서는 shotId(u64), fireSeq(u32), launchTick(u32),
assemblyRevision(u64), 3축 origin, 3축 direction(i16), speed(u16), ammoDef(u32), visualSeed(u32)다.
각 origin 축은 125m cell(i16)과 cell 안의 μm 위치(u32, 0 이상 125000000 미만)다.
direction은 SNORM32767, speed는 0.1m/s 반올림 짝수 규칙이며 권위 피해 계산에 쓰지 않는다.
launchTick은 저장된 effectiveQ16의 정수부 하위 32비트다. 작은 속도도 정규화 정밀도를 유지한다.

HostTransport::receive의 마지막 FireObservation은 인증된 소켓 어댑터가 매번 최신 권위
관측으로 공급한다. 기본 빈 관측은 새 발사를 승인하지 않는다. 기존 거래 경로는 그대로다.
실제 Windows loopback에서 1바이트 분할, Pending, 연결 유실, 빈 관측으로 원본 재시도,
같은 shotId 재전달과 한 번만 탄약 차감을 검증한다. 시험은 실제 ClientTransport의
submit_fire/retry_fire와 응답 추적을 사용한다. UE 사격/시각 효과 소비는 아직 미연결이다.

## 클라이언트 발사 추적

ClientState는 최대 64개 입력을 원본 FireIntent와 함께 보관한다. 동일 fireSeq의 다른
입력은 거절하며 Pending/Resolving은 삭제할 수 없다. disconnect는 미확정 입력을
Resolving으로 바꾸고 원본과 최종 결과를 유지한다. 새 인증 연결의 동일 world/account/
catalog 및 단조 epoch/sequence 확인 뒤에만 재전송한다. 오래된 connection token은 거절한다.

FireReceipt의 assemblyRevision은 원본 입력과 같아야 한다. 중복 최종 응답은 상태를
다시 바꾸지 않고, 상충하는 최종 결과는 연결 오류다. 승인 shotId로 인벤토리 snapshot의
확인 sequence를 갱신하여 탄약/내구도 화면 갱신을 요구한다. 승인·거절은 forget_fire로
해제할 수 있으며 클라이언트가 fireSeq를 재사용해서는 안 된다. 추적 중 Rejected의
재전송은 거절한다. 후보 거절은 영속 발사 기록이 아니므로 새 시도에는 새 fireSeq를 쓴다.
현재 입력/결과는 클라이언트 프로세스 메모리에 있으며 프로세스 재시작 복구는 별도 요구다.

검증: core `client fire tracking`, Windows TCP `TCP durable fire receipt/reconnect`.
효과 호출자는 해당 월드의 shotId로 중복을 제거한다. 이 모델은 피해를 예측/적용하지 않는다.

## 서버 승인 이력과 시계

HostSession은 계정별 마지막 승인 inputSeq/fireSeq와 현재 세션의 effective 시각을 유지한다.
무기 item ID별 cooldown은 인증 입력과 동일한 서버 steady clock에서 측정한다. profile의
minIntervalQ16(60Hz Q16)을 올림 nanosecond로 변환한다. 외부 nowQ16을 앞당기거나
hasPrevious를 false로 제공해도 cooldown을 건너뛰지 못한다. 다른 무기는 자기 간격을 쓴다.

후보의 입력/무기를 준비한 뒤 기록 공간과 대기 슬롯을 먼저 확보한다. Pending 동안 새 발사를
보류한다. 확정된 Ok에서만 cursor/cooldown을 갱신하며 요청을 처음 받은 서버 시각을 쓴다.
실패 결과를 확인하는 같은 재시도 호출은 실패를 반환한다. 다음 명시적 호출에서만 다시
제출하므로 저장 실패를 숨기거나 미확정 입력을 자동 재소비하지 않는다. 재접속은 이력을 유지한다.

recorded_fires는 공개된 applied 기록만 반환한다. session 시작 시 여기서 가장 큰 shotId의
계정 sequence와 각 무기의 이력을 복구한다. 이전 epoch의 effective tick은 비교하지 않고,
복구된 무기는 새 서버 steady 시계에서 한 번의 최소 발사 간격을 기다린다. startup 때 최대
65,536개 기존 기록을 한 번 순회한다. 오래된 동일 요청 재전달은 cooldown을 다시 시작하지 않는다.
저장 포맷은 그대로다. 전체 장전 FSM·자동화기 trigger 타이머·열/고장·피해 소비는 아직 남아 있다.

검증: `server fire clock`의 최소 간격 경계, 관측 시각 가속, 다른 무기, rollback와 재접속;
`server fire clock recovery`의 새 epoch/엔진 시각·sequence 복구. SQLite 재시작 후 applied
발사 이력과 Pending 중 비공개도 검사한다.

## 장전실과 혼합탄 급탄

ContainerState.flags의 bit 0은 장전실, bit 1은 탄창이며 동시에 설정할 수 없다.
둘 다 partDefId/containerDefId가 있는 소유 아이템의 Slot이다. 같은 아이템에 같은 종류의
컨테이너를 두 개 만들 수 없다. 저장·snapshot·delta의 기존 flags와 아이템 행을 사용한다.
행 레이아웃은 유지하고 checkpoint v3로 새 의미를 표시한다.
다른 컨테이너에는 이 규칙을 적용하지 않는다.

장전실은 width=height=1이고 단순 탄약 아이템 한 개만 허용한다.
`chamber_request`는 비어 있는 장전실로 한 발을 옮긴다. 스택이 남으면 Split,
마지막 한 발이면 Move다. 준비된 변경은 공개되지 않으며 확실한 취소에서는 위치가 유지된다.
발사 후에는 비어 있으므로 다음 발사 전에 별도 장전/급탄 거래가 필요하다.

탄창은 socketId가 작은 run부터 소비한다. 각 run은 ammoDef와 내구도·오염·습기·온도가
동일한 기존 아이템 스택이다. Split은 상태값을 복사하고 마지막 Move는 원래 ID를 유지한다.
서로 다른 탄약/상태 run을 급탄 중 합치거나 정렬하지 않는다. width는 run 슬롯 수,
height는 총 탄 수 한도이며 width≤height≤32다. 부피·질량 한도도 기존 validator가 검사한다.

`feed_request`는 무기 소유의 일반 Slot에 직접 장착된 탄창에서만 첫 run 한 발을 선택한다.
분리된 탄창·빈 탄창·이미 찬 장전실에서는 급탄하지 않는다. 클라이언트가 제공한 새 발사
원본을 그대로 승인하지 않으며 탄약 family/profile과 장착 소켓 호환은 별도 권위 공급자가
검사해야 한다. 해당 콘텐츠 공급자와 ExtractMagazine→InsertMagazine→Chamber→Ready의
전체 장전 FSM, 자동 발사 타이머·열/고장·UE 연결은 아직 미구현이다.

검증: `chamber ledger validation`, `chamber load/fire/recovery`, `magazine ledger validation`,
`mixed magazine feed/fire/recovery`, `ammunition checkpoint versions`;
SQLite의 장전 실패·응답 유실·급탄/발사 후 재시작.
