# 클라이언트 거래·뷰 상태 모델

`ClientState`는 UI 스레드에서 사용하는 C++ 상태 모델이다. 실제 위젯, 드래그 UI, 소켓, 인증 SDK는 구현하지 않았다. 인증된 서버의 같은 계정/월드 세션에만 연결하고, catalog/epoch는 검증된 handshake에서 가져온다.

## 요청과 응답

송신 전에 `track(request)`로 원래 payload를 보관한다. 추적 항목은 최대 8개이며, 같은 ID·같은 payload의 재등록은 상태를 초기화하지 않는다. 같은 ID에 다른 payload는 IdempotencyMismatch다. 재시도는 `retry_payload(id)`를 사용해 lease 값까지 원본을 유지한다.

`receive_receipt(bytes)`는 codec/epoch를 검사하고 추적 중인 requestId만 반영한다. 이미 종료해 추적에서 지운 요청의 응답은 무시한다.

- Pending/Resolving은 Committed 또는 Rejected로 확정할 수 있다.
- timeout은 Resolving/PersistenceUnavailable로 표시하며 원본 요청을 지우지 않는다.
- Resolving 이후 늦게 온 Pending은 무시한다.
- 확정 뒤 늦게 온 Pending/Resolving은 무시한다. 상충하는 최종 응답은 InvalidState로 거절하고 기존 결과를 유지한다.
- `forget(id)`는 최종 상태에서만 허용한다. 새 논리 요청에는 재사용하지 않은 requestId를 발급해야 한다.

서버가 Committed를 보냈더라도 클라이언트 World에 임의로 아이템 변경을 재실행하지 않는다. 확정 순번을 기억하고 그 시점 이상인 권한 범위 스냅샷을 기다린다. `needs_refresh()`가 true이면 표시 데이터가 없거나 최신 확정 거래를 반영하지 못한 상태다.

## 스냅샷 게시

1. 열람 허용/lease 교체 시 `set_roots(approvedRoots)`를 호출한다. 같은 루트 집합이라도 이전 표시 데이터와 재조립 버퍼를 비운다.
2. 서버가 알려 준 descriptor를 `begin_snapshot`에 전달한다. HostSession의 epoch 내 증가하는 snapshotId와 sequence를 확인한다. 현재 게시 순번 또는 확인한 commitSequence보다 오래된 것은 거절한다.
3. `receive_page`에 프레임을 전달한다. 부분 수신에서는 false, 모두 검증하고 뷰를 게시하면 true다.
4. true일 때 `view()`의 불변 World로 화면을 갱신한다. 실제 루트 집합이 승인된 집합과 다르면 게시하지 않는다.

똑같은 descriptor의 재전달은 진행 중인 재조립을 초기화하지 않는다. 다른 전송을 시작할 때 이전 재조립 버퍼부터 해제한다. 더 최신의 commit ACK가 오면 뒤처진 미완성 전송을 취소한다. 손상 프레임·잘못된 World·허용하지 않은 루트는 기존 뷰를 덮어쓰지 않는다.

## 엔진 연결 시 남은 일

lease 폐기·열람 종료·disconnect 이벤트에는 `set_roots({})`를 호출하고 UI가 따로 보관한 이전 뷰 참조도 표시에서 제거해야 한다. 모델만으로 엔진의 연결 상실이나 권한 철회를 감지하지는 않는다.

새 epoch는 패킷 한 개를 보고 수용하지 않는다. 인증된 재접속 절차에서 새 ClientState를 만들고, 같은 계정/월드임을 확인한 뒤 미확정 요청의 원래 payload를 이전해 결과를 재확인한다. 자동 재접속·타이머·송신 스케줄링·위젯 연결은 후속 작업이다.

검증: 요청 상한과 원본 재시도, timeout/지연/상충 응답, 다른 epoch, 오래된 descriptor, 여러 페이지의 원자적 게시, 잘못된 수량/권한 범위, ACK 도착 중 재조립 취소, 실제 HostSession 영속 응답 연동을 검사한다.
