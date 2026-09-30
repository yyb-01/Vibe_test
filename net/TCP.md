# Windows TCP byte transport

`tcp_stream.hpp`의 `astra::tcp::Stream`은 Winsock 소켓 하나를 소유한다.
생성 시 nonblocking과 TCP_NODELAY를 설정하고 실패·소멸 시 소켓을 닫는다.
호출자는 WSAStartup/WSACleanup과 연결·인증·tick의 수명을 관리한다.
이 객체 자체는 세션 검색, 인증, 암호화, NAT/relay를 제공하지 않는다.

## I/O 계약

- `write`는 커널이 수락한 바이트 수만 반환한다. `WSAEWOULDBLOCK`은 0이며
  호출자는 나머지를 보존한다. 오류는 소켓을 닫고 `std::system_error`로 전달한다.
- `read(limit)`는 최대 4KiB의 내부 버퍼를 빌려준다. 비어 있어도 `eof()`가
  false이면 아직 데이터가 없다는 뜻이다. TCP의 수신 경계는 메시지 경계가 아니다.
- `consume(n)`으로 실제 소비한 길이만 제거한다. 남은 suffix는 다음 `read`에도
  유지된다. 반환 span은 consume/read/close 또는 객체 소멸 전에만 사용한다.
- `recv=0`은 EOF다. transport의 `finish`/`finish_snapshot`을 호출하여 절단을
  검증하고 연결을 정리한다. socket 오류에서도 transport의 disconnect가 필요하다.
- 소켓은 복사하거나 이동하지 않는다. 같은 객체의 I/O는 소유 스레드에서 실행한다.

## 실행 검증

```powershell
./scripts/test-tcp.ps1
```

CMake에서는 Windows의 `astra_tcp_tests`와 CTest `astra_tcp`가 같은 시험을 실행한다.
`network_tests/loopback.cpp`는 OS가 고른 127.0.0.1 포트만 사용한다.
명령과 스냅샷은 별도 TCP 연결이며, 테스트가 직접 만든 두 연결에만 고정 identity를
부여한다. 이 연결 짝짓기는 테스트 fixture이며 원격 사용자 인증으로 사용할 수 없다.

검증 범위는 nonblocking I/O, 부분 소비, EOF/RST, 커널 backpressure, 실제 TCP를
거친 resume·거래·스냅샷·종료, 응답 유실 후 재접속과 중복 저장 방지,
손상/절단 입력과 마감 만료 정리다. 저장은 기존 probe fixture이므로 실제 SQLite
다중 프로세스 시험이나 20대 PC 부하 시험을 대신하지 않는다.
발사 시험은 HostTransport와 ClientTransport 양쪽을 사용해 Pending·연결 유실·원본 입력
재전송·최종 shotId 일관성·실제 장전실 탄약 1회 차감을 검사한다.
발사 profile/pose는 테스트 관측이다. 혼합탄 급탄은 코어/SQLite에서 별도로 검증한다.

## 통합 시 남은 조건

실제 플랫폼 연결에서는 양쪽 채널을 동일한 인증 세션에 묶은 뒤에만
HostTransport/ClientTransport를 연다. 매 tick에 poll하고 스냅샷 송신 전에
최신 서버 관측으로 권한을 재검사한다. 정상 종료 시 명령 채널의 종료 통지를 먼저
배출하고 나머지 채널을 닫는다. 테스트의 루프를 인터넷 서버로 노출하지 않는다.
