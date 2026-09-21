# 권한 범위 스냅샷과 페이지 — 명세 2.2 / 2.3

`HostSession::start_snapshot(connection, lease, state)`는 권한이 확인된 루트의 한 시점 상태를 직렬화하고 `SnapshotDescriptor`를 반환한다. 연결당 전송본 하나만 유지한다. 새 전송 시작, lease 교체/폐기, disconnect는 이전 전송본을 폐기한다.

## 공개 데이터

`encode_view`는 루트 ID와 활성 item/container/placement 행만 담는다. catalog, 요청 원장, 계정, tombstone을 포함하지 않는다. 아이템의 내부 birthEvent/reservedBy는 0, extraIndex는 UINT32_MAX로 정규화한다. 기존 행 codec을 재사용하되 저장 체크포인트 전체를 전송하지 않는다.

view payload는 little-endian이다. magic `0x31575641`, rootCount(u32), rootId[16B] 목록, item/container/placement count(u32 각 하나), 해당 행 목록 순이다. 행 크기는 기존 codec의 64/81/48B다. 수신 시 알려진 catalog로 그리드·중첩·수량·질량·루트 집합과 중복 ID를 검증한다. 반환 World는 클라이언트 표시용이며 서버 원장으로 반입하지 않는다.

## 페이지 형식

이 프레임은 **reliable stream용**이다. 1,200B 데이터그램에 넣지 않는다.
[공통 transport](SNAPSHOT_TRANSPORT.md)에 요청·lease/descriptor·페이지 스트림을 연결했다.
실제 소켓·인증·암호화 구현은 아직 없다.

| offset | 필드 | 바이트 |
|---|---|---|
| 0 | magic `0x31505341` | 4 |
| 4 | snapshotId | 16 |
| 20 | worldEpoch | 8 |
| 28 | snapshotSequence | 8 |
| 36 | page / pageCount | 2 / 2 |
| 40 | totalPayloadBytes | 4 |
| 44 | 페이지 데이터 | 최대 65,484 |
| 마지막 8B | 앞선 모든 바이트의 FNV-1a checksum | 8 |

페이지 번호는 0부터 시작한다. 프레임 전체 최대 65,536B, 원본 직렬화 payload 최대 2MiB, 페이지 수 최대 33개다. checksum은 우발적 손상 검사이며 인증 수단이 아니다.

`snapshot_page(connection, snapshotId, page, state)`는 **각 호출마다** 현재 lease·Pawn·거리·LOS·권한을 다시 검사한다. 실패하면 전송본을 폐기한다. 내용은 시작 시점에 고정되며 도중의 거래로 페이지별 상태가 섞이지 않는다. 호출 결과는 즉시 전송해야 한다. 엔진이 송신 큐에 오래 보관하면 실제 전송 전에 다시 권한을 확인해야 한다.

페이지 요청은 기존 거래/조회 예산을 공유한다. 신규 발급·페이지 전송이 오래 걸려 5초 lease가 만료되면 새 lease와 새 스냅샷으로 다시 시작한다.

## 수신·게시

인증된 서버가 알려 준 descriptor의 snapshotId/epoch/sequence/bytes를 확인하고 연결당 `SnapshotAssembly` 하나를 만든다. 선언 크기가 2MiB를 넘으면 할당 전에 거절한다. 페이지 전체 길이·checksum·descriptor 일치·페이지 번호/개수·정확한 마지막 페이지 크기를 검사한 뒤 복사한다.

역순과 동일한 중복 페이지를 허용하며 내용이 다른 중복은 거절한다. 다른 전송/epoch의 프레임으로 미완성 버퍼를 교체하지 않는다. 모든 페이지를 받기 전 `bytes()`는 Pending이다. 완성 후 `decode_view`가 성공했을 때만 기존 클라이언트 뷰를 교체한다.

2MiB는 재조립 **직렬화 payload** 상한이다. 입력 프레임·컨테이너 메타데이터·디코딩된 World 메모리는 별도이며 프로세스 전체 메모리 상한을 보증하지 않는다. [ClientState](CLIENT.md)는 승인 루트/epoch/순번 확인과 원자적 게시를 구현한다. 실제 reconnect·권한 철회 이벤트와 UI 연결은 남아 있다.

검증: 공개 필드/루트 분리, payload 절단, 2MiB/33페이지 역순 재조립, 중복/손상/다른 epoch/상한 초과 거절, 거래 도중의 고정 스냅샷, 페이지 사이 권한 철회와 새 전송 시 이전 ID 폐기를 검사한다.
