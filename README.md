# Zombie Survival

Godot 4.2 기반의 2D 뱀파이어 서바이버즈 / 탑다운 좀비 생존 로그라이트 프로토타입입니다.

## 실행

Godot 에디터에서 프로젝트를 열고 `scenes/ui/main_menu.tscn`을 실행합니다.

- 이동: `WASD`
- 조준: 마우스 커서
- 기본 사격: 자동
- 자동/수동 전환: `F`
- 수동 사격: 마우스 왼쪽 버튼 홀드
- 재장전: `R`
- 게임 중 메인 메뉴: `Esc`

## 주요 구조

- `scripts/autoloads`: EventBus, ObjectPoolManager, SpatialGrid, SaveManager, AudioManager
- `scripts/player`, `scripts/enemies`, `scripts/weapons`: 전투 및 엔티티 로직
- `scripts/resources`와 `data`: Resource 기반 무기/퍽 데이터
- `scenes/maps`: 서로 다른 구조의 2개 플레이 맵
- `.github/workflows/build.yml`: 에셋 임포트, 맵 로드 검증, Windows export

## 검증

로컬에 Godot 4.2.x가 설치되어 있으면 다음 명령으로 맵 로드와 스폰을 확인할 수 있습니다.

```bash
godot --headless --path . --script verify_map.gd
```
