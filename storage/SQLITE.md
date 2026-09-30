# SQLite 저장 1차 구현

언리얼 없이 `DurableInventory`를 실제 로컬 SQLite에 연결한다. `SQLiteStore(path)` 하나가 월드 파일 하나를 소유하며 객체 수명 동안 OS 배타 잠금을 유지한다. 경로의 부모 폴더는 호출자가 먼저 만든다. 동일 파일의 별칭은 canonical 경로로 처리하며, 하드 링크로 세이브를 공유하지 않는다.

```powershell
./scripts/setup-sqlite.ps1
./scripts/test-sqlite.ps1
```

공식 SQLite 3.53.4 소스를 `.tools`에 받고 해시를 검사한다. 검증한 SHA3-256과 SHA-256은 설치 스크립트에 기록했다. C 소스를 정적으로 링크하므로 실행 PC에 DB 서비스나 SQLite DLL 설치가 필요 없다. 빌드 옵션은 `SQLITE_THREADSAFE=1`, `SQLITE_OMIT_LOAD_EXTENSION`, `SQLITE_DQS=0`이다. [공식 배포](https://www.sqlite.org/download.html), [빌드 옵션](https://www.sqlite.org/compile.html).

```cpp
#include "sqlite.hpp"
astra::DurableInventory inventory(
    std::make_unique<astra::SQLiteStore>(savePath), seedCheckpoint);
// 인증된 호스트 경로에서 Access.epoch = inventory.epoch()로 설정한다.
auto result = inventory.apply(request, access);
// Pending이면 예약을 유지하고 resolve()로 확정 여부를 조회한다.
```

`BEGIN IMMEDIATE` 안에서 버전과 epoch를 확인하고 상태·요청 결과를 함께 저장한다. WAL/FULL/FK 설정값을 검사하며 COMMIT 성공 뒤에만 메모리 확정을 수행한다. 결과가 불명확하면 새 연결로 저장 버전과 체크포인트를 비교한다. [트랜잭션](https://www.sqlite.org/lang_transaction.html), [synchronous](https://www.sqlite.org/pragma.html#pragma_synchronous).

재시작은 DB/schema/catalog/체크포인트 불변식을 검사한 뒤 epoch와 origin을 증가시킨다. 기존 아이템과 tombstone의 origin도 피해 새 ID를 만든다. 이전 요청 결과와 계정 actionSeq를 복구하므로 재전송이 수량을 다시 바꾸지 않는다. 잘못된 세이브는 오류로 중단하며 seed로 덮어쓰지 않는다.

checkpoint는 일반 저장 v1, 탄약 컨테이너 없이 발사 기록만 있는 기존 저장 v2,
장전실/탄창이 있는 저장 v3를 지원한다. v3의 행 레이아웃은 같지만 구버전 reader가
새 위치를 일반 슬롯으로 해석해 덮어쓰지 않도록 버전으로 구분한다. 내용과 맞지 않는
버전은 거절한다. [장전실·혼합탄 저장 계약](../core/FIRE.md#장전실과-혼합탄-급탄).

검증은 재시작·중복/변조·거절 결과·ID 비재사용, SQL 실패 롤백, 응답 유실의 Pending/resolve, schema/catalog/손상/overflow 거절, 커밋 전후 프로세스 강제 종료, 다른 프로세스의 월드 잠금 및 강제 종료 후 해제를 포함한다. fixture는 매번 `.build/sqlite-tests-<GUID>`에 새로 생성한다.

HostSession 결합 시험은 SQL rollback에서 탄환/탄약 무변경, 확정 후 탄환 생성·정적 충돌,
DB 재시작 뒤 원본 발사 재전달의 중복 방지를 확인한다. Windows에서는 실제 TCP+SQLite로
응답 유실·연결 해제 중 저장 확정 조회·재접속 재전송도 검증한다.
[탄환 처리](../core/COMBAT.md)의 비행 상태·접촉 출력은 영속 피해 사건으로 저장하지 않는다.

현재는 기존 binary checkpoint 전체를 `world`의 한 행에 저장한다. 요청 결과도 그 안에 들어 있다. 정상 종료 API와 백업 3개 순환은 [종료·백업 안내](SQLITE_SHUTDOWN.md)에 구현했다. 명세 A.6/E.7의 정규화된 item/container/placement/event 테이블, 변경 행 저장과 손상 자산 격리는 후속 구현이다. 백업을 새 세이브로 여는 [복원 경로](SQLITE_RESTORE.md)는 제공한다. 비동기 worker·한 슬롯/64MiB 메시지 제한은 [AsyncStore](ASYNC.md)로 연결했다. 매 거래 전체 상태 직렬화 비용과 65,536 아이템·64 계정·65,536 요청 기록의 기존 코어 한도가 남는다. 실제 디스크 고장·전원 차단·대규모 성능 및 Windows 외 실행은 미검증이다.

콘솔은 `scripts/play.ps1 -SavePath ./saves/world.db`로 비동기 SQLite 저장을 사용한다. 경로를 생략하면 메모리 데모다. CMake의 `-DASTRA_SQLITE=ON`은 `astra_saved_demo`와 Windows CTest의 복구·콘솔 저장 시험을 활성화한다. 여기서 실제 검증한 경로는 Zig/PowerShell이다.
