# 거래 네트워크 경계 — 명세 2.2 기반

`packet.hpp`는 엔진 없이 실행하는 애플리케이션 codec이다. 실제 소켓·방 생성·인증·암호화 transport는 아직 연결하지 않았다.

## wire v1

모든 정수는 기존 거래 codec과 같은 little-endian이다. C++ 구조체 메모리를 직접 송신하지 않는다.

| offset | 필드 | 바이트 |
|---|---|---|
| 0 | protocolVersion=1 / messageType=1(InventoryRequest) | 2 / 2 |
| 4 | worldEpoch | 8 |
| 12 | sequence / ackSequence / ackBits | 4 / 4 / 4 |
| 24 | senderTick | 4 |
| 28 | payloadBytes / flags=0 | 2 / 2 |

뒤에 기존 `44+88N` 거래 payload가 붙는다. 1~8개 이동의 전체 크기는 164~780B다. 송신 시 payloadBytes를 실제 길이로 계산한다. 수신 시 미지원 버전/메시지, 0 또는 범위 밖 epoch, 예약 flags, 잘린/추가 바이트, 손상된 payload를 거절한다.

거래 상태 응답은 messageType=2와 38B payload를 사용한다. [응답 계약](RECEIPT.md)에 상태·공개 오류·재확인 의미를 정의했다. [스냅샷 페이지](SNAPSHOT.md)는 별도 reliable stream 프레임이며 각 페이지 최대 64KiB, 재조립 payload 최대 2MiB다.

`pathBudget`은 암호화·transport 비용을 제외한 애플리케이션 예산이다. 1,200B와 전달받은 예산 중 작은 값으로 제한한다. 기본값만으로 실제 인터넷 MTU를 보증하지 않는다.

## 호스트 연결 순서

1. 플랫폼 transport에서 인증한 연결을 계정에 결합한다.
2. `decode_packet(bytes, durable.epoch(), pathBudget)`으로 검증한다.
3. 서버가 현재 거리·LOS·상태·루트별 권한을 `InteractionState`로 관측한다.
4. `HostSession::receive`가 codec 검사와 연결별 lease 검사를 거쳐 영속 결과를 반환한다. 방장은 `apply_local`로 같은 검사를 거친다.

codec은 인증 여부나 실제 거리·LOS를 판단하지 않는다. 클라이언트가 보낸 lease 값만으로 권한을 인정하지 않는다. [HostSession](SESSION.md)에 접속 슬롯·거래 제한·[lease/권한 범위 조회](INTERACTION.md)를 구현했다. 실제 인증·UE 관측값과 transport 연결은 남아 있다.

## 순번/ACK

`PacketWindow`는 연결·채널별 최신 순번과 이전 32개의 수신 여부를 기록한다. bit 0은 `sequence-1`, bit 31은 `sequence-32`다. 최초 수신 여부는 `initialized`로 구분한다. 최초 수신 전 ACK의 유효성 표시는 추후 transport 연결에서 정의해야 한다.

`serial_newer`는 uint32 래핑을 처리한다. 정확히 반 바퀴 차이는 모호하므로 새 순번으로 인정하지 않는다. 이 비교는 senderTick에도 사용할 수 있지만 장기 저장 tick은 64bit를 사용한다.

`observe`의 false는 중복 또는 윈도 밖이라는 뜻이다. 거래를 버리는 근거로 사용하지 않는다. 거래 재전송은 기존 requestId/actionSeq의 영속 idempotency를 거쳐 같은 결과를 재전달해야 한다. ACK 필드만으로 디스크 커밋을 인정하지 않는다.

검증: `./scripts/build.ps1`의 packet contract/window 그룹에서 헤더 offset, round trip, 모든 길이의 절단, 오염/추가 바이트, epoch/MTU 거절, 거래 replay, 순번 래핑과 32/33 간격을 검사한다.
