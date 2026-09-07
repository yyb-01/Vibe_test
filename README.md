# Astra Game — UE5 설치 전 C++ 코어

[기술 명세서](SURVIVAL_TECHNICAL_SPECIFICATION.md)의 A 영역부터 구현했습니다. C++20 표준 라이브러리만 사용하며 Unreal 없이 컴파일·테스트할 수 있습니다. 현재 실행물은 인벤토리를 조작하는 콘솔 샌드박스입니다.

## 실행

프로젝트 폴더의 PowerShell에서:

```powershell
./scripts/setup-toolchain.ps1
./scripts/build.ps1
./scripts/play.ps1
```

첫 명령은 공식 Zig 0.15.2 도구 모음 약 93MB를 `.tools`에 받고 SHA-256을 검사합니다. 시스템 설치나 PATH 변경은 없습니다. 이미 준비된 경우 다운로드하지 않습니다. 현재 워크스페이스에는 도구 모음이 준비되어 있습니다.

`build.ps1`은 실제 C++ 테스트를 실행합니다. `play.ps1`은 콘솔 데모를 빌드하고 실행합니다. 종료는 `quit`입니다.

```text
show
take 100 4 0
split 100 7 20 5 0
replay
merge 105 20 4 0
drop 100
take 100 4 0
swap 102 104
show
quit
```

컨테이너 10은 상자, 20은 플레이어 가방, 30은 바닥, 40은 아이템 102 안의 파우치입니다. `split` 출력의 `created`가 새 아이템 ID이며 위 105는 초기 샘플 기준입니다. `replay`는 마지막 요청을 그대로 재전송해 중복 적용이 없는지 확인합니다. 좌표는 0부터 시작합니다.

아이템 100/101/103은 탄약, 102는 가방, 104는 소총입니다. 데모의 외관·이동 공간은 콘솔 목록으로 표현됩니다.

## 구현 범위

- 명세서의 128bit ID, 64B ItemState/ContainerState, 48B Placement와 실제 컴파일 시 크기 검사.
- 그리드 회전, 슬롯, 바닥 위치, 중첩 깊이 4, 루트당 1,024개·직접 자식 256개 제한.
- 질량·외부 점유 부피·클래스 제한, 순환 참조·정수 overflow 검증.
- 이동/교환/분할/병합/드롭/줍기, tombstone, 전체 실패 롤백, 불변 읽기 스냅샷.
- 계정별 요청 중복 방지, 같은 ID의 payload 변조 거절, epoch·revision·순서·루트 접근권한 검증.
- 명세서 A.4의 44B 요청 머리말과 88B 항목을 명시적 little-endian으로 직렬화. 잘린 패킷·예약 비트·상한 위반 거절.

## 보증 경계

`Inventory::apply`의 성공은 **메모리에 적용됨**입니다. PostgreSQL 영속 커밋이나 분산 2PC를 뜻하지 않습니다. 종료하면 데모 상태와 중복 요청 기록은 사라집니다. 재시작 후 복사 방지, DB 장애 복구, 네트워크 인증·거리/LOS 검사, 낙하 Actor, UI는 아직 구현하지 않았습니다.

`Access`는 인증된 서버가 만들어야 합니다. 클라이언트가 권한 목록을 제출하는 API가 아닙니다. 전체 `snapshot()`도 서버용이며 원격 사용자에게 그대로 송신하면 안 됩니다. 순서 있는 거래 채널 기준으로 actionSeq는 1씩 증가하며, 정상 형식의 거절 결과도 해당 순서를 소비합니다.

생성자 `idOrigin`은 epoch와 별개인 아이템 ID 상위 64bit입니다. 운영 호스트는 영속 저장소에서 부팅마다 고유한 origin을 할당해야 합니다. 샘플의 고정 origin=1은 독립 데모용입니다.

현재는 mutex 하나와 전체 상태 복사로 원자성을 구현합니다. 대규모 월드에는 영향을 받는 루트만 복사하는 write-set과 PostgreSQL prepare/commit 적용 분리가 필요합니다. 확장 상태가 있는 stack의 분할/병합, 유연 가방 압축, 무기 Socket 장착은 지원하지 않습니다.

## UE5 연결

`core` 소스를 Unreal 서버 모듈에서 다시 컴파일합니다. Zig/MinGW 바이너리를 MSVC 엔진에 직접 링크하지 않습니다. 현재 코어는 예외를 사용하므로 해당 모듈의 `bEnableExceptions = true`가 필요합니다. 엔진 연결은 아직 검증하지 않았습니다.

CMake 3.20+와 C++20 컴파일러가 있으면 `cmake -S . -B .build/cmake`, `cmake --build .build/cmake`, `ctest --test-dir .build/cmake -C Debug --output-on-failure`도 사용할 수 있습니다. 실제 검증한 경로는 Windows Zig 빌드입니다.

세부 진행 상황은 [구현 현황](IMPLEMENTATION_STATUS.md)에 기록합니다. 명세서 산술 검사는 기존 `verify_spec.py`로 별도 실행합니다.
