# 생존 reference 실행 안내

Windows C++20 권위 실행기와 Python 3.12+ 실행기를 사용한다. UE 설치는 필요하지 않다. 초기 준비:

```powershell
./scripts/setup-toolchain.ps1
./scripts/setup-sqlite.ps1
python -m pip install -r requirements.txt
./scripts/play-game.ps1 -Mode solo -WorldId survival -Rebuild
```

`play-game.ps1`은 Codex Python 런타임 또는 PATH의 Python을 선택한다. 의존성을 설치한 환경이 다르면 `-Python 'C:/경로/python.exe'`를 지정한다. 빌드 실행물은 `.build/astra-game.exe`다.

## 방장과 참가

```powershell
./scripts/play-game.ps1 -Mode host -WorldId survival -Address 192.168.0.10 -Port 7777
./scripts/play-game.ps1 -Mode join -Invitation '화면에서 복사한 astra:// 초대 링크'
```

방장 포함 20계정 슬롯을 지원한다. `-Address`는 참가자가 접속할 실제 방장 IP다. TLS 1.3과 초대 링크의 인증서 pin으로 접속한다. 초대 링크와 재접속 토큰은 해당 방의 접근 정보다. 방장 종료 시 방도 종료되며 방장 이전·NAT traversal/relay·플랫폼 인증 서비스는 제공하지 않는다.

Python CLI는 `python -m game_launcher --help`로 확인한다. `--no-browser`는 URL만 출력하며 `--ui-port`로 로컬 UI 포트를 지정할 수 있다.

## 화면과 조작

한국어 화면에 2D 지도, 생존/무기/차량 상태, 가방, 근처 대상, 제작/건축, 상세 명령을 표시한다. WASD로 이동하고 지도 클릭으로 조준하며 Space로 발사한다. 차량에서는 W 전진·S 후진·A/D 조향을 사용하고 가속 키를 떼면 브레이크를 적용한다. 화면에서 섭취·치료·장전·장착·줍기/드롭·탑승·급유·문/잠금·보관·제작/회수·건축·리스폰을 실행한다.

## 저장과 요청

월드는 `%LOCALAPPDATA%/AstraGame/Saves/<WorldId>/world.sqlite3`에 저장한다. WorldId는 검증된 ASCII 이름이며 예약 Windows 파일 이름을 거절한다. 계정 재접속 정보와 미확정 원본 입력은 `%LOCALAPPDATA%/AstraGame/Clients/` 등에 로컬 저장한다. 종료 버튼으로 저장 종료를 요청하고, 같은 WorldId로 다시 실행해 복구한다. 기존 SQLite 정상 종료·백업 3개·별도 파일 복원 정책을 재사용한다.

원격 room protocol은 2, 비공개 native pipe protocol은 1이다. gameplay archive v2와 inventory checkpoint v6을 사용하며 기존 checkpoint v1~v6을 읽는다. 게임 catalog v2와 다른 월드는 거절한다. 아직 콘텐츠 migration 도구가 없으므로 기존 세이브를 보존하고 새 WorldId를 사용한다.

공개 UI는 로컬 origin/bearer를 검사한다. 원격 입력은 인증된 슬롯, 제한된 입력률, 발사 시계/epoch/조립 revision을 검사한다. 상태와 원본 요청 결과를 SQLite에 함께 확정한 후 공개하며, ACK 유실 시 같은 원본 요청을 재전송해 중복 소비를 막는다. 다른 계정의 가방과 접근할 수 없는 보관함 내용은 공개하지 않는다.

## 검증 경계

[구현 현황](../IMPLEMENTATION_STATUS.md)과 [성능 결과](GAME_PERFORMANCE.md)가 기준이다. 현재 물리는 AABB/평면 지면 reference이며 셀은 논리 활성 관리다. 최대 콘텐츠·8시간 soak·모든 GUI 조작·실제 20대 PC·CMake 빌드는 미검증이다.
