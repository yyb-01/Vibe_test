# 2차 에셋 카탈로그

이 문서는 `game_system_architecture_revised.md`의 Definition과 Presentation 자산을 연결하는 제작 기준이다. 파일을 먼저 만들고 임의의 Node에 붙이지 않는다.

## 파일 규칙

- AI raster: `assets/generated/<kind>_<id>.png`
- UI/vector: `assets/ui/icon_<id>.svg`
- 이름은 lowercase snake_case를 사용한다.
- Entity와 Pickup은 투명 배경, 중심 정렬, 여백 포함으로 만든다.
- Terrain은 반복 가능한 정사각 타일을 사용하고, 맵 전체 장식은 별도 Prop으로 분리한다.
- 구조물은 논리 Footprint와 독립이다. 연결 Mask는 `isolated/end/straight/corner/tee/cross`와 회전으로 표현한다.
- 체력 바, Preview, Telegraph 진행 바처럼 상태에 따라 바뀌는 얇은 표현은 코드로 유지한다.
- 저장 데이터에는 Sprite 경로·Variant·VFX 상태를 넣지 않는다.

## 현재 연결된 최소 세트

| Asset | 대상 | 연결 위치 | 상태 |
|---|---|---|---|
| `player_explorer.png` | Player | `operation.tscn` | 연결 완료 |
| `enemy_scavenger.png` | EnemyAgent | `operation.tscn` | 연결 완료 |
| `core_reactor.png` | Core | `operation.tscn` | 연결 완료 |
| `wall_module.png` | Wall View | `structure_view.gd` | 연결 완료 |
| `wood_salvage.png` | Wood Pickup | `operation.tscn` | 연결 완료 |
| `terrain_grass.png` | Grass Terrain | `operation_world.gd` | 연결 완료 |
| `icon_wood.svg` | Inventory | `operation.tscn` | 연결 완료 |
| `icon_wall.svg` | Build Wall | `operation.tscn` | 연결 완료 |
| `icon_extract.svg` | Extraction | `operation.tscn` | 연결 완료 |

## 2차 세트 제작 현황

| Asset | 대상 Definition | 현재 상태 |
|---|---|---|
| `enemy_runner.png`, `enemy_brute.png` | Enemy Archetype | 제작·Enemy View 매핑·EnemyDefinition·다중 Spawn 등록 완료 |
| `terrain_dirt.png`, `terrain_stone.png`, `terrain_path.png` | Dirt, Rock, Path | 제작·Terrain ID 매핑·Briefing 선택·Operation HUD 연결 완료 |
| `structure_gate.png`, `structure_turret.png`, `structure_storage.png` | Gate, Turret, Storage | 제작·Structure View 매핑·Definition 등록·Briefing/Operation Blueprint UI 연결 완료 |
| `resource_scrap.png`, `resource_stone.png`, `resource_medicine.png` | Scrap, Stone, Medicine | 제작·Pickup View 매핑·Definition 등록·다중 Pickup 생성 연결 완료 |

현재 `outpost`는 기본값으로 `grass`를 사용하지만 Briefing에서 등록된 Terrain(`grass/dirt/rock/path`)을 선택해 실행할 수 있다. `scavenger·runner·brute / wood·scrap·stone·medicine / wall·gate·turret·storage` 조합으로 실행되며, 적 처치 Drop도 `InventoryController.add_pickup`으로 연결되어 `scrap` 또는 `stone`이 월드에 생성된다. Terrain 선택은 저장 Snapshot과 Operation HUD까지 연결되었고, 압박 이벤트는 `SpawnTicket`을 통해 웨이브 적을 동적으로 생성·추적한다.

## 2차 제작 순서

| 우선순위 | ID 묶음 | 목적 | 연결 조건 |
|---:|---|---|---|
| 1 | `enemy_runner`, `enemy_brute` | 적 Archetype 시각 구분 | EnemyDefinition·SpawnPlanner 다중 출현·Drop 연결 완료 |
| 1 | `terrain_dirt`, `terrain_stone`, `terrain_path` | 맵 변형과 경로 구분 | TerrainDefinition·Briefing 선택·SpawnTicket 연결 완료 |
| 1 | `structure_gate`, `structure_turret`, `structure_storage` | 벽 외 건설 콘텐츠 | StructureDefinition·View·Blueprint UI 연결 완료 |
| 2 | `resource_scrap`, `resource_stone`, `resource_medicine` | Inventory 흐름 확장 | ItemDefinition·다중 Pickup View 연결 완료 |
| 2 | `prop_rock`, `prop_crate`, `prop_ruin` | 맵 밀도와 랜드마크 | Operation 장식 레이어 추가 후 |
| 3 | Hit/Defeat/Build/Extraction VFX | Fact 기반 연출 | Fact Presenter 소비자 추가 후 |
| 3 | 경고음·피격음·건설음·종료음·환경음 | Audio Fact 소비 | AudioBus와 Audio Presenter 추가 후 |

## 완료 조건

에셋 파일 존재만으로 완료 처리하지 않는다. 각 항목은 `Definition → ContentManifest → View/Presenter → Headless 검증` 순서로 연결되어야 한다. 누락된 표현은 임의 Sprite로 대체하지 않고 Content validation failure로 기록한다.
