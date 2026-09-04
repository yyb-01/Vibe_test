# Vivv 2차 리빌딩 진행 상태

최종 확인일: 2026-09-04
기준 문서: `docs/game_system_architecture_revised.md`

Godot 실행 파일은 GitHub 파일 크기 제한 때문에 저장소에 포함하지 않는다. 로컬의 `Godot_v4.2.2-stable_win64.exe/`는 `.gitignore` 대상이며, 다른 환경에서는 Godot 4.2.2를 별도 설치한다.

## 현재 상태

레거시 `scripts/`, `scenes/`, `data/`, 기존 아트 의존성을 정리하고 `game/` 루트에 Definition → Runtime State → Controller → View/Presenter 구조로 다시 구성했다. 현재 프로젝트는 Main Menu → Campaign → Briefing → Operation → Settlement 흐름으로 실행된다.

## 완료된 범위

- Slice A: ContentManifest, ContentCatalog, ContentValidator, 부트 실패 처리
- Slice B: AppFlow와 Operation lifecycle
- Slice C: Inventory의 World → Carried → Secured 흐름, Reservation, Pickup View
- Slice D: BuildGrid, BuildSite, Blueprint 선택, 연결 Mask, Preview, 철거/파괴
- Slice E: EnemyDefinition 3종, 다중 적 SpawnPlanner, 경로 재탐색, 피해, Enemy Drop
- Slice F: Objective, ThreatDirector, PressureEvent, Telegraph, SpawnTicket 기반 동적 웨이브
- Slice G: Extraction, OperationOutcome, RewardPolicy, Settlement, 중복 정산 방지
- Slice H: Campaign/Operation 원자 저장, 백업 복구, Reservation·Threat·SpawnTicket 복원
- Slice I: OperationPresenter/HUD, Blueprint Palette, 고대비 표시
- Slice J: 전체 앱 흐름 회귀
- Briefing Terrain 선택: `grass`, `dirt`, `rock`, `path`를 선택해 Operation과 HUD에 전달하고 Snapshot에 저장

## 현재 콘텐츠와 에셋

- Enemy: `enemy_scavenger`, `enemy_runner`, `enemy_brute`
- Terrain: `grass`, `dirt`, `rock`, `path`
- Structure: `wall`, `gate`, `turret`, `storage`
- Item/Pickup: `wood`, `scrap`, `stone`, `medicine`
- `outpost`는 3개 초기 적과 압박 Tier 1/2 웨이브를 사용한다.
- 에셋은 `assets/generated/` PNG 17개와 `assets/ui/` SVG 3개가 연결되어 있다.
- 자세한 연결 상태는 `docs/asset_catalog_v2.md`를 기준으로 한다.

## 검증 결과

Godot 4.2.2 headless Slice A–J 전체 통과:

`A 10, B 15, C 25, D 29, E 27, F 27, G 31, H 30, I 19, J 18` — 총 231 passed / 0 failed

실행 예:

```powershell
& '.\Godot_v4.2.2-stable_win64.exe\Godot_v4.2.2-stable_win64_console.exe' --headless --path '.' --quit-after 240 'res://game/tests/slice_f_test.tscn'
```

## 다음 작업

1. `prop_rock`, `prop_crate`, `prop_ruin` Definition/View와 Operation 장식 레이어
2. `WorldFact`를 소비하는 Hit/Defeat/Build/Extraction VFX
3. 압박·피격·건설·종료·환경 Audio Presenter
4. 필요 시 Terrain의 `walkable/buildable` 플래그를 실제 BuildGrid 셀 태그와 연결

## 의도적으로 단순화한 부분

현재 웨이브는 `OperationDefinition.enemy_spawn_waves`의 고정 Spawn 후보를 사용한다. Seed 기반 후보 선택, 시야/금지 영역 검사, 복수 후보 재시도는 실제 맵과 Prop/시야 시스템이 추가될 때 확장한다.
