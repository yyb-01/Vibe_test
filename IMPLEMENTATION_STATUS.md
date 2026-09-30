# 구현 현황

## 2026-09-30 현재 코드 기준

현재 실행 제품은 **C++20 인벤토리 콘솔 샌드박스**다. 현재 루트의 소스·호출 경로·실행 시험을
명세 v1.1의 G.1/G.6과 대조했다. **UE 연동을 제외해도 전체 게임은 미완성**이다.
과거 54.2%/62.5%는 2026-09-14 체크리스트 집계이며 현재 개발·출시 완료율로 사용하지 않는다.

| 영역 | 작성·연결된 범위 | 남은 범위 |
|---|---|---|
| A 인벤토리 | POD·그리드/슬롯·중첩·질량/부피, 6종 거래, 예약·확정/취소, 권한·버전·중복 방지·불변 뷰 | 조립 Socket/Escrow, 확장 상태 스택, 유연 가방, 낙하 Actor·실제 UI |
| A/E 저장 | SQLite WAL/FULL, 상태+요청 결과 원자 저장, 비동기 worker, 재시작·epoch 복구, 정상 종료·백업 3개·새 파일 복원 | 전체 checkpoint BLOB 쓰기와 단일 in-flight 작업; 행별 DB delta·게임 부하 |
| 세션·네트워크 | 방장 포함 20슬롯 정책, lease·페이지·재접속·종료 통지, 양쪽 transport·마감, Windows TCP byte adapter와 loopback | 실제 인증·방 검색/참가·채널 결합·암호화·NAT/relay·LAN/인터넷·다중 PC·종료 수신 ACK |
| B 발사 | FireIntent 34B/패킷 66B, 권위 후보 검증, 탄약·내구도·ShotData 공동 저장, 세션 시계/sequence 복구, 40/98B 응답·64개 클라이언트 원본 추적, 확정 후 탄환 1회 생성 | 실제 net ID↔item/profile/pose/FSM/clock 공급자, 자동 사격·열/고장, 충돌의 영속 피해 처리 |
| B 장전·탄창 | 실제 1발 장전실, Move/Split 장전, socketId 순서의 혼합탄 급탄·상태 보존, 최대 32발, checkpoint v1/v2/v3 호환 검사 | 탄약 family/profile·조립 소켓 호환·전체 장전 FSM |
| B 탄도 | 정수 scalar 자유비행·AABB 연속 교차, 수명/사거리·보수적 정지, 도탄 gate/에너지 표·반사, 관통 시간·진행·출구 재개, 세션 점 탄환의 240Hz 배치·접촉 정렬 | 접촉→관통 자동 선택, 겹친 layer의 시간 진행, 탄약별 profile·history/rewind·BVH/triangle·Mach LUT·SIMD parity·실제 게임 호출 루프 |
| C 방어구·생체 | 정적 AABB layer 조회·같은 body 구간 합집합·에너지 계획 | 보호 zone·국소 손상·wound·출혈·사망·대사·섭취·환경 시뮬레이션 |
| D 차량 | 명세와 기준 산술만 | 부품 조립·COM/관성·휠/동력계·주행/충돌·예측/복제·Chaos |
| E 제작·전력·하우징 | 저장 기반만 | recipe/job/stage/escrow·원자적 완료/취소·전력/열/소음·구조/설치물 |
| 월드·좀비 | 명세와 좀비 컨셉 이미지 | 활성 영역·셀 pin·스트리밍·좀비 AI·월드 사건·20인 게임 부하 |
| F 에셋 | 명세·컨셉 이미지/prompt | manifest validator·socket/PBR/LOD·golden scene·승인 registry·플랫폼 cook |
| UE | 미설치·미연동 | 리슨 서버·관측·입력/위젯·렌더·PIE/cook·엔진 성능 검증 |

코드 근거: [거래](core/inventory.cpp), [저장](storage/sqlite_save.cpp),
[세션 발사](core/session_fire.cpp), [장전실](core/chamber.cpp), [탄창](core/magazine.cpp),
[발사체](core/projectile.cpp), [반사](core/reflection_loop.cpp), [관통 출구](core/volume_resume.cpp),
[layer 계획](core/layer_energy.cpp), [서버 탄환 처리](core/COMBAT.md), [TCP](net/tcp_stream.cpp).

## 이번 실행 검증

2026-09-30 현재 소스로 Zig 0.15.2/C++20을 다시 빌드해 아래 검사를 통과했다.

| 명령 | 결과·범위 |
|---|---|
| `./scripts/build.ps1` | 코어 103그룹 PASS |
| `./scripts/test-tcp.ps1` | Windows loopback TCP 6그룹 PASS |
| `./scripts/test-sqlite.ps1` | rollback·lost ACK·혼합탄 순서·재시작·커밋 전후 강제 종료·잠금·백업/복원, 세션 탄환·실제 TCP+SQLite 발사 PASS |
| `./scripts/test-demo.ps1` / `-ClientMode` | 현재 저장 데모 재빌드 후 기본/ClientMode 저장·재접속·백업 복원 PASS |
| `./scripts/test-demo-idle.ps1` / 데모 `--smoke` | 부분 입력 중 tick·reconnect·열린 stdin의 quit·메모리 모드 PASS |
| `verify_spec.py` | 25 POD layout·17 sizeof·기준 산술·문서 SQL PASS; 기능 구현 시험과 구분 |

TCP 6그룹은 ProbeStore를 사용한다. 별도 SQLite 시험에서 실제 loopback TCP+SQLite의 단일 발사,
응답 유실·재접속·디스크 재시작 중복 방지를 검증했다. 20명 시험은 한 프로세스의 호스트와
19개 어댑터다. 실제 20대 PC·게임 프레임/메모리 예산·물리적 전원 차단·UE/다른 OS는 미검증이다.
CMake 타깃은 제공하며 이번 실제 빌드 경로는 Windows Zig다.

GitNexus `Vibe_test`의 등록 경로를 현재 루트와 대조하고 `analyze --pdg --index-only`로 갱신했다.
초기 전체 감사에서 context·100개 함수/메서드 upstream impact·taint/PDG를 소스와 대조했다.
저장 codec/validator의 HIGH/CRITICAL, 24개 UNKNOWN을 안전 판정으로 해석하지 않았다.
초기 전체 감사의 `detect_changes(scope: all)`은 148개 파일·817개 symbol·31개 흐름,
위험도 CRITICAL을 보고했으며 partial/truncated는 없었다. 위 소스 검토와 실행 검증으로 보완했다.
C++ 헤더/가상·멤버 호출 누락, 지역 변수 오탐과 100 execution flow 상한이 있다.
taint 0건은 결함 부재의 증명이 아니다. [프로젝트 지도](docs/GITNEXUS_PROJECT_MAP.md),
[남은 작업](docs/IMPLEMENTATION_QUEUE.md)을 다음 작업의 시작점으로 사용한다.
이번 전투 후속 수정 전체 29개 파일의 커밋 전 검사는 90개 symbol·7개 흐름·HIGH를 보고했고
partial/truncated는 없었다. publish_fire의 로컬/원격/저장 조회 경로와 UNKNOWN인
advance_combat의 실제 호출 위치를 대조했다. 탄도·저장·TCP 검토에서 재시작 시험의
성공 상태/원본 데이터 검사를 보강했다. 비행 상태는 세션 메모리이며 피해 사건 저장은 남았다.

## 이전 구현 기록 — 각 날짜 당시의 상태와 수치

2026-09-30 후속: durable 확정 발사를 세션의 점 탄환과 240Hz 정적 충돌/도탄 처리에 연결했다.
Pending/실패는 발사하지 않으며 응답 유실·재접속 뒤에도 한 번만 생성한다. 코어 103그룹,
TCP 6그룹과 실제 TCP+SQLite 결합·SQLite 전체 회귀 통과. 저장 데모 ClientMode/idle도 재검증했다.
탄약별 profile·관통 자동 진입·역사 rewind·영속 피해/사망·실제 게임 호출 루프·UE는 남아 있다.

2026-09-30 후속: 장전실의 실제 1발 위치와 혼합탄 탄창을 기존 Slot·아이템 스택에 연결했다.
장전/급탄은 Move 또는 Split이며 발사 확정 직전에도 장전실을 재검사한다.
코어 99그룹, TCP 6그룹, SQLite 전체 시험 통과. 장전 취소·혼합탄/상태 순서·응답 유실·
재시작과 발사 커밋 전후 강제 종료를 검증했다. 현재 탄창은 최대 32발이다.
새 탄약 컨테이너 저장은 checkpoint v3로 표시하며 기존 v1/v2 읽기와 버전 변조 거절을 검증했다.
탄약 family/profile·조립 소켓 호환·전체 장전 FSM·자동 발사·피해·UE는 남아 있다.

2026-09-30 후속: 서버가 계정별 발사 sequence와 무기별 steady clock 간격을 유지하고
applied 발사 기록에서 세션 재시작 이력을 복구한다. 코어 94그룹 통과.
저장 대기/실패·재접속·clock reset을 검증했다. 장전 FSM·자동 발사 타이머·피해·UE는 남아 있다.

2026-09-30 후속: ClientState/ClientTransport에 발사 상태·원본 입력·재전송을 연결했다.
코어 92그룹과 TCP 6그룹 통과. 연결 유실 뒤 같은 입력/shotId, 상충 응답 거절,
탄약 화면 갱신을 검증했다. 실제 무기/FSM·효과/피해 소비·UE 통합은 남아 있다.

2026-09-30 후속: 40/98B FireReceipt와 시각 효과용 ShotAccepted를 HostTransport에 연결했다.
코어 91그룹과 Windows TCP 6그룹에서 코덱·1바이트 분할·발사 대기·재접속·동일 shotId를 검증했다.
ClientTransport 발사 추적·실제 관측/FSM·피해 소비·UE 연결은 남아 있다.

2026-09-30 후속: FireIntent 66B 패킷과 HostSession의 로컬/원격 사격 진입점을 추가했다.
계정/fireSeq 원본 조회로 비동기 대기·재접속 재시도를 연결했고 코어 90그룹이 통과했다.
실제 무기 관측/FSM·TCP 사격 분기·ShotAccepted wire·피해 소비는 남아 있다.

2026-09-30: 발사 데이터·탄약·내구도 원자적 SQLite 저장을 연결했다. 코어 89그룹, TCP 5그룹,
SQLite 발사 rollback·응답 유실·재시작·커밋 전후 강제 종료 복구를 통과했다.
실제 무기 FSM·발사 세션 라우팅·피해 적용과 UE 연결은 남아 있다. [저장 계약](core/FIRE.md).

2026-09-29 현재: 코어 88그룹 통과. 반사·관통 상태 재개, 겹친 layer의 조직 경로 합집합과
에너지 계획, [FireIntent·서버 후보 검증](core/FIRE.md)을 추가했다. 실제 발사 승인 사건과
탄약/내구도 영속 커밋, 피해·역사 proxy·UE 통합은 아직 미구현이다. 아래 날짜별 수치는 당시 기록이다.

2026-09-28 후속: 정수 비행과 정적 장애물 충돌을 [발사체 루프](core/PROJECTILES.md)로 연결했다.
곡률 1/2/4/8분할·반경 여유·동률 순서·6초 수명·2.5km 사거리·재충돌 방지를 검증했고
코어 86그룹이 통과했다. 불투과 박스의 보수적 정지이며 관통/도탄·피해·저장·UE는 미연결이다.
정수 나눗셈 최적화와 `std::gcd` 약분으로 자유비행 합성 측정 p50은 17.17→1.92ms였다.
유효한 비행의 계산 범위 초과는 `Limit` 정지로 처리하며, 잘못된 입력과 구분한다.
[측정 범위](docs/BALLISTICS_PERFORMANCE.md)는 실제 게임 프레임 성능과 구분한다.

2026-09-28: Windows nonblocking TCP byte transport와 loopback 테스트 5그룹 통과.
부분 I/O·커널 backpressure·거래/스냅샷/종료·재접속 중복 방지·오류 정리를 검증한다.
실제 인증·LAN/인터넷 참가·SQLite 소켓 부하·다중 PC 시험은 아직 없다. [TCP](net/TCP.md).
정수 128bit 중간 곱/반올림/제곱근과 240Hz 자유비행 scalar reference를 추가하여
정적 박스 연속 충돌과 관통/도탄 에너지 장부까지 포함해 코어 83그룹이 통과했다.
비행/충돌 루프·역사 proxy·발사 승인·피해·SIMD·UE 연결은 남아 있다.
[탄도 구현 경계](core/BALLISTICS.md), [전체 작업 큐](docs/IMPLEMENTATION_QUEUE.md).

2026-09-23 입력 대기 tick: 표준 입력만 별도 스레드로 옮기고 소유 스레드에서 약 10ms마다
기존 transport_tick을 실행한다. 부분 입력 중에도 시간 제한·스냅샷 lease 만료를 감지하며
연결 해제 후 reconnect로 복구한다. quit/EOF의 기존 저장 정리 순서와 원본 요청을 유지한다.
코어 79그룹, 입력 지연/부분 명령/열린 stdin에서 quit, 기본·ClientMode 저장/백업 복원,
메모리 smoke 검증을 통과했다. 명령 내부 대기·입력 취소·실제 소켓/인증·UE 통합은 남아 있다.
[실행 계약](demo/CLIENT_MODE.md).

2026-09-23 다중 참가자 전송 검증: 호스트 1명과 원격 어댑터 19개를 같은 세션에 연결했다.
20명 정원·연결별 부분 송수신·한 연결 정체 시 나머지 스냅샷 진행·재접속 토큰 격리·전체 종료를
검증한다. 같은 아이템을 요청한 두 계정의 Busy 재시도·버전 충돌·최종 응답 유실 후 중복 저장
방지와 모든 클라이언트의 최신 스냅샷도 확인했다. `scripts/build.ps1`의 코어 78그룹 통과.
프로세스 내부 전송과 테스트 저장소를 사용하며 실제 소켓·인증·다중 PC/SQLite 부하 시험은 아니다.
후속 범위는 표준 입력 대기 중 지속 tick, 실제 플랫폼 인증/소켓 선택 및 연결, UE 관측값·메뉴 통합이다.

2026-09-21 실행 루프: 콘솔 ClientMode를 HostTransport/ClientTransport의 부분 송수신 경로에 연결했다.
명령 양방향·스냅샷 채널마다 tick당 256B를 전달하고 시간 제한·페이지 Busy·실패 정리를 처리한다.
재접속 resume와 정상 종료 통지도 같은 스트림을 사용한다. 소켓·인증·표준 입력 대기 중의 tick은
구현하지 않았으며 다음 actionSeq 조회는 기존 신뢰된 프로세스 내부 resume codec 경로를 유지한다.
[실행 계약](demo/CLIENT_MODE.md).
코어 76개 테스트 그룹과 ClientMode 저장·재접속·백업 복원·24회 연속 조회 검증을 통과했다.

2026-09-21 시간 제한: HostTransport/ClientTransport에 poll 기반 고정 작업 마감을 추가했다.
초기 resume·미완성 명령·미송신 명령·스냅샷 전체 전송을 제한하며 느린 부분 진행으로 연장하지 않는다.
만료 시 연결·버퍼·뷰를 정리하고 미확정 거래 원본은 Resolving으로 보존한다.
기본 30초이며 유휴 연결은 유지한다. 플랫폼의 tick/소켓 연결과 별도 거래 응답 대기 정책은 남아 있다.
코어 74개 테스트 그룹과 콘솔 ClientMode 저장·백업 복원 검증을 통과했다.
[시간 제한 계약](core/TRANSPORT.md#전송-시간-제한).

2026-09-21 후속: SnapshotRequest/Offer codec으로 lease·승인 루트·descriptor를 전달하고
전용 스트림의 부분 송수신과 기존 페이지 재조립을 연결했다. 대기 페이지도 매 송신 직전
현재 권한을 재검사하며 실패 시 연결을 해제한다. 페이지 생성 Busy는 진행 상태를 유지한다.
코어 71개 테스트 그룹과 콘솔 ClientMode 저장·백업 복원 회귀 검증을 통과했다.
실제 관측값·tick/소켓·인증·종료 ACK·UE 통합은 남아 있다. 전송 시간 제한은 위 항목에 추가했다.
[스냅샷 transport 계약](core/SNAPSHOT_TRANSPORT.md).

2026-09-21 추가: ClientTransport가 인증된 연결의 SessionResume/receipt/종료 통지를
검증하고 요청 원본을 부분 송신한다. 연결 토큰으로 이전 callback을 차단하고 재접속 시
원본 요청을 재전송한다. HostTransport::shutdown은 저장 대기가 정리된 뒤 통지를 보내며
송신 완료 시 peer를 해제한다. 코어 67개 테스트 그룹 통과.
스냅샷 채널은 위 후속 항목에 추가했다. 실제 인증·소켓·시간 제한·종료 ACK·UE 통합은 남아 있다.
[클라이언트 어댑터 계약](core/CLIENT_TRANSPORT.md).

2026-09-18 추가: 플랫폼 공통 HostTransport로 인증 결과와 연결 ID를 결합하고
SessionResume/요청/receipt를 스트림에 연결했다. 한 프레임 송신 대기, 부분 송신,
EOF/오류 시 슬롯 해제와 새 연결의 원본 요청 재전송을 처리한다.
당시 후속 범위였던 종료 통지 전달은 위 2026-09-21 항목에 구현했다.
코어 64개 테스트 그룹 통과. [어댑터 계약](core/TRANSPORT.md).

2026-09-16 추가: 인증된 논리 스트림용 4B 길이 prefix/StreamDecoder를 구현했다.
분할/결합 수신, 프레임당 메모리 한도, 잘못된 길이와 절단 EOF를 처리한다.
요청→영속 응답→스냅샷→종료를 1바이트 단위 전달로 검증했으며 코어 62그룹을 통과했다.
실제 소켓·인증·송신 큐·연결 시간 제한은 미구현이다. [스트림 계약](core/STREAM.md).

2026-09-16 추가: E.8 정상 종료 통지 코어를 구현했다. `SessionClosing` 40B codec과
`ClientState::receive_shutdown`을 콘솔 ClientMode에 연결했다. 저장 대기 정리 이후에만
통지하며, 수신 시 뷰를 지우고 원본 요청·최종 결과를 보존한다. 통지 순번은 개별 거래
성공이나 백업 완료로 해석하지 않는다. 코어 테스트는 60개 그룹으로 증가했다.
실제 transport 전달·ACK/재전송·UE 메뉴 전환은 남아 있어 아래 전체 완료율은 유지한다.

기준: `SURVIVAL_TECHNICAL_SPECIFICATION.md` v1.1(2026-09-08). 방장 PC 리슨 서버와 로컬 SQLite 저장을 목표로 하며, UE5 미설치 환경에서 독립 C++ 코어를 먼저 작성한다.

2026-09-14 체크리스트 완료율: **54.2% (완료 13/24)**. 부분 완료 4개를 각각 0.5로 계산하면 **62.5% ((13+4×0.5)/24)**다. 초기 범위 제외 1개는 분모에서 뺀다. 아래 항목의 동일 가중치이며 게임 전체의 개발 시간·출시 준비율이 아니다.

| 집계 범위 | 완료 | 부분 | 미구현 | 부분 포함 진행률 |
|---|---:|---:|---:|---:|
| 독립 빌드부터 루트 스냅샷까지 | 11 | 0 | 0 | 100% |
| 대규모 성능부터 비동기 DB까지 | 2 | 4 | 0 | 66.7% |
| 리슨 서버부터 에셋 파이프라인까지 | 0 | 0 | 7 | 0% |

이번 검증 최적화로 완료 항목 수는 바뀌지 않는다. 체크포인트 검증의 전체 아이템·배치 복사를 제거하고 컨테이너별 부모 경로를 재사용했다. 60,000개 직렬화·검증 p50은 121.363→68.618ms로 약 43.5% 감소했다. 이후 비동기 거래의 전체 체크포인트 생성·직렬화·미확정 결과 비교를 worker로 옮겼다. 6만 아이템 제출 p50 0.072ms, 메시지 예산 5,136B다. SQLite 전체 체크포인트 쓰기는 남아 있어 완료 항목 수는 동일하다. 측정 조건·편차는 [성능 기록](storage/PERFORMANCE.md)에 남긴다.

| 단계 | 상태 | 근거 / 다음 완료 조건 |
|---|---|---|
| C++20 독립 빌드 | 완료 | Zig 로컬 빌드, CMake 구성 제공 |
| A 아이템/컨테이너 POD | 완료 | 실제 컴파일 static_assert |
| A 그리드/슬롯/중첩/질량/부피 | 완료 | `core/validate.cpp`, `grid.hpp`, `ancestry.cpp` |
| A 메모리 원자적 거래 | 완료 | 이동·교환·분할·병합·드롭·줍기, 실패 시 무변경 |
| A 중복/권한/순서/버전 검사 | 완료, 프로세스 범위 | `core/inventory.cpp`, `check_request.cpp` |
| A 거래 payload codec | 완료 | 44+88N byte, 길이/예약 비트/개수 검사 |
| 직접 조작 콘솔 | 완료 | `scripts/play.ps1`, 기본 메모리 모드와 `-SavePath` 비동기 SQLite 저장 모드 |
| 콘솔 영속 저장 연결 | 완료 | 재시작 요청 순번 복구·128bit ID 입출력·Pending 재확인·quit/EOF 종료·백업 3개; `scripts/test-demo.ps1`; `-ClientMode`로 HostSession/ClientState/packet/페이지 왕복 통합 |
| A 불변 변경 집합/준비·확정 분리 | 완료, 프로세스 범위 | `prepare`/`commit`/`abort`, 변경 전후 행·요청·결과, 대기/중복/취소 처리 |
| A 루트별 병렬 예약/부분 복사 | 완료, 준비 단계 | 계정당 대기 1개·독립 루트 동시 대기, 영향 루트만 시뮬레이션, 최신 상태에 변경 행 병합 |
| A 루트 스냅샷/확정 전체 복사 제거 | 완료 | 루트 인덱스·불변 버전 공유, 변경 행 사전 할당, 추가 할당 없는 확정; 전체 snapshot은 요청 시 복사 |
| A 대규모 처리 성능 개선 | 부분 완료 | 거래 경로의 전체 순회·복사 제거; API 내부 mutex 1개, 실제 게임 틱·메모리 예산 미측정 |
| 저장 성능 기준선 | 합성 측정 완료 | 100~60,000 아이템·단계별 p50/p95·저장 결과 검증; 전체 체크포인트 복사/codec 비용 확인. [결과](storage/PERFORMANCE.md) |
| A SQLite 영속 커밋/복구 | 1차 구현 | `SQLiteStore`·WAL/FULL·OS 월드 잠금·체크포인트/요청 결과 원자적 저장·재시작 복구; 행별 저장은 남음; AsyncStore 연결 가능. [실행/검증](storage/SQLITE.md) |
| E.8 정상 종료/백업 | 저장 경로 구현 | `close()` admission 중단·Pending resolve·검증된 Backup API 사본·정상 백업 3개·실패 재시도; UE 종료 통지는 남음; 비동기 종료 연결 완료. [상세](storage/SQLITE_SHUTDOWN.md) |
| E.8 백업 복원 | 구현 | 검증된 백업을 새 파일에 게시·원본 보존·별도 lineage 실행·기존 경로/잠금/손상 거절. [복원 안내](storage/SQLITE_RESTORE.md) |
| A/E.8 비동기 DB/대기열 | 1차 구현 | 단일 worker·호출 스레드 확정·메시지 64MiB/한 슬롯·지연 상태·Pending/종료 재시도; 변경 집합 메시지·worker에서 전체 목표 비교 구현; SQLite 전체 쓰기·다중 거래 큐는 남음. [상세](storage/ASYNC.md) |
| A 분산 2PC/교차 월드 거래 | 초기 범위 제외 | 월드별 단일 DB 원자적 거래로 처리; 명세 A.7 |
| 리슨 서버 방 만들기/참가/종료 | 접속 정책 코어 구현, 엔진 통합 미구현 | 방장 1+원격 19명 슬롯·handshake/계정/Pawn 검사·종료 admission/저장 재시도; 실제 인증/NAT/relay·종료 통지는 남음. [정책 계약](core/SESSION.md) |
| A 네트워크/UI | 기반 codec/명령·lease 정책 구현, 통합 미구현 | 32B 헤더·epoch/MTU·ACK·거래 제한·연결별 lease·거리/LOS 관측값 검사·권한 범위 조회·폐기 후 결과 재확인; 70B 상태 응답/공개 오류 구현; 권한 범위 스냅샷/페이지/재조립 구현; 클라이언트 요청 추적/원자적 게시 구현; 실제 인증·UE 관측값·transport·위젯/이벤트 연결은 남음. [wire 계약](core/NETWORK.md) / [lease](core/INTERACTION.md) |
| B 총기/탄도 | 독립 코어 부분 구현 | 정수 탄도·관통/도탄 장부·발사 후보 검증·탄약/내구도/사건 원자 저장; 조립·FSM·세션 사격·피해·rewind·UE는 남음 |
| C 방어구/생체 | 미구현 | 보호 zone, wound, 대사·환경 |
| D 차량 | 미구현 | 질량/관성, 구동계, Chaos 및 예측 연결 |
| E 제작/전력/하우징 | 미구현 | escrow, stage 저장, 구조/환경 사건 |
| F AI 에셋 파이프라인 | 명세만 존재 | 실제 asset validator/cook/조립 검사 |

2026-09-15: 명세 2.2의 공통 패킷 헤더와 ACK 윈도를 추가했다. 네트워크/UI 전체 완료 조건은 충족하지 않아 위 완료율 집계는 유지한다.

같은 날 HostSession의 접속·명령·종료 정책을 추가했다. 20개 슬롯, 인증 후 handshake 비교, 계정/Pawn 중복 방지, 재접속 시 연결 번호 폐기와 요청 예산 유지, 로컬/원격 공통 영속 경로, 종료 실패 재시도를 검증했다. 엔진 없는 코어 범위이며 실제 원격 세션 완료로 집계하지 않는다.

이어서 열람 lease 발급·교체·만료·폐기와 루트별 권한 조회를 구현했다. 세션은 외부 Access 대신 현재 서버 관측값을 받으며, 이미 접수된 거래는 lease가 사라져도 자기 계정의 원래 payload로 결과를 확인한다. 실제 UE raycast·좌표·권한 데이터 연결은 남아 있다.

70B 거래 상태 응답을 추가했다. 요청/응답 공통 헤더 검사를 공유하고 내부 오류를 공개 reason으로 정규화한다. 저장 미확정과 요청 제한은 최종 거절로 바꾸지 않는다. 상태 확인 범위이며 변경 행/스냅샷 전송과 클라이언트 UI는 남아 있다.

권한 범위 공개 스냅샷 직렬화와 reliable stream용 페이지 codec·재조립을 추가했다. 페이지마다 권한을 재검사하며 64KiB 프레임·2MiB payload 상한과 연결별 단일 전송본을 유지한다. 실제 소켓/플랫폼 transport와 클라이언트 게시 연결은 남아 있다.

클라이언트 ClientState를 추가했다. 요청 원본 8개 추적·timeout/지연 응답·확정 상태 보존과 승인 루트/epoch/순번 검사 후 스냅샷 원자적 게시를 구현했다. 실제 위젯·권한 철회/재접속 이벤트와 transport 연결은 남아 있다.

콘솔에 선택형 ClientMode를 연결했다. 고정 장면에서 요청 packet→HostSession→SQLite→응답 codec→ClientState와 공개 스냅샷 페이지→표시를 실행한다. 기본/클라이언트 저장 모드의 재시작·백업 복원 시험, 요청 예산 소진 후 replay/다음 거래, 메모리 smoke를 검증했다. 실제 소켓·인증·UE 관측값은 여전히 미구현이다.

재접속 상태 코어를 추가했다. 서버가 연결 계정의 재개 정보를 생성하며 클라이언트는 연결 해제 시 요청 원본을 보존하고 계정/월드/catalog 변경과 epoch/순번 후퇴를 거절한다. 저장 대기 중 재접속 후 단일 확정과 합성 메타데이터를 사용한 새 epoch 전환을 검증했다. 실제 인증·재접속 transport 연결은 남아 있다.

재개 정보 전송 codec을 추가했다. messageType=3의 112B 패킷으로 계정/월드/catalog와 순번을 전달하고 인증된 handshake epoch를 검사한다. 콘솔 초기 연결에 직렬화 왕복을 적용했으며 절단·추가 바이트·잘못된 ID/순번·MTU·메시지 거절과 SQLite 클라이언트 저장/백업 복원을 검증했다. 실제 transport와 인증은 남아 있다.

검증: C++ 58개 테스트 그룹(콘솔 종료 재시도 포함). 이번 변경은 기본/클라이언트 콘솔 프로세스 시험과 메모리 smoke로 검증했다. 클라이언트 요청/뷰·여러 페이지 게시·영속 응답 연동 검사 포함. 스냅샷 공개 데이터·2MiB 재조립·페이지 권한 철회 검사 포함. 응답 wire·상태 조합·오류 매핑·영속 세션 왕복 검사 포함. lease 범위·만료·철회 후 Pending/replay·원장 결과 조회 검사 포함. 접속 정책·거래 예산·로컬/원격 명령·재접속·종료 보존 검사 포함. 패킷 헤더·epoch/MTU·절단/오염·거래 replay·순번 래핑 검사 포함. Delta codec·분할/병합/거절 재구성·변경 전 행 충돌·호출 스레드 할당/메시지 크기 독립성·epoch/전체 목표 불일치 fencing 검사 포함. 검증 성공·실패 시 원본 보존, 가방 이동 후 부모 경로 재계산, 없는 컨테이너·cycle 거절 포함. 계정 요청 순번 조회·준비/취소·중복·거절 후 복구 검사 포함. 콘솔 프로세스 시험은 재시작·replay·전체 ID·입력 범위·거절 후 다음 거래·EOF·백업 순환·손상 세이브 보존을 검증한다. 비동기 저장 정체·호출 스레드 확정·미확정 종료·큐 크기/지연 경계·예산 거절 롤백 검사 포함. 체크포인트 codec/복구/손상 검사 포함. 실제 스레드 20개 동시 루팅, 무작위 거래 1,000회 수량·질량 보존, snapshot 불변성, 중복 요청/변조, 원자적 swap/실패 rollback, 중첩 권한/cycle/depth, 조건 불일치 merge, 32bit 전체 폭 grid, slot 중복, 수량·질량 overflow, 패킷 절단/오염. 준비 API 검증은 snapshot 유지, 변경 집합으로 최종 상태 재구성, split/merge/tombstone/자손 depth 포함, 취소 후 동일 요청 재시도와 ID 미재사용, 외부/위조/취소 핸들 거절, 거절 결과 확정, Busy의 순서 미소비, 잘못된 순서 요청의 계정 한도 미소비, 20스레드 동시 준비·중복 확정이다.

루트 예약 검증은 독립 루트 20개 동시 준비·확정, 역순 split 확정과 event/확정 순번 분리, 대기 중 독립 `apply`, 교차 루트 획득 실패·취소 시 예약 누수 방지, 중첩 아이템 루트 충돌, 거절 결과의 루트 비예약, 대기분을 포함한 계정 64개 한도, tombstone 65,533개를 포함한 전역 아이템 한도와 대기 split 생성분 예약이다. 준비 시 부분 복사와 확정 시 기존 스냅샷·독립 변경 보존을 함께 확인했다.

스냅샷 검증은 변경되지 않은 루트의 객체 공유, 가방·자손의 루트 이동, tombstone 분리, 읽기 스레드 3개와 swap 200회의 일관성이다. 테스트 실행물에서만 메모리 할당을 주입·계측하여 확정·중복 확정·거절 확정·취소의 추가 할당 0회와, split 준비의 각 할당 지점 실패 후 상태·예약·ID·event 무변경 및 동일 요청 재시도를 확인했다. 계측 코드는 게임 코어와 데모에 연결되지 않는다.

방장 1명+19개의 실제 원격 연결, 렌더링을 포함한 방장 PC 60Hz 예산, 20만 아이템 부하, Windows 외 플랫폼, 실제 디스크 고장·전원 차단, UE/콘솔 빌드는 아직 시험하지 않았다. SQLite SQL 롤백·응답 유실·커밋 전후 프로세스 강제 종료·프로세스 간 월드 잠금, 정상 종료·백업 3개 순환·백업/정리 실패 재시도와 실제 SQLite 비동기 저장·재시작·종료 백업을 별도 통합 테스트로 검증했다. v1.1 명세를 기준으로 SQLite 체크포인트 저장 경로를 추가했으며, 상용 멀티플레이어 게임 전체가 완성된 상태는 아니다.

게임 코어에는 외부 라이브러리를 추가하지 않았다. 별도 SQLite adapter는 해시를 고정한 공식 SQLite 3.53.4를 정적으로 포함하며 DB 서비스 설치가 필요 없다. 개발 도구는 [Zig 공식 배포](https://ziglang.org/download/index.json)의 고정 버전/해시를 사용한다. 도구 모음과 빌드 결과는 `.gitignore`에서 제외한다.

콘솔 ClientMode에 disconnect/reconnect와 비대기 submit 명령을 연결했다. 내부 참가자 연결을 폐기·재발급하고 미확정 결과 확인 후 lease/스냅샷을 갱신한다. 실제 transport와 인증은 미구현이다.

클라이언트 새 거래의 actionSeq 조회를 SessionResume codec 경로로 전환했다. 직접 DurableInventory 조회를 제거하고 연결/미확정 요청/식별자/순번을 검사한다. 기본·클라이언트 SQLite 통합 테스트와 거절 후 재접속·다음 거래 순번 검증을 통과했다.

콘솔 종료 중 재접속/저장 예외를 종료 시도 내부에서 처리한다. 대화형 quit 실패 후 세션을 유지해 재시도하고 EOF는 실패 코드로 종료한다. 예외/Pending/성공 순서의 주입 테스트와 기본·클라이언트 SQLite 프로세스 시험을 통과했다.

E.8 종료 준비 단계를 분리했다. DurableInventory/HostSession의 prepare_close는 admission 차단과 Pending 확정 후 DB를 열린 상태로 유지한다. 콘솔은 내부 클라이언트 연결 해제 후 close로 백업/DB 닫기를 진행한다. 준비 단계에서 DB close가 호출되지 않는지, 반복 준비·신규 거래 차단·최종 종료 실패 재시도를 검증했다. 실제 UE/transport 참가자 통지는 남아 있다.
