# 인증 완료 연결의 공통 호스트 어댑터

`HostTransport`는 신뢰된 플랫폼 어댑터가 검증한 `AuthenticatedPeer`와
`SessionInfo`를 받아 HostSession에 연결한다. 계정 인증·소켓·TLS 구현은 아니다.
클라이언트가 보낸 account/pawn을 인증 결과로 전달하면 안 된다.
HostSession이 먼저 생성되고 나중에 파괴되어야 하며 모든 호출과 파괴는 소유 스레드에서 한다.

## 연결과 I/O

1. 인증 완료 후 연결마다 새 HostTransport를 만든다. admission/재개 정보 생성 실패 시
   슬롯을 반환한다. 첫 `output()`은 길이 prefix를 포함한 SessionResume다.
2. 현재 `connection()`에 서버 관측값으로 lease를 부여한다. lease 전달은 기존 외부 계약이다.
3. `output()`의 바이트를 소켓에 쓰고 실제 받아들인 바이트 수만 `sent(n)`으로 알린다.
   would-block은 `sent(0)`이다. 반환 span은 다음 변경 호출까지만 유효하다.
4. 수신 바이트와 서버가 현재 관측한 InteractionState를 `receive`에 전달한다.
   반환값만큼만 입력을 소비한다. 분할 수신은 내부에서 복원하고, 결합 수신은 요청 하나까지만
   처리한다. 응답이 남아 있으면 0을 반환하므로 송신 준비 이벤트까지 수신을 중단한다.
5. 완성 요청은 HostSession의 rate limit/권한/영속 중복 검사에 전달된다. 응답은
   InventoryReceipt다. 같은 Pending 응답은 ClientState에서 상태 변화가 없을 수 있다.

수신은 최대 1,200B 프레임 하나, 출력은 재개 정보 또는 응답 하나만 보관한다.
호출자는 미소비 입력·소켓 버퍼에도 한도를 적용한다. 어댑터의 시간 제한은 아래 계약을 따른다.
전체 송신 성공은 OS/플랫폼이 바이트를 받았다는 의미이며 원격 수신 확인이 아니다.
ACK/packet sequence 기반 재전송은 사용하지 않고 requestId/actionSeq의 기존 중복 처리를 쓴다.

## 연결 상실과 재접속

EOF는 `finish()`로 부분 header/body 절단을 검사한 뒤 슬롯을 해제한다.
소켓 오류·취소·시간 초과는 `disconnect()`로 해제한다. 수신/응답 생성 예외도 연결을
해제하고 호출자에게 다시 던진다. 호출자는 소켓을 닫고 클라이언트 측 disconnect를 수행한다.
남은 응답은 버리지만 이미 제출된 거래는 취소하지 않는다.

같은 계정 재접속에는 새 객체와 새 연결 ID를 사용한다. 닫힌 객체는 수신을 거절하며
뒤늦은 disconnect가 새 연결을 해제하지 않는다. 이전 소켓 callback을 새 객체로 전달하지
않는 책임은 플랫폼 어댑터에 있다. 클라이언트는 원본 요청을 보존하고 재전송하여 결과를 확인한다.

## 정상 종료 통지

호스트 종료 관리자는 모든 연결에서 응답을 먼저 배출하고 `shutdown()`을 호출한다.
출력이나 스냅샷 송신이 남으면 Busy 예외이며, prepare_close가 Pending/실패이면 통지를 만들지 않는다.
Ok일 때만 SessionClosing을 대기시킨다. 마지막 바이트의 `sent`에서 peer를 해제한다.
모든 연결의 통지를 송신하거나 송신 시간 초과를 처리한 뒤 관리자가 HostSession::close를
호출해야 한다. 어댑터는 DB를 닫지 않는다. 원격 수신 확인·종료 ACK는 아직 없다.

클라이언트 I/O는 [CLIENT_TRANSPORT.md](CLIENT_TRANSPORT.md)에 구현되어 있다.
스냅샷 별도 채널은 [SNAPSHOT_TRANSPORT.md](SNAPSHOT_TRANSPORT.md)에 구현했다.
실제 인증·소켓·tick 스케줄링·다중 참가자 네트워크 시험은 후속 범위다.
콘솔 ClientMode는 [실행 루프](../demo/CLIENT_MODE.md)로 이 어댑터를 사용한다.
검증: `./scripts/build.ps1`의 transport session / transport failures / transport shutdown.

## 전송 시간 제한

생성자의 선택 인자는 작업당 제한 시간(기본 30초)과 steady_clock 함수다.
양수 제한과 단조 시계를 검증한다. 초기 resume 송신, 미완성 명령 수신, 명령 응답·종료 통지
송신, 스냅샷 전체 송신에 각각 고정 마감 시간을 둔다. 부분 진행으로 연장하지 않는다.
작업이 없는 유휴 연결은 만료시키지 않는다. lease의 5초 만료 검사는 별도로 유지한다.

플랫폼은 소유 스레드의 매 tick 및 `output()`을 얻어 실제 쓰기 직전에 `poll()`을 호출한다.
false면 소켓과 두 스트림을 닫는다. 마감 시각 이상이면 peer·디코더·출력을 정리한다.
시계 역행/범위 오류는 같은 정리 후 InvalidState를 던진다. receive/sent/snapshot I/O/shutdown도
처리 전에 poll하므로 늦은 바이트가 만료를 취소할 수 없다. 반환 span은 poll 호출 뒤 새로 얻는다.
별도 타이머 스레드는 없으며 호출하지 않는 동안 자동 실행되지 않는다.
검증: `transport deadlines`, `client transport deadlines`, `snapshot transport deadlines`.
