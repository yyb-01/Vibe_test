# Astra Game — UE5 설치 전 C++ 코어

[기술 명세서](SURVIVAL_TECHNICAL_SPECIFICATION.md)의 A 영역부터 구현했습니다. C++20 표준 라이브러리만 사용하며 Unreal 없이 컴파일·테스트할 수 있습니다. 현재 실행물은 인벤토리를 조작하는 콘솔 샌드박스입니다.

v1.1의 목표는 **방장 PC 리슨 서버(방장 1명+참가자 최대 19명)**입니다. 방장이 판정·저장·자기 화면을 함께 실행하고, 로컬 SQLite를 게임에 포함해 별도 DB 서비스 설치를 없앱니다. 방장이 종료하면 세션도 종료되며 자동 방장 이전은 초기 범위에 없습니다. 실제 UE 방 생성/참가는 아직 미구현입니다. SQLite 체크포인트 저장·재시작 복구와 [정상 종료·백업 3개 순환](storage/SQLITE_SHUTDOWN.md)을 구현했으며 [실행과 한계](storage/SQLITE.md)를 별도로 기록했습니다.

## 실행

프로젝트 폴더의 PowerShell에서:

```powershell
./scripts/setup-toolchain.ps1
./scripts/build.ps1
./scripts/play.ps1
```

첫 명령은 공식 Zig 0.15.2 도구 모음 약 93MB를 `.tools`에 받고 SHA-256을 검사합니다. 시스템 설치나 PATH 변경은 없습니다. 이미 준비된 경우 다운로드하지 않습니다. 현재 워크스페이스에는 도구 모음이 준비되어 있습니다.

`build.ps1`은 실제 C++ 테스트를 실행합니다. `play.ps1`은 콘솔 데모를 빌드하고 실행합니다. 종료는 `quit`입니다.

```text
show
take 100 4 0
split 100 7 20 5 0
replay
merge 105 20 4 0
drop 100
take 100 4 0
swap 102 104
show
quit
```

컨테이너 10은 상자, 20은 플레이어 가방, 30은 바닥, 40은 아이템 102 안의 파우치입니다. `split` 출력의 `created`가 새 아이템 ID이며 위 105는 초기 샘플 기준입니다. `replay`는 마지막 요청을 그대로 재전송해 중복 적용이 없는지 확인합니다. 좌표는 0부터 시작합니다.

아이템 100/101/103은 탄약, 102는 가방, 104는 소총입니다. 데모의 외관·이동 공간은 콘솔 목록으로 표현됩니다.

## 구현 범위

- 명세서의 128bit ID, 64B ItemState/ContainerState, 48B Placement와 실제 컴파일 시 크기 검사.
- 그리드 회전, 슬롯, 바닥 위치, 중첩 깊이 4, 루트당 1,024개·직접 자식 256개 제한.
- 질량·외부 점유 부피·클래스 제한, 순환 참조·정수 overflow 검증.
- 이동/교환/분할/병합/드롭/줍기, tombstone, 전체 실패 롤백, 불변 읽기 스냅샷.
- 거래 준비/확정/취소 API, 불변 변경 집합(변경 전후 행·영향 루트·요청·결과), 대기 중 중복/충돌 처리.
- 루트별 예약, 독립 루트의 동시 대기, 영향 루트만 복사하는 시뮬레이션, 역순 확정 시 변경 보존.
- 루트별 불변 스냅샷 공유, 거래 확정 시 전체 복사·추가 메모리 할당 제거, 준비 할당 실패 시 무변경.
- 계정별 요청 중복 방지, 같은 ID의 payload 변조 거절, epoch·revision·순서·루트 접근권한 검증.
- 명세서 A.4의 44B 요청 머리말과 88B 항목을 명시적 little-endian으로 직렬화. 잘린 패킷·예약 비트·상한 위반 거절.

## 보증 경계

`Inventory::apply`의 성공은 **메모리에 적용됨**입니다. 로컬 디스크 영속 커밋을 뜻하지 않습니다. 종료하면 데모 상태와 중복 요청 기록은 사라집니다. SQLite 재시작 복구는 별도 `DurableInventory`/`SQLiteStore` 경로로 검증했습니다. 콘솔 데모 연결, 네트워크 인증·거리/LOS 검사, 낙하 Actor, UI는 아직 구현하지 않았습니다.

`Access`는 방장 PC의 인증된 권위 실행 경로가 만들어야 합니다. 클라이언트가 권한 목록을 제출하는 API가 아닙니다. 방장 로컬 입력도 같은 검증을 거칩니다. 전체 `snapshot()`도 서버용이며 원격 사용자에게 그대로 송신하면 안 됩니다. 순서 있는 거래 채널 기준으로 actionSeq는 1씩 증가하며, 정상 형식의 거절 결과도 해당 순서를 소비합니다. 방장 자체의 메모리/세이브 변조를 막는 보증은 없습니다.

생성자 `idOrigin`은 epoch와 별개인 아이템 ID 상위 64bit입니다. 운영 호스트는 영속 저장소에서 부팅마다 고유한 origin을 할당해야 합니다. 샘플의 고정 origin=1은 독립 데모용입니다.

거래 준비는 루트 인덱스에서 영향 루트와 그 자손만 복사해 검증합니다. 서로 다른 계정의 독립 루트 거래는 함께 대기할 수 있습니다. 확정은 미리 할당한 변경 행과 루트 스냅샷을 교체하며 World 전체를 복사하지 않습니다. API 내부 실행은 mutex 하나로 보호합니다. CPU에서의 동시 시뮬레이션, 방장 PC의 렌더링 포함 시간 예산 검증, SQLite 변경 행 저장은 아직 남아 있습니다. [AsyncStore](storage/ASYNC.md)는 DB I/O를 전용 worker로 옮기고 메모리 확정을 호출 스레드에 유지합니다. 확장 상태가 있는 stack의 분할/병합, 유연 가방 압축, 무기 Socket 장착은 지원하지 않습니다.

## C++ 거래 준비 API

기존 `apply(request, access)`는 준비와 메모리 확정을 한 번에 실행합니다. 호스트가 두 단계를 나누려면 다음 API를 사용합니다.

```cpp
auto prepared = inventory.prepare(request, access);
if (prepared.changes) {
    // prepared.result.code == Error::Pending; snapshot()은 아직 이전 상태다.
    const astra::WriteSet& changes = *prepared.changes;
    // changes.outcome은 성공 또는 검증 거절을 담고, sequence는 아직 0이다.
    // 이 예제는 메모리에서만 확정한다.
    auto result = inventory.commit(prepared.changes);
}
```

`WriteSet`은 정렬된 영향 루트, account/request ID, epoch/actionSeq, 정규 wire payload와 제안된 결과, 실제 달라진 item/container/placement 행을 담습니다. 행의 `before`가 없으면 삽입, `after`가 없으면 삭제입니다. 병합으로 사라진 스택은 item tombstone과 placement 삭제로 함께 표현됩니다. POD padding을 비교하거나 직렬화하지 않습니다.

계정당 대기 거래는 하나이며, 출발·도착의 최상위 루트를 함께 예약합니다. 중첩 파우치를 옮기거나 비우는 요청도 해당 최상위 루트와 충돌합니다. 계정 또는 루트가 겹치면 `Busy`를 반환하며 actionSeq를 소비하지 않습니다. 다른 계정의 독립 루트는 함께 준비하거나 `apply`로 즉시 반영할 수 있습니다. 같은 요청의 재전송은 같은 불변 핸들과 `Pending`을 반환하고, 대기 거래에 `apply`를 호출해도 조기 확정하지 않습니다. `commit`을 중복 호출하면 같은 최종 결과를 반환합니다. 검증 거절은 루트를 예약하지 않으며, 확정할 때 결과를 기억하고 actionSeq를 소비합니다.

성공한 준비에는 epoch 내 고유한 `WriteSet::event`를 부여하며, 분할 아이템의 `birthEvent`에 같은 값을 사용합니다. 이는 확정 순번과 별개입니다. 준비된 `outcome.sequence`는 0이고, `commit`이 반환하는 `Result.sequence`가 실제 반영 순서대로 증가합니다. 예를 들어 event 2를 먼저 확정하면 sequence 1, event 1을 나중에 확정하면 sequence 2입니다. 거절 결과는 확정 당시 sequence를 기억하되 증가시키지 않습니다. 요청 codec의 44+88N 바이트 형식은 그대로입니다.

호스트는 확실한 취소에만 `abort(handle)`를 호출합니다. 취소 후 같은 requestId/actionSeq로 다시 준비할 수 있으며, 이미 노출된 분할 아이템 ID와 event는 재사용하지 않습니다. 취소한 거래의 예약만 해제하므로 다른 대기 거래는 그대로 유지됩니다. 저장 결과가 불명확하다면 핸들을 유지해야 합니다. 핸들은 해당 Inventory에서 받은 원본만 유효하며 취소된 핸들·복사해서 만든 핸들·다른 Inventory의 핸들은 확정할 수 없습니다.

복사한 시뮬레이션 상태에는 영향 루트의 활성 아이템만 들어갑니다. 전역 65,536개 아이템 한도는 기존 tombstone과 대기 중 분할 생성분까지 합쳐 검사합니다. 요청 결과 65,536개·계정 64개 한도도 대기 거래의 예약분을 포함합니다. 대기 예약 때문에 한도에 닿으면 재시도 가능한 `Busy`, 확정된 데이터만으로 한도에 닿으면 `LimitExceeded`입니다.

이 API는 서버 내부용입니다. 비동기 DB 연결은 `AsyncStore`로 제공하며 클라이언트 연결은 아직 없습니다. `commit` 역시 **메모리 반영**만 보장하며 디스크 저장을 수행하지 않습니다. 최신 상태에 변경된 행만 합치므로 독립 거래가 먼저 확정돼도 그 결과를 덮어쓰지 않습니다. 준비 도중 메모리 할당이 실패하면 상태·예약·ID·순서를 변경하지 않고 `std::bad_alloc`을 전달하며, 같은 요청으로 재시도할 수 있습니다. 정상적인 확정 경로에는 추가 할당이 없습니다. 영속 요청 결과·프로세스 강제 종료 복구는 별도 SQLite 경로에서 구현했으며, 실제 부하 측정은 다음 단계입니다.

## 루트별 읽기 스냅샷

```cpp
auto view = inventory.snapshot_roots({astra::Id{1, 10}, astra::Id{1, 20}});
// 두 루트가 같은 확정 시점에 관측된다. view.sequence는 해당 시점의 확정 순번이다.
const astra::World& chest = *view.roots.at(astra::Id{1, 10});
```

`snapshot_roots`는 선택한 최상위 루트의 불변 World를 공유합니다. 행 데이터를 복사하지 않으며, 바뀌지 않은 루트는 이전 스냅샷과 같은 객체를 사용합니다. 가방 이동 시 자손 컨테이너와 내용물도 함께 새 루트로 이동합니다. 보관한 이전 스냅샷은 이후 거래와 무관하게 유지됩니다. 잘못된 ID나 중첩 컨테이너 ID를 루트로 지정하면 `InvalidState`를 반환하는 `Violation`을 던집니다.

루트 스냅샷에는 활성 아이템과 그 위치만 포함됩니다. 위치가 없는 tombstone은 내부 전역 인덱스에 남습니다. 기존 `snapshot()`은 tombstone을 포함한 전체 World가 필요한 호환·검사용 API이며, 호출 시 전체 복사가 필요할 수 있습니다. 같은 버전의 전체 스냅샷을 읽는 사용자가 아직 보관 중이면 그 객체를 재사용합니다. 일반적인 부분 조회에는 `snapshot_roots`를 사용합니다. 두 API 모두 서버 내부용이며, 호스트가 접근권한을 확인한 뒤 필요한 데이터만 원격 사용자에게 전달해야 합니다.

메모리에는 내부 행 인덱스와 루트별 활성 데이터가 함께 존재합니다. 읽기 스냅샷을 오래 보관하면 해당 루트의 이전 버전도 유지됩니다. 전체 복사를 확정 경로에서 제거한 것이며, 게임 전체의 메모리·60Hz 처리 예산을 검증한 것은 아닙니다.

## UE5 연결

`core` 소스를 Unreal Game 타깃의 모듈에서 다시 컴파일해 리슨 서버의 권위 경로에서 호출합니다. 권위 코드를 `UE_SERVER` 전용 분기로 감싸지 않습니다. Zig/MinGW 바이너리를 MSVC 엔진에 직접 링크하지 않습니다. 현재 코어는 예외를 사용하므로 해당 모듈의 `bEnableExceptions = true`가 필요합니다. 엔진 연결은 아직 검증하지 않았습니다.

CMake 3.20+와 C++20 컴파일러가 있으면 `cmake -S . -B .build/cmake`, `cmake --build .build/cmake`, `ctest --test-dir .build/cmake -C Debug --output-on-failure`도 사용할 수 있습니다. 실제 검증한 경로는 Windows Zig 빌드입니다.

세부 진행 상황은 [구현 현황](IMPLEMENTATION_STATUS.md)에 기록합니다. 명세서 산술 검사는 기존 `verify_spec.py`로 별도 실행합니다.
