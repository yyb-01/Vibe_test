# 거래 상태 응답 — 명세 A.4의 첫 구현

`receipt.hpp`는 영속 거래의 상태 확인용 codec이다. 공통 헤더의 messageType=2(InventoryReceipt), protocolVersion=1을 사용한다. 요청(type=1)과 같은 길이·예약 비트·epoch·MTU 검사를 재사용한다.

## wire

little-endian, 전체 70B = 공통 헤더 32B + 아래 payload 38B다.

| payload offset | 필드 | 바이트 |
|---|---|---|
| 0 | requestId | 16 |
| 16 | status: Pending=0, Committed=1, Rejected=2, Resolving=3 | 1 |
| 17 | reason | 2 |
| 19 | reserved=0 | 1 |
| 20 | commitSequence | 8 |
| 28 | durableWorldEpoch | 8 |
| 36 | changedCount=0 | 2 |

현재 changedCount=0은 **변경 행을 포함하지 않았다는 뜻**이다. 거래가 월드를 변경하지 않았다는 뜻이 아니다. 응답에 분할 생성 ID, 변경 행, snapshotVersion/페이지 토큰을 포함하는 기능은 아직 없다. 성공 뒤 [권한 범위 스냅샷](SNAPSHOT.md)을 요청해 내용을 갱신한다. 페이지 codec/재조립은 구현했으며 실제 transport 연결은 남아 있다.

빈 requestId, 지원하지 않는 status/reason, 상태와 이유의 모순, 헤더와 payload의 epoch 불일치, 잘린/추가 바이트, 변경 행이 있다고 주장하는 응답을 거절한다. Committed만 양수 commitSequence를 가지며 나머지 상태는 0이다.

## 공개 오류와 미확정 상태

reason의 고정 wire ID는 다음과 같다. 내부 Error 열거형 번호를 전송하지 않는다.

| ID | reason |
|---|---|
| 0 | None |
| 1 | RevisionConflict |
| 2 | Busy |
| 3 | InvalidPlacement |
| 4 | CapacityExceeded |
| 5 | CycleDetected |
| 6 | NotAccessible |
| 7 | MissingPart |
| 8 | InvalidQuantity |
| 9 | IdempotencyMismatch |
| 10 | PersistenceUnavailable |

`make_receipt`의 입력은 **DurableInventory 또는 HostSession의 Result**여야 한다. 메모리 전용 Inventory 결과로 디스크 커밋을 주장하면 안 된다.

- Ok → Committed/None, Pending → Pending/None.
- SequenceMismatch는 RevisionConflict, DepthExceeded는 InvalidPlacement, InvalidRequest는 NotAccessible로 정규화한다.
- Busy/LimitExceeded는 Resolving/Busy다. 요청 제한에 걸린 replay도 있을 수 있으므로 이를 과거 거래의 최종 거절로 해석하지 않는다.
- StorageUnavailable·EpochMismatch·Incompatible·InvalidState 등은 Resolving/PersistenceUnavailable이다. 저장 실패나 재동기화 필요를 숨겨 성공으로 바꾸지 않으며, 내부 진단 문자열도 전송하지 않는다.
- 나머지 명시적인 거래 거절은 대응하는 공개 reason으로 Rejected를 보낸다.

## 연결

인증된 연결에서 정상 디코딩한 요청의 ID와 `HostSession::receive` 결과를 `make_receipt(id, result, host.info().epoch)`에 넘긴다. 서버가 생성한 PacketHeader의 messageType을 InventoryReceipt로 지정하고 `encode_receipt`로 보낸다. 잘못된 패킷에서 임의로 requestId를 추출해 응답하지 않는다.

클라이언트는 인증된 서버에서 온 응답만 처리한다. [ClientState](CLIENT.md)가 epoch/requestId 검사와 timeout·지연 응답 처리를 구현한다. 이미 확인한 Committed는 지연된 Pending/Resolving으로 되돌리지 않는다. 실제 UI·타이머·인증 transport 연결은 남아 있다.

검증: 70B offset/round trip, 모든 절단 길이, 잘못된 상태·이유·예약 필드·epoch·MTU, 내부 오류 전체 매핑, 저장 대기→확정→lease 폐기 후 replay→요청 제한 응답을 테스트한다.
