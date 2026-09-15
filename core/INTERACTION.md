# 연결별 열람·조작 lease — 명세 2.2 / 2.3 / A.4

`HostSession`은 외부에서 구성한 `Access`를 받지 않는다. 연결에서 계정을 찾고 lease를 확인한 뒤 내부에서 `Access`를 만든다. 저수준 Inventory/DurableInventory API는 서버 내부 전용으로 유지한다.

## 서버 관측값

`InteractionState`는 서버가 연결에 배정한 Pawn, 생존·작업 가능 상태, 각 최상위 루트의 거리(m)·LOS·접근 허용 여부다. 기본 bool 값은 false다. 거리와 LOS는 **권위 월드에서 매번 계산한 값**이어야 하며 클라이언트 패킷에서 복사하지 않는다. 실제 UE 거리 측정·충돌 raycast·권한 데이터 연결은 아직 미구현이다.

코어는 다음을 검사한다.

- 관측 Pawn과 연결 Pawn이 같고 생존·작업 가능한 상태
- 모든 루트의 접근 허용과 LOS, 유한한 거리 0~2.5m
- 1~16개의 중복 없는 루트 ID(최대 8개 이동의 출발·도착 범위)
- 발급 시 실제 최상위 루트인지 확인. 중첩 컨테이너·없는 ID는 모두 NotAccessible

소유 가방 등 거리/LOS의 기준점 선정도 서버의 책임이다. 루트 승인에는 그 루트의 자손 내용물 열람 권한까지 포함된다. 일부 자손만 공개할 권한이면 해당 루트를 승인하면 안 된다.

## 발급·사용·폐기

1. 인증된 연결의 현재 관측값으로 `grant_lease(connection, state)`를 호출한다.
2. 반환된 token을 클라이언트에 전달한다. 한 연결에 lease 하나만 유지하며 교체할 때 이전 token을 폐기한다.
3. 신규 거래는 `receive(connection, bytes, state)`, 방장은 `apply_local(request, state)`로 실행한다. 요청의 interactionLease가 현재 token과 일치해야 한다.
4. 읽기는 `view(connection, token, state)`로 수행한다. 승인된 루트의 불변 스냅샷만 반환하며 전체 월드·다른 루트·tombstone 원장은 노출하지 않는다.
5. 열람 종료나 권한 철회 시 `revoke_lease(connection)`를 호출한다. disconnect도 lease를 폐기한다.

초기 수명은 서버 steady clock 기준 5초이며 정확히 만료 시각부터 거절한다. 매 요청/조회에서 현재 관측값을 다시 검사하고 발급 때의 루트 집합과 일치시킨다. 새 루트가 필요하면 lease를 교체한다. 현재 구현의 조회는 거래와 같은 10회/초·burst 20 예산을 소비한다. 발급/폐기는 신뢰된 호스트 관리 호출이며 외부 RPC로 직접 노출하지 않는다.

스냅샷은 조회 순간의 권한과 데이터를 나타낸다. [페이지 전송 코어](SNAPSHOT.md)는 각 페이지를 생성할 때 권한을 재검사한다. 실제 transport 큐에 대기시키는 경우 송신 직전 재검사가 필요하며, 엔진 복제 연결은 후속 작업이다.

## lease 만료 후 거래 결과

새로운 명령과 과거 결과 조회를 구분한다. `Inventory::result_for`는 알려지지 않은 요청을 준비하거나 순번을 소비하지 않는다. DurableInventory의 같은 API는 자기 계정의 Pending 거래만 resolve할 수 있다.

세션은 같은 계정·requestId·원래 payload의 결과가 있으면 lease 검사 전에 그 결과를 반환한다. 따라서 사망·거리 이탈·재접속 때문에 이미 접수된 거래를 Rejected로 바꾸지 않는다. payload를 바꾸면 IdempotencyMismatch이며, 다른 계정의 결과는 조회할 수 없다. 결과 조회는 아이템 내용을 담은 스냅샷을 반환하지 않는다.

재접속 후 기존 결과를 확인할 때는 **기존 lease 값도 포함한 원래 payload**로 재전송한다. 이후 새 거래에는 새 lease를 사용한다. 만료된 lease로 신규 요청을 보내면 저장 작업 없이 NotAccessible이다.

검증: 루트별 비공개 데이터 분리, Pawn·거리 경계·NaN/무한대·LOS·생존/작업·중복 루트 거절, token 교체/철회/만료, Pending 이후 철회, 재접속 replay와 원장 복구 후 조회를 C++ 테스트에 포함한다.
