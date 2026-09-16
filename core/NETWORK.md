# 거래 네트워크 경계 — 명세 2.2 기반

바이트 스트림 분할/결합 수신은 [STREAM.md](STREAM.md)의 길이 prefix와 StreamDecoder를
사용할 수 있다. 실제 소켓 연결은 없으며 기존 패킷 wire 포맷과 독립적인 외부 프레임이다.

## 정상 종료 통지

`shutdown.hpp`의 SessionClosing(messageType=4)은 공통 헤더 32B와 마지막 확정
world sequence 8B(little-endian), 총 40B다. 길이·버전·flags·epoch·MTU와
sequence 상한을 기존 envelope/codec 규칙으로 검사한다. sequence=0도 허용한다.

호스트는 `prepare_close()`가 Ok일 때만 `encode_shutdown`으로 통지하고 그 후
`close()`로 백업과 DB 닫기를 수행한다. 통지는 critical 거래 정리 완료를 뜻하며
백업/DB 종료 성공이나 개별 요청의 Committed를 보증하지 않는다.

인증된 **현재 연결**에서만 `ClientState::receive_shutdown`을 호출한다. 클라이언트는
게시·확정 순번 후퇴를 거절한 뒤 `disconnect()`로 뷰/재조립을 비우고 미확정 요청을
Resolving으로 유지한다. 원본 payload와 최종 receipt는 보존한다. 같은 통지 재전달은
안전하며 재접속 baseline은 통지의 순번보다 후퇴할 수 없다. 이전 연결의 지연 메시지를
폐기하는 책임은 transport에 있다. epoch만으로 연결 인증이나 replay 방지를 제공하지 않는다.

콘솔 ClientMode 종료는 이 codec 왕복을 사용한다. 실제 원격 전달·전달 확인·재전송·
메뉴 전환은 미구현이다. `tests/shutdown_codec.cpp`와 `tests/client_shutdown.cpp`가
손상 입력 무변경, Pending→통지→DB 종료, 중복 통지, 저장 종료 실패 재시도를 검사한다.

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

## 재접속 정보

messageType=3(SessionResume)은 공통 헤더 32B와 payload 80B로 구성된다. payload는 worldId 16B, accountId 16B, catalogHash 32B, 확정 sequence 8B, nextActionSequence 8B 순서다. epoch는 공통 헤더에만 담는다. 정수는 little-endian이며 ID는 hi/lo 각 8B다.

서버의 resume_state 결과를 encode_resume으로 직렬화한다. decode_resume의 expectedEpoch는 인증된 handshake에서 제공하며 패킷에서 추출해 신뢰하지 않는다. 길이·메시지·epoch·비어 있는 ID·순번 범위를 검사하고, 계정/월드/catalog 일치와 순번 후퇴는 ClientState가 검사한다. codec 자체는 인증이나 암호화를 제공하지 않는다. 콘솔 ClientMode의 초기 재개 정보도 이 왕복을 사용한다.
