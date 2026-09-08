# 비동기 DB 처리

`AsyncStore`는 기존 `DurableStore`를 전용 스레드 하나에서 실행한다. SQLite 월드 열기·복구·저장·결과 조회·백업·닫기가 이 스레드에서 처리된다. `DurableInventory`의 검증·예약·메모리 확정은 호출 스레드에 남는다. worker에 전달하는 데이터는 직렬화된 체크포인트 사본이며 살아 있는 Inventory나 UObject를 전달하지 않는다.

```cpp
#include "async_store.hpp"
#include "sqlite.hpp"
std::unique_ptr<astra::DurableInventory> inventory;
astra::AsyncStore* queue{};
auto opening = std::make_unique<astra::AsyncStore>(
    [savePath] { return std::make_unique<astra::SQLiteStore>(savePath); }, seed);
// 이후 로딩 틱에서 ready()를 한 번씩 확인한다. false면 다음 틱까지 기다린다.
if (opening->ready()) {
    queue = opening.get(); // inventory가 살아 있는 동안만 유효하다.
    inventory = std::make_unique<astra::DurableInventory>(std::move(opening), seed);
}
```

새 명령은 기존 `apply(request, access)`로 제출한다. DB 작업이 접수되면 `Pending`이며 이때 스냅샷은 바뀌지 않는다. 이후 틱에서 `resolve()`를 한 번씩 호출하면 저장 확인 뒤 호출 스레드가 확정하고 최종 결과를 돌려준다. `ready()`는 초기 복구 실패를 예외로 전달하므로 실패 시 참가를 허용하지 않는다. AsyncStore API는 생성한 스레드에서 호출해야 한다.

대기·완료 메시지를 합쳐 **한 슬롯, 64MiB**로 제한한다. 고정 관리 공간 4KiB를 예약하고 vector의 실제 capacity를 검사한다. 한 거래가 진행 중이면 새 거래는 `Busy`이며 기존 requestId의 재전송·변조 검사는 유지된다. 메시지가 한도를 넘으면 `LimitExceeded`로 명시적으로 거절하고 메모리 예약을 취소한다. 확정 순서와 actionSeq는 소비하지 않는다.

`queue->status()`는 메시지 크기, 진행 여부, 경과 시간과 압력 단계를 제공한다. `steady_clock` 기준으로 250ms 초과 Warning, 1초 초과 Throttled, 2초 초과 또는 결과 미확정은 Stopped다. 현재 한 슬롯 정책은 작업 진행 중 새 거래를 모두 거절하므로 각 지연 단계에서도 신규 거래가 누적되지 않는다. UI 경고 표시는 UE 연결 시 사용한다.

저장 응답을 잃으면 worker가 영속 상태를 조회한다. 조회도 실패하면 `Pending`과 예약을 유지하며 다음 `resolve()`에서 조회만 재시도한다. 저장 명령을 임의로 중복 실행하지 않는다. 저장 자체가 롤백됐다고 확인하면 `StorageUnavailable`을 반환하고 같은 요청을 재시도할 수 있다.

종료는 틱마다 `close()`의 결과를 확인한다. 처음부터 새 명령을 막고 미확정 거래를 정리한 뒤 worker에서 백업·닫기를 수행한다. `Pending`이면 다음 틱에서, 오류이면 원인을 해결한 뒤 재시도한다. 소멸자는 실행 중 worker를 join하므로 종료 결과 확인 전에 게임 틱에서 객체를 파괴하지 않는다. 자세한 보존 정책은 [정상 종료](SQLITE_SHUTDOWN.md)를 따른다.

검증은 `scripts/build.ps1`의 비동기 4개 그룹과 `scripts/test-sqlite.ps1`의 실제 저장·재시작·백업 경로에 포함한다. DB 정체 시 API 진행, worker 완료 후 호출 스레드의 확정, 중복 방지, 응답 유실·종료 실패 재시도, 크기 상한과 지연 경계값을 검사한다.

현재 전체 체크포인트 생성·직렬화와 복구 결과 비교는 호출 스레드에서 수행한다. 64MiB는 메시지 예산이며 복호화된 월드·시뮬레이션·읽기 스냅샷의 메모리는 별도다. 명세의 60Hz 예산을 충족했다는 의미는 아니다. 변경 행 저장, 여러 거래의 큐잉, UE 틱/UI 연결, 대규모 처리량 측정은 후속 항목이다.
