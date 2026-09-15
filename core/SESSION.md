# 리슨 서버 접속·명령 정책 — 명세 0.2 / 2.2 / E.8

`HostSession`은 복구된 `DurableInventory` 위에서 실행하는 소유 스레드 전용 코어다. 실제 방 검색·소켓·인증 SDK·NAT/relay를 구현한 것은 아니다. UI가 공개 방을 표시하기 전에 저장 복구와 이 코어 생성을 완료해야 한다.

## 접속

- 생성 시 방장 계정/Pawn을 connection 1에 등록한다. 최대 인원은 방장 포함 20명이다.
- `SessionInfo`의 session/world/host ID, protocolVersion, catalogHash, identity 구분을 인증된 handshake와 비교한다. epoch는 복구된 저장소에서 가져온다. catalogHash는 호스트의 승인된 catalog에서 제공해야 한다.
- `admit_authenticated`에는 플랫폼 ticket 검증을 완료한 계정과 **서버가 배정한 Pawn**만 전달한다. 이 함수 자체는 인증하지 않는다. 검색 메타데이터나 클라이언트 계정/Pawn 주장을 그대로 넘기면 안 된다.
- Platform과 LocalLan 식별자는 섞지 않는다. 동일 계정 또는 동일 Pawn의 중복 접속은 거절한다.
- 반환된 connection 번호는 서버 transport 연결에 보관한다. 클라이언트가 전송한 connection 번호로 사용자를 선택하지 않는다.
- 연결 해제 후 같은 계정도 새 번호를 받는다. 이전 번호는 재사용하지 않는다. 방장 종료에는 `disconnect` 대신 `close`를 사용한다.

## 거래

인증된 연결의 `resume_state(connection)`은 서버에 묶인 계정·월드·catalogHash, 현재 epoch·확정 순번·계정의 다음 요청 순번을 반환한다. 클라이언트가 계정을 지정하지 않는다. 이 조회도 계정 요청 예산과 종료 admission을 적용한다. [클라이언트 재접속](CLIENT.md)에 사용하는 신뢰된 제어 정보이며 실제 인증·wire 전송은 호출자가 연결해야 한다.

원격 입력은 `receive(connection, bytes, state, pathBudget)`, 방장은 `apply_local(request, state)`로 처리한다. 둘 다 계정별 10회/초·burst 20과 동일한 영속 거래 경로를 거친다. 서버의 steady clock만 사용하며 패킷의 senderTick을 제한 계산에 사용하지 않는다.

손상 패킷·거절·replay도 요청 예산을 소비한다. 재접속해도 계정 예산은 유지한다. 기록은 기존 Inventory 원장과 같은 64개 계정 상한으로 제한한다. 새 계정 admission이 상한에 닿으면 `LimitExceeded`이며 기존 계정 재접속은 가능하다.

`InteractionState`에는 호스트가 현재 월드에서 관측한 Pawn·거리·LOS·생존/작업·루트별 권한을 전달한다. 세션이 [연결별 lease](INTERACTION.md)를 발급·검사·폐기하고 내부에서 Access를 만든다. 실제 UE 관측값 연결은 남아 있다. `view`는 같은 검사를 거쳐 승인된 루트만 조회한다.

별도 거래 큐를 추가하지 않았다. 기존 저장 경로의 월드 전체 Pending 1개 제한을 유지하므로 연결당 outstanding은 명세 상한 8개보다 적다. 다른 거래는 Busy, 같은 요청은 재시도로 결과를 확인한다. 알려진 요청은 lease 만료·폐기 후에도 같은 계정의 원래 payload로 결과를 확인할 수 있다. 재접속 뒤 기존 요청을 확인하고 새 거래용 lease를 발급한다.

반환 `Result`는 서버 내부 값이다. [상태 응답 codec](RECEIPT.md)의 `make_receipt`로 공개 오류를 정규화한다. [스냅샷 전송 코어](SNAPSHOT.md)는 연결당 하나의 고정 전송본과 페이지별 권한 재검사를 제공한다. 실제 transport, inline 변경 행, Input 60회/초 제한, 전역/컨테이너별 부하 제한은 남아 있다.

## 종료

`close`는 신규 입장과 모든 신규 명령을 먼저 중단한다. 기존 `DurableInventory::close`가 Pending 정리와 저장소 정상 종료/백업을 수행한다. Pending 또는 저장 실패 시 참가자 목록을 유지하며 `close`를 재시도한다. 성공하면 목록을 비우고 이후 입장을 거절한다.

`prepare_close()`는 신규 입장/명령을 막고 기존 저장을 확정하지만 DB와 참가자 목록을 유지한다. Pending/실패이면 재시도하며 Ok 이후 외부 참가자 통지를 수행하고 `close()`로 백업·DB 닫기를 진행한다. 준비 성공은 DB 종료 성공이 아니다. 두 단계 모두 반복 호출할 수 있다. 기존 `close()` 단독 경로도 유지한다. 현재 저장 모델은 모든 변경이 critical 거래이며 별도 noncritical snapshot은 없다. 콘솔은 준비 성공 후 내부 ClientState를 연결 해제하고 DB를 닫는다. 실제 UE/transport 종료 통지와 전달 확인은 남아 있다.

검증: `./scripts/build.ps1`에서 1+19명 슬롯, handshake 불일치, 중복 계정/Pawn, 연결 번호 폐기, 다른 스레드 호출 거절, 제한 보충 경계, 재접속 제한 유지, 로컬/원격 거래, Pending 보존과 종료 실패 재시도를 검사한다.
