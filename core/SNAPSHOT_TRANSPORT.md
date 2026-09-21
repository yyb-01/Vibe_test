# 인증된 스냅샷 전용 스트림

명령 스트림과 별개인 **연결당 하나의 ordered reliable stream**을 사용한다.
두 스트림 모두 같은 인증 연결에 결합한다. 실제 소켓·채널 생성은 플랫폼 책임이다.

## 요청과 메타데이터

1. SessionResume 수신 후 클라이언트가 `request_snapshot(token)`을 호출한다.
   명령 스트림에 SnapshotRequest(messageType=5, 공통 헤더 32B, payload 없음)를 보낸다.
   진행 중인 스냅샷이나 미송신 명령이 있으면 Busy다. 이전 뷰/lease는 즉시 비운다.
2. 호스트는 현재 서버 관측값으로 lease를 발급하고 고정 스냅샷을 만든다.
   클라이언트는 요청에 루트·계정·관측값을 넣지 않는다.
3. 전용 스트림의 첫 프레임은 SnapshotOffer(messageType=6)다.
   payload는 lease(u64), snapshotId(16B), sequence(u64), bytes(u32), rootCount(u16),
   rootId[16B] 순서이며 little-endian이다. epoch는 공통 헤더에서 가져온다.
   1~16개의 중복 없는 유효 루트와 최대 2MiB descriptor를 검증한다. 패킷 최대 326B다.
4. 같은 스트림에 기존 snapshot page 프레임을 순서대로 보낸다.
   각 프레임 앞에는 4B 길이 prefix가 붙는다. 메타데이터와 페이지 순서가 뒤바뀌지 않는다.

## 플랫폼 I/O 계약

- 명령은 기존 output/sent/receive를 사용한다. SnapshotRequest는 receipt를 만들지 않는다.
- 호스트는 `snapshot_output(최신 서버 관측값)`을 호출하고 반환 span을 **즉시** 송신한다.
  실제 쓰인 바이트 수만 `snapshot_sent(n)`에 전달한다. would-block이면 0이다.
  span을 외부 송신 큐에 복사해 나중에 쓰지 않는다. 다음 송신 전에 다시 호출한다.
- 클라이언트는 같은 연결 토큰으로 `receive_snapshot(token, bytes)`를 호출한다.
  호출당 프레임 하나까지만 소비하므로 남은 suffix는 다시 전달한다.
- offer 후 `snapshot_lease(token)`으로 새 거래의 lease 값을 얻는다.
  원본 거래 재전송은 기존 retry를 사용하며 원본 lease를 바꾸지 않는다.
- 완성된 모든 페이지의 checksum·descriptor·승인 루트·World 검증이 성공해야 뷰를 게시한다.
  전송 도중 더 최신 확정 receipt가 재조립을 무효화하면 이후 페이지 수신은 연결 실패다.
  클라이언트는 재접속하여 스냅샷을 다시 요청한다. 원본 거래와 확정 receipt는 유지된다.

호스트는 한 프레임만 송신 대기한다. 최초 offer는 1,200B 제한, 이후 페이지는
65,536B 제한이다. 클라이언트도 같은 단계별 제한과 기존 2MiB 재조립 상한을 사용한다.
페이지 생성은 기존 계정 예산을 소비한다. 예산 부족 Busy는 연결/진행 상태를 유지하므로
다음 tick에 다시 시도한다. 대기 프레임의 권한 재검사는 예산을 소비하지 않는다.

## 만료·철회·종료

호스트는 송신이 끝난 뒤에도 활성 스냅샷이 있는 동안 매 tick snapshot_output을 호출해
lease 만료·권한 변화를 검사한다. 별도 revoke 메시지 대신 연결을 끊는 보수적 동작이다.
권한 실패 시 큐를 비우고 peer를 해제한다. 플랫폼은 양쪽 스트림을 닫고 클라이언트의
disconnect를 호출해야 한다. 새 lease/스냅샷을 갱신하지 않으면 5초 만료 시 연결이 끊긴다.
실제 관측값 제공과 tick/시간 제한 스케줄러는 아직 플랫폼에서 연결해야 한다.

클라이언트의 snapshot EOF는 `finish_snapshot(token)`으로 전달한다.
프레임 중간뿐 아니라 offer 뒤나 페이지 사이의 미완료 EOF도 오류이며 뷰를 비운다.
손상 입력·요청 처리 실패도 연결을 닫는다. 이전 연결 토큰의 callback은 새 연결에 영향을 주지 않는다.
스냅샷이 송신 중이면 호스트 shutdown은 Busy다. 송신을 완료하거나 연결을 해제한 뒤 종료한다.
완료 직전의 늦은 페이지도 클라이언트 종료 후에는 거절한다.

검증: `./scripts/build.ps1`의 snapshot control / transport snapshots / failures / pages.
인증·소켓·자동 시간 제한·종료 ACK·실제 다중 참가자·UE/콘솔 통합은 후속 범위다.
