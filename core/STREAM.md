# 인증된 바이트 스트림의 프레임 경계

`stream.hpp`는 연결에서 받은 바이트를 기존 codec에 넘길 완전한 프레임으로 복원한다.
소켓·TLS·인증·송신 대기열·재전송을 구현하지 않는다. 현재 콘솔은 직접 codec 왕복이며,
스트림 경로는 `tests/stream_session.cpp`에서 HostSession/ClientState와 통합 검증한다.

## 포맷과 한도

4B little-endian unsigned payload 길이 뒤에 기존 packet 또는 snapshot page를 그대로 붙인다.
길이는 1 이상이다. 기본 한도는 packet의 1,200B, snapshot 전용 논리 스트림은
`snapshot_page_limit`(65,536B)을 명시한다. 길이 prefix 4B는 이 한도 밖이다.
채널 종류와 한도는 인증된 연결 설정으로 정하며 클라이언트 payload에서 선택하지 않는다.
같은 스트림에 packet/page를 섞는 다중화는 제공하지 않는다.

`encode_stream`은 기존 payload의 의미를 검사하지 않는다. 수신 완료 후에도
decode_packet/receipt/resume/shutdown 또는 SnapshotAssembly의 검증을 반드시 수행한다.

## 수신·종료

- 연결/논리 채널별 StreamDecoder 하나를 소유 스레드에서 사용한다.
- `receive(span)`은 최대 한 프레임까지 소비하고 소비한 바이트 수를 반환한다.
  남은 suffix는 호출자가 보관한다. `complete()`이면 `take()`로 꺼낸 뒤 suffix를 다시 전달한다.
  완성 프레임을 꺼내기 전 receive는 0을 반환한다. 무조건 반복 호출하면 안 된다.
- 헤더 4B만으로 길이를 검증한 뒤 최대 한 프레임만 할당한다. 입력에 여러 프레임이 있어도
  내부 무제한 대기열을 만들지 않는다. 송수신 예산과 backpressure는 transport 책임이다.
- EOF에서 `finish()`를 호출한다. 미완성 header/body는 InvalidRequest이며 완성 프레임은
  finish 이후에도 take할 수 있다. 종료 후 receive는 InvalidState다.
- 손상 입력/수신 예외가 발생하면 decoder를 재사용하지 않는다. 연결을 끊고 기존
  ClientState::disconnect 경로로 미확정 요청을 보존한다. 새 연결에는 새 decoder를 만든다.
- 미완성 프레임의 시간 제한, peer 인증, 이전 연결 callback 폐기, EOF 이후 자동 재접속은
  실제 transport가 처리해야 한다. 이 codec만으로 네트워크 서비스가 완성되지 않는다.

검증: `./scripts/build.ps1`의 stream frames/stream session 그룹.
