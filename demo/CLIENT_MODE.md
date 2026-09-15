# 저장 콘솔의 클라이언트 프로토콜 모드

```powershell
./scripts/play.ps1 -SavePath ./saves/client-world.db -ClientMode
```

새 모드는 기존 콘솔 명령을 사용하며 다음 흐름을 한 프로세스 안에서 실행한다.

1. SQLite 복구 후 HostSession과 ClientState 생성
2. 새 명령의 원래 payload를 ClientState에 보관
3. 요청 packet codec → HostSession의 계정/lease/요청 제한 검사
4. AsyncStore → SQLite 저장, 불명확한 결과는 원래 요청으로 재확인
5. 70B 응답 codec → ClientState의 최종 상태 보존
6. 허용 루트 스냅샷 → 페이지 codec → 클라이언트 재조립/검증 → show와 다음 명령의 읽기 상태

`show`와 명령 파싱은 이 모드에서 DurableInventory의 전체 World를 직접 읽지 않는다. 새 명령 전에 lease와 클라이언트 뷰를 갱신한다. 새 논리 명령의 requestId는 actionSeq와 별개로 증가하며 replay/resolve는 기존 payload를 유지한다.

관측값은 콘솔의 고정 샘플 장면이다. 방장 1명과 프로세스 내부 참가자 1명, 샘플 루트 10/20/30, 고정된 거리/LOS/권한을 사용한다. 인터넷/LAN 통신, 실제 공간 계산, 인증, remote 참가를 구현한 것은 아니다. 실행 시 이를 배너에 표시한다.

명령 결과의 `created`와 오류 이름은 기존 콘솔과 같은 **호스트 진단 출력**이다. 실제 네트워크 상태 응답에는 created ID나 내부 오류를 추가하지 않는다. 화면의 아이템 목록은 검증된 공개 스냅샷만 사용한다.

## 대기와 종료

콘솔은 Pending 결과를 최대 2초 재확인하고 미완료이면 사용자가 resolve/replay를 실행할 수 있게 유지한다. 요청 제한에 걸린 재시도도 최종 거절로 바꾸지 않는다. 페이지 admission은 최대 2초 동안 100ms 간격으로 재시도한다. 엔진 연결에서는 이 대기를 틱별 비차단 처리로 바꿔야 한다.

quit/EOF는 클라이언트의 미확정 명령을 먼저 정리한다. 이후 HostSession의 admission 중단·저장 종료·백업 경로를 사용한다. 완료되지 않으면 성공 종료를 표시하지 않는다.

ClientMode를 생략한 메모리/직접 SQLite 모드는 계속 사용할 수 있다. ClientMode에는 SavePath가 필요하며, RestoreBackup과 함께 새 경로에서 실행할 수도 있다.

## 검증

```powershell
./scripts/test-demo.ps1 -ClientMode
```

분할·원본 replay·프로세스 재시작·128bit ID·잘못된 입력/배치 이후 다음 거래·병합·EOF 종료·백업 순환/복원·손상 파일 보존을 검사한다. 25번 연속 replay로 예산을 소진한 뒤에도 확정 결과가 유지되고 다음 거래와 공개 스냅샷이 정상 반영되는지 추가 검사한다. 기본 저장 모드의 동일 테스트와 메모리 `--smoke`도 별도로 실행했다.

## 연결 해제와 재접속

ClientMode에서 disconnect는 참가자 연결 번호와 lease를 폐기하고 클라이언트 표시를 지운다. 요청 원본은 보존한다. reconnect는 새 연결 번호와 재개 정보 codec을 사용하고, 미확정 요청을 먼저 재확인한 뒤 새 lease와 공개 스냅샷을 갱신한다. 오프라인 show/replay는 NotAccessible로 거절한다.

submit split 100 7 20 4 0처럼 submit을 붙이면 저장 완료를 기다리지 않는다. 이어서 disconnect, reconnect, replay로 복구를 시험할 수 있다. 연결이 끊긴 상태의 quit/EOF도 미확정 요청이 있으면 내부 재접속으로 정리한 뒤 저장소를 닫는다. 실제 소켓이나 플랫폼 인증을 사용하는 원격 접속은 아니다.

통합 테스트는 미확정 요청 제출 직후 해제, 오프라인 접근 거절, 재접속/replay 후 수량 보존, 다음 거래 순번, 재시작 복구 및 오프라인 종료를 검사한다.

새 거래의 actionSeq는 저장소를 직접 읽지 않고 SessionResume 패킷 왕복으로 조회한다. 미확정 요청이 남아 있거나 연결이 끊겨 있으면 새 순번 조회를 거절한다. 이전 응답과 계정/월드/catalog, epoch를 대조하고 저장·요청 순번 후퇴를 검사한다. 조회도 계정 요청 예산을 소비하며 콘솔에서 제한된 시간 동안 재시도한다. 거절 후 재접속과 연속 재접속 이후 다음 거래를 통합 테스트로 검증한다.

종료 중 재접속·저장 작업이 예외를 던져도 대화형 콘솔은 세션을 유지하고 Shutdown incomplete와 Retry quit 안내를 표시한다. 사용자는 quit을 다시 실행할 수 있다. EOF에서는 반복 대기하지 않고 실패 코드로 종료한다. 예외·Pending 이후 성공하는 종료 재시도는 주입된 종료 함수로 검증한다.
