# 플랫폼 공통 클라이언트 I/O

ClientTransport는 ClientState를 소유하며 요청·응답·정상 종료 통지를 바이트 스트림에
연결한다. 인증·소켓 구현은 아니다. 소유 스레드에서만 호출한다.

## 신뢰 경계와 연결 수명

생성자의 ResumeState는 신뢰된 월드/계정/catalog/epoch와 최소 재개 순번이다.
첫 접속에서 아직 거래 이력이 없으면 sequence=0, nextActionSequence=1을 쓸 수 있다.
기존 클라이언트는 같은 객체를 재사용해 확정 순번과 원본 요청을 유지한다.
네트워크에서 받은 첫 패킷으로 신뢰할 계정이나 epoch를 정하면 안 된다.

1. 플랫폼 인증 완료 후 `open_authenticated(epoch)`를 호출해 연결 토큰을 받는다.
2. 소켓 callback에는 **그때 반환된 토큰**을 캡처한다. 새 연결의 토큰으로 치환하지 않는다.
3. `receive(token, bytes)`의 첫 프레임은 SessionResume여야 한다. 예상 epoch, 계정,
   월드, catalog와 순번 후퇴를 기존 codec/ClientState로 검사한 뒤 connected가 된다.
4. 이후 InventoryReceipt/SessionClosing만 받는다. 재개 프레임 재전달, 손상 프레임,
   잘못된 메시지는 연결을 닫고 예외를 반환한다. 플랫폼은 소켓을 해제한다.

재접속은 disconnect 후 새 open_authenticated로 시작하며 새 decoder와 단조 증가 토큰을
사용한다. 이전 토큰의 receive/sent/finish/submit 등은 InvalidState로 거절하고 현재 연결을
변경하지 않는다. 이전 disconnect는 무시한다. 정상 종료 수신 뒤 EOF도 이미 닫힌 연결의
콜백이므로 호출자는 InvalidState를 처리해야 한다. 어댑터 파괴 뒤 callback 실행은 금지한다.

## 송수신과 결과 보존

`submit`은 완전한 프레임을 준비한 뒤 요청 원본을 ClientState에 등록한다.
출력이 남으면 Busy로 거절한다. `output(token)`과 `sent(token, 실제 송신 바이트 수)`는
호스트와 같은 부분 송신 계약이다. 반환 span은 다음 변경 호출까지만 유효하다.
수신은 한 번에 프레임 하나까지만 소비하므로 반환값 뒤 suffix를 호출자가 다시 전달한다.
송수신 각각 한 프레임만 보관하며 외부 버퍼 한도와 tick 호출은 플랫폼 책임이다.

응답 시간 초과는 `timeout`, 원본 재전송은 `retry(token, requestId)`를 사용한다.
EOF의 `finish`와 오류/취소의 `disconnect`는 미확정 요청을 Resolving으로 보존한다.
새 연결에서 새 epoch로 packet 헤더만 다시 만들며 원본 actionSeq/lease/requestId는 유지한다.
최종 결과는 `state()`로 읽고 `forget`으로 제거하여 최대 8개 추적 슬롯을 반환한다.

SessionClosing은 기존 receive_shutdown 검증 후 연결을 해제하고 미송신 출력을 버린다.
확정 receipt가 없는 거래를 Committed로 바꾸지 않는다. 송신 완료는 원격 수신 ACK가 아니다.

## 남은 범위

스냅샷 채널과 lease/descriptor 전달은 [SNAPSHOT_TRANSPORT.md](SNAPSHOT_TRANSPORT.md)에 구현했다.
플랫폼 인증·소켓, tick 스케줄링,
종료 ACK, 실제 다중 참가자 시험과 UE 통합은 후속 범위다.
콘솔 ClientMode는 [실행 루프](../demo/CLIENT_MODE.md)로 연결했다.
검증: `./scripts/build.ps1`의 client transport session / failures / transport shutdown.

## 전송 시간 제한

생성자의 선택 인자는 양수 제한 시간(기본 30초)과 steady_clock 함수다.
open_authenticated부터 첫 resume 완성까지, 이후 명령 프레임의 첫 바이트부터 완성까지,
명령 큐 등록부터 송신 완료까지, 스냅샷 요청부터 전체 게시까지 각각 고정 마감 시간을 둔다.
부분 송수신이나 offer 도착은 마감을 연장하지 않는다. 유휴 연결은 유지한다.

플랫폼은 매 tick 및 output의 실제 쓰기 직전에 `poll(token)`을 호출한다.
false면 해당 토큰의 소켓·스트림을 닫는다. 오래된 토큰은 새 연결에 영향 없이 false다.
만료 시 출력·재조립·뷰를 비우고 원본 요청과 확정 receipt를 보존하며 미확정 거래는 Resolving이다.
I/O 진입점에서도 poll을 수행한다. 시계 역행/범위 오류는 연결 해제 후 InvalidState다.
송신이 끝난 거래의 **아직 시작하지 않은 receipt 대기**는 이 전송 제한의 대상이 아니다.
거래 응답 대기 정책은 기존 `timeout(token, requestId)`와 `retry`로 호출자가 처리한다.
