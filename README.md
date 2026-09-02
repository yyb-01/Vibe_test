# Zombie Survival

Godot 4.2 기반의 2D 뱀파이어 서바이버즈 / 탑다운 좀비 생존 로그라이트 프로토타입입니다.

## 실행

Godot 에디터에서 프로젝트를 열고 `scenes/ui/main_menu.tscn`을 실행합니다.

- 이동: `WASD`
- 조준: 마우스 커서
- 기본 사격: 자동 (F로 수동 조준 전환)
- 자동/수동 전환: `F`
- 수동 사격: 마우스 왼쪽 버튼 홀드
- 재장전: `R`
- 일시정지/메뉴 확인: `Esc` → 확인창에서 선택

## 주요 구조

- `scripts/autoloads`: EventBus, ObjectPoolManager, EvolutionManager, UpgradeManager, SpatialGrid, SaveManager, AudioManager
- `scripts/player`, `scripts/enemies`, `scripts/weapons`: 전투 및 엔티티 로직
- `scripts/resources`와 `data`: Resource 기반 무기/퍽 데이터
- `scenes/maps`: 서로 다른 구조와 크기의 4개 플레이 맵
- `scenes/world`: 생존자 구조 목표
- `.github/workflows/build.yml`: 에셋 임포트, 맵 로드 검증, Windows export

## 게임 시스템

- 30초마다 웨이브가 증가하며 생성 속도, 체력, 특수 좀비 비율이 상승합니다.
- 일반 좀비, 러너, 탱크, 스피터, 자폭형 봄버, 사망 폭발형 블로터, 엘리트, 5분 보스가 등장합니다.
- 기관단총, 점사 소총, 레일건, 충격파 발생기를 포함한 8종 무기는 5레벨에서 진화하고, 패시브 조합은 추가 시너지를 제공합니다.
- 공격형 Scavenger, 생존형 Medic, 기동형 Ranger 중 하나를 선택할 수 있습니다.
- 맵에서 구조 신호를 회수하고 처치 의뢰를 달성하면 추가 골드를 획득합니다.
- 맵별 사건(차량 호송, 발전기 재가동, 감염 샘플 회수, 보스 데이터 해킹)을 완료하면 진화 코어와 펫 설계도를 얻습니다.
- 맵3 `침수 격리 지구`는 중앙 수로와 엄폐물이 있는 긴 동선으로, 맵4 `지하 연구소`는 교차 실험동과 콘솔 엄폐물로 설계되었습니다.
- 레벨업 카드에서 골드 25G로 리롤하거나 카드를 건너뛸 수 있고, 맵3의 보급 상자는 골드와 체력을 제공합니다.
- 웨이브가 오를 때 보너스 골드와 위협 상승 배너가 표시되며, 엘리트 5마리 처치 의뢰도 진행됩니다.
- 탄환 피격 충격 링, 플레이어 피격 방향 경고, 체인 라이트닝, 레일건 트레이서, 충격파 확산 이펙트가 무기별로 표시됩니다.
- 8개 무기는 레벨 5 이후 고유한 진화 이름과 공격 방식 강화로 전환되며, 사건에서 얻은 진화 코어로 웨이브 상점에서 무료 진화할 수 있습니다.
- 런 통계와 최고 기록, 골드, 영구 업그레이드는 `user://save_data.cfg`에 저장됩니다.
- 메뉴에서 화면 흔들림과 효과음 볼륨을 조절할 수 있습니다.

## 1,000+ 오브젝트 고성능 경로

기존 게임플레이를 보존한 채 사용할 수 있는 최적화 경로가 다음 파일에 있습니다.

- `scripts/autoloads/object_pool_manager.gd`: `PackedScene`별 `active_pool`/`inactive_pool`과 기존 `acquire/release` 호환 API
- `scripts/enemies/OptimizedZombie.gd`: 0.1~0.3초 스태거드 조향, `SpatialGrid` 반발, 화면 밖 저비용 이동
- `scripts/weapons/BaseProjectile.gd` 및 `scripts/weapons/PooledProjectile.gd`: float 수명·거리·관통 한도 기반 투사체
- `scripts/managers/OptimizedSpawner.gd`: 화면 밖 링 스폰과 프레임당 스폰 예산

`OptimizedSpawner`를 맵의 `Node`에 붙이고 `queue_wave(1000)`을 호출합니다. 좀비 풀은 `pool_size=1024`, `max_size=1200`, `spawn_per_frame=8`을 기준으로 시작합니다. 투사체는 `pooled_projectile.tscn`을 등록한 뒤 `ObjectPoolManager.spawn(scene, pos, angle, [direction, damage, target, pierce])`로 꺼냅니다.

권장 충돌 레이어는 Player=1, World=2, Enemy=4, Projectile=8입니다. 좀비는 `collision_mask=2`만 사용해 좀비끼리 물리 충돌을 만들지 않고, 투사체는 `collision_mask=6`으로 벽과 적만 감지합니다. 프로젝트 물리 틱은 60Hz로 고정되어 있습니다.

풀과 재사용 경로는 다음 headless self-check로 확인할 수 있습니다.

```text
Godot_v4.2.2-stable_win64_console.exe --headless --path . verify_optimized_pool.tscn
```

## 무기 진화·12종 발사체 시스템

- `scripts/resources/item_data.gd`: `ItemData` 기본 Resource
- `scripts/resources/weapon_data.gd`: 기존 `WeaponData`에 `cooldown`, `speed`, `projectile_scene`, `is_evolution`을 추가한 호환 버전
- `scripts/resources/passive_data.gd`, `scripts/resources/evolution_recipe.gd`: 패시브·진화 레시피
- `scripts/managers/EvolutionManager.gd`, `scripts/managers/UpgradeManager.gd`: 레벨 조건 검사, 안전한 무기 교체, 진화 우선 3~4장 추첨
- `scripts/weapons/AdvancedWeapon.gd`: 12종 발사 루트와 풀 예열
- `scripts/weapons/projectiles`: Pistol/Dual, Shotgun/Dragon, Revolver/Magnum, Flame/Infernal, Rocket/Cluster, Tesla/Thor 및 공용 장판·폭발·빔

`AdvancedWeaponCatalog.get_weapons()`는 6개 기본 무기와 6개 진화 무기를 제공하고, `get_recipes()`의 조건은 기본 무기 `Lv5`와 지정 패시브 `Lv1+`입니다. 기존 프로젝트의 `weapon_data.gd`가 사용 중이므로 Windows의 대소문자 파일 충돌을 피하기 위해 요청된 `WeaponData.gd`는 이 호환 파일에 구현했습니다.

레벨업 화면 외의 코드에서도 `UpgradeManager.get_level_up_choices(player, 4)`로 카드를 만들고 `UpgradeManager.apply_choice(player, choices[0])`로 적용할 수 있습니다. 새 탄환은 `ObjectPoolManager.spawn(data.projectile_scene, muzzle, direction.angle(), [direction, damage, player, pierce, {"weapon_id": data.id}])` 형식으로 호출합니다.

권장 인스펙터/프로젝트 설정:

- Physics Ticks per Second: `60`; Project Settings → Physics → 2D → Default Gravity: `0`
- Layer 1 World, 2 Player, 4 Enemy, 8 Projectile
- OptimizedZombie: layer `4`, mask `2`; 각 좀비의 충돌 모양은 좀비끼리 겹치지 않게 설정하고 `SpatialGrid` 반발을 사용
- 새 발사체: layer `8`, mask `2|4`; `FireZone`/`Explosion`은 layer `0`, mask `4`
- `VisibleOnScreenNotifier2D`는 스프라이트보다 조금 큰 사각형으로 두고, 화면 밖에서는 시각 처리만 끄며 이동/AI 캐시만 유지
- Area2D의 `monitoring`은 효과 씬에서만 켜고, DoT/전도/수명은 Timer 노드 없이 float 누적으로 처리

새 시스템만 검증하려면 다음 self-check를 실행합니다.

```text
Godot_v4.2.2-stable_win64_console.exe --headless --path . verify_advanced_system.tscn
```

## 검증

로컬에 Godot 4.2.x가 설치되어 있으면 다음 명령으로 전체 리소스 파싱과 맵 스폰을 확인할 수 있습니다.

```bash
godot --headless --path . verify_resources.tscn
godot --headless --resolution 1280x720 --path . verify_hud_layout.tscn
godot --headless --resolution 1280x720 --path . verify_main_menu_layout.tscn
godot --headless --path . verify_map.tscn
```

## 상용화 에셋

현재 포함된 그래픽은 프로젝트 내부에서 직접 만든 SVG이며, 외부 유료 에셋 의존성이 없습니다. 사용 범위는 `ASSET_LICENSE.md`에 기록했습니다.
