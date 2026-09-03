# Vivv Greenfield Game Architecture

> 기준선: Greenfield G1
> 상태: 신규 게임 및 신규 코드베이스의 규범 문서
> 엔진 기준: Godot 4.2
> 범위: 게임 흐름, 런타임 구조, 설치·연결·전투·보상·저장·검증
> 제외: 적 수, 탄약 수, 피해량, 비용, 시간, 확률 등 밸런스 값

---

## 0. 이 문서의 선언

이 문서는 기존 Vivv 구현을 개선하는 문서가 아니다. 기존 클래스, 폴더, Autoload, 저장 형식, 낮/밤 흐름, 네트워크 구조, 테스트, 데이터 ID와 호환될 의무가 없는 완전 신규 설계다.

기존 코드는 구현 시 참고 자료가 아니라 폐기 가능한 레거시로 취급한다. 에셋은 새 Definition 계약에 맞는 경우에만 다시 사용할 수 있다.

### 0.1 설계 입력

새 설계가 유지하는 제품 수준의 입력은 다음뿐이다.

- Godot 기반의 2D 아이소메트릭 실시간 게임이다.
- 플레이어가 직접 이동하고 탐사하며 전투한다.
- 셀 기반 구조물을 설치하고 기지를 확장한다.
- 같은 계열 블록이 맞닿으면 외형이 자연스럽게 연결된다.
- 탐사에서 얻은 가치가 건축과 성장으로 이어진다.
- 적의 압박을 견디고 작전 결과를 정산한다.
- 정확한 수치는 코드가 아니라 콘텐츠 데이터가 결정한다.

그 밖의 모든 흐름과 경계는 이 문서에서 새로 결정한다.

### 0.2 규범 용어

- 필수: 구현이 반드시 지켜야 한다.
- 금지: 구현하면 안 된다.
- 선택: 실제 요구나 측정 결과가 있을 때만 추가한다.
- Definition: 제작자가 편집하는 불변 콘텐츠 데이터다.
- Runtime State: 플레이 중 변하는 권위 상태다.
- Derived State: 권위 상태에서 다시 계산할 수 있는 캐시나 표현 상태다.
- Action: 플레이어나 게임 규칙이 요청한 의도다.
- Fact: 이미 확정된 결과를 설명하는 불변 기록이다.

### 0.3 비목표

다음은 G1의 목표가 아니다.

- 기존 저장 데이터 마이그레이션
- 기존 API 또는 Scene 경로 호환
- Dedicated Server, P2P, Host Migration
- 범용 ECS, 범용 Workflow Engine, 범용 Rule DSL
- 모든 시스템을 위한 Interface와 Factory
- 실측 전 Object Pool, 멀티스레드, 증분 그래프 최적화
- 밸런스 표와 콘텐츠 목록

멀티플레이 요구가 확정되기 전까지 게임은 단일 권위 프로세스로 만든다. 다만 입력을 Action으로 받고 표현을 상태에서 분리하여 이후 권위 프로세스를 서버로 옮길 수 있는 최소 경계는 유지한다.

---

## 1. 새 게임의 정체성

### 1.1 한 문장

Vivv는 위험 지역에 거점을 심고, 탐사하면서 연결형 방어망을 확장한 뒤, 스스로 선택한 순간에 탈출을 감행하는 실시간 액션·건축 생존 게임이다.

### 1.2 기존 흐름과의 단절

새 게임에는 탐사 Scene과 방어 Scene이 분리된 낮/밤 반복이 없다. 한 작전은 하나의 지속되는 맵에서 진행된다.

플레이어는 같은 공간에서 다음 행동을 계속 선택한다.

- 안전한 거점 주변을 강화한다.
- 더 멀리 탐사해 목표와 자원을 찾는다.
- 자원을 들고 돌아와 보관하거나 현장에서 소비한다.
- 소음과 활동으로 커진 압박에 대응한다.
- 필수 목표를 달성한 뒤 더 욕심낼지 탈출할지 결정한다.

이 선택들이 하나의 공간과 하나의 OperationState 안에서 충돌하게 만드는 것이 새 설계의 핵심이다.

### 1.3 핵심 설계 기둥

#### 공간은 곧 전략이다

벽, 길, 동력선, 포탑은 단순 장식이 아니다. 구조물의 위치와 연결이 이동 경로, 방어 범위, 가동 여부를 바꾼다.

#### 안전은 직접 만들어야 한다

플레이어에게 영구적으로 안전한 전투 구역을 주지 않는다. 설치한 구조물, 확보한 시야, 열린 퇴로가 현재의 안전을 만든다.

#### 욕심은 압박을 키운다

탐사, 채굴, 목표 수행, 대형 설비 가동, 탈출 호출 같은 행동은 ThreatDirector의 입력이 된다. 작전의 난이도는 고정된 밤 전환보다 플레이어의 선택에 반응한다.

#### 획득과 확정은 다르다

바닥에서 주운 물자는 아직 보상이 아니다. 운반 중인 물자, 거점에 확보한 물자, 작전 종료 후 계정에 정산된 보상을 구분한다.

#### 실패도 하나의 결과다

실패는 상태를 임의로 되돌리는 예외가 아니다. OperationOutcome으로 확정되고, 보존되는 것과 잃는 것이 RewardPolicy에 따라 정산된다.

### 1.4 유사작에서 가져오는 원리

유사작의 콘텐츠나 흐름을 복제하지 않고 다음 원리만 참고한다.

| 참고 대상 | 공식 설명에서 확인되는 원리 | Vivv에서의 재해석 |
|---|---|---|
| The Riftbreaker | 직접 전투, 탐사, 자원 수집, 기지 건설이 같은 경험을 이룸 | 탐사와 건축을 별도 모드가 아닌 한 작전 공간에 둔다 |
| They Are Billions | 확장, 자원망, 방어선, 소음과 적 압박이 서로 영향을 줌 | 모든 활동을 ThreatDirector의 입력으로 통합한다 |
| The Last Spell | 희소 자원을 전투력과 방어 시설 사이에서 선택함 | 운반 물자를 현장 소비할지 안전하게 정산할지 선택하게 한다 |
| Godot TileMap Terrain | 인접 셀 조건으로 연결 타일을 선택할 수 있음 | 바닥·도로 표현은 엔진 Terrain을 쓰고, 개별 구조물은 명시적 연결 마스크를 쓴다 |

Vivv의 독자성은 고정된 준비/방어 교대가 아니라 연속 작전, 플레이어가 선택하는 탈출 시점, 운반·확보·정산으로 이어지는 가치 상태, 시각 연결과 기능 연결을 분리한 모듈 건축에 있다.

---

## 2. 전체 게임 흐름

### 2.1 상위 흐름

~~~text
Boot
  → Main Menu
  → Campaign
  → Briefing
  → Operation
  → Settlement
  → Campaign
~~~

AppFlowState만 상위 화면 전환을 소유한다. UI 버튼이나 Operation 내부 시스템이 Scene을 직접 교체하면 안 된다.

### 2.2 Campaign

Campaign은 작전 사이에 유지되는 영구 진행 상태다.

CampaignState는 다음을 소유한다.

- 접근 가능한 지역과 작전
- 해금한 청사진과 장비 Definition ID
- 영구 자원과 연구 상태
- 선택하지 않은 보상 제안
- 완료한 작전 결과 요약
- 콘텐츠 버전과 저장 버전

Campaign은 실시간 전투 상태를 소유하지 않는다. 플레이어 HP, 현재 탄약, 맵 위 구조물, 적, 투사체는 OperationState에 속한다.

### 2.3 Briefing

Briefing에서 플레이어는 다음을 확정한다.

- OperationDefinition
- 시작 Loadout
- 사용 가능한 Blueprint 세트
- 선택형 위험 조건
- 작전 시작에 소비되는 영구 자원

StartOperationAction은 이 선택을 한 번에 검증하고 CampaignState의 비용 차감과 OperationState 생성을 원자적으로 처리한다. 중간 실패 시 둘 다 바뀌지 않는다.

### 2.4 Operation

Operation은 다음 상태를 순서대로 가진다.

~~~text
CREATING
  → INSERTION
  → ACTIVE
  → EXTRACTION
  → RESOLVING
  → CLOSED
~~~

- CREATING: Seed로 맵, 목표, 출현 지점을 생성하고 검증한다.
- INSERTION: 플레이어와 Core를 배치하고 입력을 잠시 제한한다.
- ACTIVE: 탐사, 건축, 전투, 목표 수행이 동시에 진행된다.
- EXTRACTION: 탈출 요청이 확정되고 탈출 조건과 최종 압박을 처리한다.
- RESOLVING: 모든 결과를 멈추고 OperationOutcome과 RewardSettlement를 만든다.
- CLOSED: 런타임 객체를 정리한 읽기 전용 상태다.

ACTIVE 안에 별도 낮/밤 Phase를 만들지 않는다. 조도나 날씨 변화가 필요하면 WorldCondition으로 표현하며, 전체 시스템 상태 머신을 갈아타지 않는다.

### 2.5 ACTIVE의 반복

~~~text
탐색
  → 발견
  → 획득 또는 목표 수행
  → 운반
  → 거점 확장 또는 장비 소비
  → 압박 대응
  → 더 깊이 진입하거나 탈출
~~~

이 흐름은 강제 순서가 아니다. 플레이어는 압박 중에도 건설할 수 있고, 탐사 중에도 임시 구조물을 설치할 수 있다. 각 Action의 허용 여부는 Operation 상태와 Definition 정책으로 판단한다.

### 2.6 탈출

필수 목표가 충족되면 ExtractionEligibility가 열린다. 자동으로 작전을 끝내지 않는다.

RequestExtractionAction이 승인되면 다음이 한 번에 일어난다.

- Operation 상태가 EXTRACTION으로 바뀐다.
- 탈출 지점과 탈출 조건이 고정된다.
- ThreatDirector가 ExtractionPressure를 시작한다.
- 새 선택 목표 생성이 중단된다.
- HUD에 성공 조건과 미확보 물자를 명확히 표시한다.

탈출 성공, 전원 무력화, Core 파괴, 명시적 포기와 같은 종료 원인은 서로 다른 OperationEndReason으로 기록한다.

### 2.7 정산

OperationOutcome은 종료 순간의 불변 사실이다. Settlement는 이 사실만 읽는다.

정산 순서는 다음과 같다.

1. 종료 원인 확정
2. 운반·확보·목표·발견 기록 봉인
3. RewardPolicy 적용
4. RewardLedger에 항목 생성
5. CampaignState에 아직 적용되지 않은 항목만 반영
6. 선택형 보상 제안 생성
7. 저장 성공
8. Settlement UI 공개

UI나 남아 있는 Scene Node를 훑어 보상을 계산하는 것은 금지한다.

---

## 3. 아키텍처 형식

### 3.1 Godot-native feature architecture

새 코드는 기술 레이어보다 기능 단위로 묶는다. 한 기능의 상태, 규칙, Controller, View가 가까이 있어야 한다.

~~~text
game/
  app/
    app_root.tscn
    app_root.gd
    app_flow_state.gd
  content/
    content_manifest.gd
    content_catalog.gd
    content_validator.gd
    definitions/
  campaign/
    campaign_state.gd
    campaign_controller.gd
    campaign_screen.tscn
  operation/
    operation.tscn
    operation_controller.gd
    operation_state.gd
    operation_clock.gd
    operation_outcome.gd
  building/
    build_grid.gd
    build_rules.gd
    build_controller.gd
    connection_resolver.gd
    build_view.gd
  inventory/
    inventory_state.gd
    inventory_rules.gd
    inventory_controller.gd
  combat/
    combat_controller.gd
    damage_rules.gd
    projectile.tscn
  enemies/
    threat_director.gd
    spawn_planner.gd
    enemy_agent.tscn
    path_service.gd
  objectives/
    objective_state.gd
    objective_controller.gd
  rewards/
    reward_ledger.gd
    reward_rules.gd
    settlement_service.gd
  save/
    save_store.gd
    save_codec.gd
    save_schema.gd
  presentation/
    operation_hud.tscn
    operation_presenter.gd
    build_preview.tscn
  shared/
    action_result.gd
    game_ids.gd
    world_fact.gd
  tests/
~~~

systems, managers, utils 같은 포괄 폴더는 만들지 않는다. 파일의 소유 기능이 불분명하면 경계가 잘못된 것이다.

### 3.2 Scene tree

~~~text
AppRoot
├── ContentCatalog
├── SaveStore
├── AppFlow
└── CurrentScreen
    └── Operation
        ├── OperationController
        ├── World
        │   ├── GroundTileMap
        │   ├── BuildTileMap
        │   ├── DynamicEntities
        │   ├── Pickups
        │   └── WorldEffects
        ├── Features
        │   ├── BuildController
        │   ├── InventoryController
        │   ├── CombatController
        │   ├── ObjectiveController
        │   └── ThreatDirector
        └── Presentation
            ├── OperationPresenter
            ├── HUD
            └── BuildPreview
~~~

AppRoot는 main_scene이며 앱 실행 동안 유지된다. G1은 Autoload를 사용하지 않는다. 전역 접근이 필요한 것처럼 보이는 객체도 AppRoot가 명시적으로 전달한다.

### 3.3 의존 방향

~~~text
Presentation
    ↓ requests / reads
Feature Controller
    ↓
Rules + Runtime State
    ↓
Godot native services and ContentCatalog
~~~

- Presentation은 Runtime State를 직접 수정하지 않는다.
- Rules는 UI Node를 참조하지 않는다.
- Content Definition은 Runtime Node를 참조할 수 없고 PackedScene 같은 표현 참조만 가진다.
- 기능 간 변경은 상대 기능의 공개 메서드를 호출하거나 OperationController가 하나의 거래로 조정한다.
- 전역 EventBus는 만들지 않는다.

### 3.4 상태 권위

권위는 한 프로세스의 OperationController에 있다.

| 상태 | 단일 작성자 |
|---|---|
| AppFlowState | AppRoot |
| CampaignState | CampaignController |
| OperationState | OperationController |
| BuildGrid, BuildSite, Structure | BuildController |
| Inventory와 Reservation | InventoryController |
| Damage, Health, Status | CombatController와 대상 Entity |
| ObjectiveState | ObjectiveController |
| ThreatState와 SpawnTicket | ThreatDirector |
| RewardLedger | SettlementService |
| 화면과 효과 | 해당 View 또는 Presenter |

한 상태를 두 Controller가 직접 수정하지 않는다. 여러 상태를 함께 바꿔야 하면 OperationController가 거래를 조정한다.

### 3.5 단일 스레드

모든 게임 규칙과 SceneTree 변경은 메인 스레드에서 실행한다. G1은 Worker Thread를 만들지 않는다.

무거운 작업이 실측되면 순수 데이터 계산만 WorkerThreadPool로 보낼 수 있다. Node, Resource, PhysicsServer 상태를 작업 스레드에서 수정하지 않는다.

---

## 4. 런타임 처리 모델

### 4.1 Action에서 화면까지

~~~text
Input 또는 UI
  → Action Request
  → 현재 상태 재검증
  → 규칙 Decision
  → 원자적 Commit
  → WorldFact 발행
  → Derived State 갱신
  → Presenter와 View 반영
~~~

Action은 미래 의도이고 Fact는 이미 일어난 결과다. 둘을 같은 Signal 이름으로 섞지 않는다.

### 4.2 Action의 공통 필드

모든 변경 Action은 다음 의미를 가진다.

| 필드 | 의미 |
|---|---|
| action_id | 같은 요청의 중복 실행을 막는 ID |
| actor_id | 행동 주체 |
| operation_id | 대상 작전 |
| issued_tick | 입력이 만들어진 Simulation Tick |
| expected_revision | Preview 이후 상태가 바뀌었는지 확인할 때 사용 |
| payload | Action 종류별 최소 데이터 |

싱글플레이에서도 action_id를 유지한다. 버튼 중복 입력, 저장 복구 후 재실행, 향후 네트워크 전환을 같은 방식으로 방지한다.

### 4.3 ActionResult

모든 변경 API는 ActionResult를 반환한다.

~~~text
ActionResult
  accepted
  action_id
  reason_code
  changed_revision
  facts
~~~

예상 가능한 거절은 오류가 아니다. UI는 reason_code를 현지화된 안내로 바꾼다.

대표 거절 코드는 다음과 같다.

- WRONG_OPERATION_STATE
- ACTOR_NOT_AVAILABLE
- UNKNOWN_DEFINITION
- OUT_OF_BOUNDS
- OCCUPIED
- TERRAIN_NOT_ALLOWED
- DISCONNECTED
- ROUTE_BLOCKED
- NOT_ENOUGH_RESOURCE
- INVENTORY_FULL
- TARGET_INVALID
- STALE_PREVIEW
- OBJECTIVE_INCOMPLETE
- ALREADY_RESOLVED

문자열 메시지를 게임 규칙으로 비교하는 것은 금지한다.

### 4.4 원자적 Commit

둘 이상의 상태를 함께 바꾸는 Action은 먼저 모든 변경을 계산한 뒤 한 번에 Commit한다.

PlaceBuildAction의 예:

1. BuildRules가 Footprint와 Grid를 검증한다.
2. InventoryRules가 비용을 예약할 수 있는지 검증한다.
3. PathService가 결과 Grid에서 필수 경로를 확인한다.
4. 모두 성공하면 Grid Reservation, Item Reservation, BuildSite를 함께 적용한다.
5. 하나라도 실패하면 어떤 상태도 바꾸지 않는다.

Commit 도중 예외가 발생할 수 있는 파일 I/O나 Scene 로드는 넣지 않는다. 필요한 Resource는 Boot에서 검증하고 미리 로드한다.

### 4.5 Fact

Fact는 다음 용도로만 쓴다.

- 다른 기능이 확정 결과에 반응
- View와 VFX 갱신
- Objective와 Threat 입력
- 디버그 Trace
- RewardSettlement 입력

대표 Fact:

- ITEM_ACQUIRED
- ITEM_SECURED
- BUILD_SITE_CREATED
- STRUCTURE_COMPLETED
- STRUCTURE_REMOVED
- CONNECTIONS_CHANGED
- DAMAGE_APPLIED
- ENTITY_DEFEATED
- OBJECTIVE_COMPLETED
- EXTRACTION_REQUESTED
- OPERATION_ENDED
- REWARD_SETTLED

Fact는 발행 후 과거 상태를 다시 조회하지 않아도 되도록 필요한 ID와 결과 값을 담는다. 반대로 전체 Entity 객체나 Node 참조를 담으면 안 된다.

### 4.6 Tick 순서

OperationController는 _physics_process에서 SimulationProfile의 Tick 정책으로 다음 순서를 고정한다.

1. 외부 Action Queue 비우기
2. 플레이어 이동과 상호작용 의도 적용
3. 건축·인벤토리 Action Commit
4. Objective와 Threat 입력 수집
5. AI 의사결정
6. 이동과 충돌
7. 공격, 투사체, 피해
8. 죽음과 드롭 확정
9. Build Work와 구조물 기능 실행
10. Objective와 Threat 상태 전이
11. Dirty Grid, 연결, 경로 캐시 갱신
12. Fact 묶음 전달
13. 종료 조건 평가

한 Tick 중 생성된 Entity는 다음 안전 지점부터 AI와 공격 대상이 된다. 제거 대상은 즉시 inactive로 표시하되 queue_free는 Tick 종료 후 실행한다.

### 4.7 시간

- 게임 규칙은 Tick 또는 OperationClock의 논리 시간을 사용한다.
- UI 애니메이션은 프레임 시간을 사용할 수 있다.
- Definition의 초 단위 값은 Catalog 빌드 시 Tick으로 변환한다.
- OS 시계는 저장 시각과 로그에만 사용한다.
- 일시정지는 OperationClock과 Simulation을 멈추지만 UI는 계속 동작할 수 있다.

### 4.8 RNG

OperationState는 Seed와 명명된 RNG Stream 상태를 소유한다.

권장 Stream:

- WORLD
- OBJECTIVE
- THREAT
- SPAWN
- LOOT
- REWARD_CHOICE

표현용 흔들림과 파티클은 게임 RNG를 소비하지 않는다. 같은 Seed와 같은 Action 순서가 같은 규칙 결과를 만들도록 유지한다.

---

## 5. 상태 모델

### 5.1 ID

Runtime 객체는 Node 경로나 배열 인덱스로 식별하지 않는다.

| ID | 범위 |
|---|---|
| campaign_id | 영구 진행 |
| operation_id | 한 작전 |
| entity_id | 플레이어, 적, 구조물, Pickup |
| container_id | 인벤토리와 보관함 |
| build_site_id | 건설 작업 |
| objective_id | 목표 Runtime |
| action_id | 변경 요청 |
| fact_id | 확정 결과 |
| ledger_entry_id | 보상 정산 |
| definition_id | 콘텐츠 데이터 |

ID는 저장과 복구 후에도 같은 대상을 가리킨다.

### 5.2 Revision

Revision은 Preview와 캐시 무효화에만 사용한다.

- operation_revision: 권위 상태 Commit마다 증가
- grid_revision: 점유나 지형 통과성이 바뀔 때 증가
- topology_revision: 연결형 구조물 관계가 바뀔 때 증가
- navigation_revision: 경로 가능 셀이 바뀔 때 증가
- inventory_revision: Container 내용이 바뀔 때 증가

모든 객체에 개별 Revision을 붙이지 않는다. 실제 충돌 검사가 필요한 경계에만 둔다.

### 5.3 OperationState

~~~text
OperationState
  identity
  definition_id
  lifecycle_state
  logical_tick
  rng_streams
  player_records
  world_state
  build_state
  objective_state
  threat_state
  operation_ledger
  end_state
~~~

World Node 자체를 직렬화하지 않는다. 각 소유자가 자신의 Runtime State를 Save DTO로 내보낸다.

### 5.4 Entity lifecycle

모든 Runtime Entity는 다음 수명 주기를 따른다.

~~~text
REQUESTED
  → SPAWNING
  → ACTIVE
  → DYING 또는 DESPAWNING
  → REMOVED
~~~

- REQUESTED: Spawn 요청만 존재한다.
- SPAWNING: ID와 상태가 등록됐지만 규칙 대상이 아니다.
- ACTIVE: Tick, 충돌, 공격 대상에 참여한다.
- DYING: 사망 결과는 확정됐고 추가 피해를 받지 않는다.
- DESPAWNING: 거리 정리나 작전 종료로 제거된다.
- REMOVED: Registry에서 제거된 상태다.

ENTITY_DEFEATED는 ACTIVE에서 DYING으로 처음 전이할 때 한 번만 발행한다.

### 5.5 저장하지 않는 Derived State

다음은 저장하지 않고 복구 후 다시 만든다.

- 연결 마스크와 Sprite Variant
- AStar 경로와 경로 캐시
- HUD ReadModel
- 선택 윤곽과 Build Preview
- 시야용 임시 Polygon
- Target 후보 목록
- 파티클, Tween, 카메라 흔들림
- 재생 가능한 최근 Fact
- Utility Network의 계산 캐시

---

## 6. 콘텐츠 데이터

### 6.1 ContentManifest

런타임 디렉터리 검색 대신 하나의 ContentManifest Resource가 모든 Definition을 명시적으로 참조한다.

Boot 순서:

1. ContentManifest 로드
2. Definition ID 인덱스 생성
3. 교차 참조 검증
4. 값 정규화와 Tick 변환
5. Catalog Hash 생성
6. 검증 성공 후 Main Menu 진입

중복 ID나 누락 참조가 있으면 플레이를 시작하지 않는다.

### 6.2 Definition 종류

| Definition | 책임 |
|---|---|
| OperationDefinition | 맵 생성, 목표 집합, 종료 정책, 허용 콘텐츠 |
| TerrainDefinition | 지형 태그, 이동 가능 여부, 건축 허용 태그 |
| ItemDefinition | Stack, 무게, 용도, 표현 |
| StructureDefinition | Footprint, 점유 채널, 비용, BuildSite, 기능 |
| ConnectionSetDefinition | 호환 그룹, 마스크별 표현 Variant |
| UtilityDefinition | Port 종류, 공급·소비 의미 |
| WeaponDefinition | 공격 방식, 비용, 발사체, 피해 규칙 |
| EnemyDefinition | 이동, 감지, 공격, 드롭, 압박 태그 |
| ObjectiveDefinition | 조건 종류, 선행 목표, 결과 |
| ThreatDefinition | 압박 입력, Event 후보, Spawn 정책 |
| RewardPolicyDefinition | 종료 원인별 보존·변환·제안 규칙 |
| SimulationProfile | Tick과 기술적 Simulation 정책 |
| PresentationDefinition | Scene, Sprite, Sound, VFX |

수치는 모두 Definition에 있고 Controller에 중복 상수로 존재하면 안 된다.

### 6.3 Definition과 Runtime State 분리

Definition은 플레이 중 수정하지 않는다. Runtime State는 definition_id만 저장한다.

예:

~~~text
StructureDefinition
  id
  footprint
  occupancy_channels
  terrain_requirements
  connection_group
  functional_ports
  build_cost
  build_work
  max_health
  scene

StructureState
  entity_id
  definition_id
  anchor_cell
  rotation
  lifecycle
  health
  runtime_flags
~~~

Save에 max_health나 Sprite 경로를 복사하지 않는다.

### 6.4 ContentValidator

Headless에서도 실행 가능한 Validator가 최소한 다음을 확인한다.

- 모든 Definition ID의 유일성
- 모든 참조 ID의 존재
- Footprint가 비어 있지 않고 Anchor를 포함
- 회전된 Footprint에 중복 셀이 없음
- 연결 그룹의 모든 필수 Variant 존재
- 비용 Item이 실제 ItemDefinition을 가리킴
- Structure Scene이 필수 계약을 만족
- Objective Graph가 순환하지 않음
- Operation이 종료 가능한 목표 경로를 가짐
- RewardPolicy가 모든 OperationEndReason을 처리
- 저장 가능한 Enum과 ID가 안정적임

### 6.5 데이터 변경 절차

새 콘텐츠를 추가할 때는 다음만 수행한다.

1. 기존 Definition 종류로 표현 가능한지 확인
2. Resource 작성
3. ContentManifest에 등록
4. Validator 실행
5. 해당 기능 Scenario Test 실행

새로운 행동 의미가 없으면 새 Controller나 Interface를 만들지 않는다.

---

## 7. Operation Objective와 Threat

### 7.1 Objective Graph

작전 목표는 하나의 거대한 Script가 아니라 작은 Objective Node의 DAG로 정의한다.

ObjectiveRuntimeState:

- objective_id
- definition_id
- state: LOCKED, AVAILABLE, ACTIVE, COMPLETED, FAILED
- progress
- activated_tick
- resolved_tick

지원하는 조건 종류는 코드로 명시한다.

- REACH_AREA
- INTERACT_ENTITY
- ACQUIRE_TAGGED_ITEM
- SECURE_TAGGED_ITEM
- BUILD_TAGGED_STRUCTURE
- DEFEND_ENTITY
- DEFEAT_TAGGED_ENTITY
- SURVIVE_PRESSURE_EVENT
- START_EXTRACTION

범용 문자열 수식 평가기는 만들지 않는다. 새 조건 의미가 실제로 필요할 때 명시적 Handler를 추가한다.

### 7.2 Fact-driven progress

ObjectiveController는 Fact를 받아 관련 Objective만 갱신한다.

예:

~~~text
ITEM_SECURED
  → tag가 일치하는 SECURE_TAGGED_ITEM 목표 조회
  → progress 갱신
  → 완료 조건 판단
  → OBJECTIVE_COMPLETED 발행
  → 후속 Objective 잠금 해제
~~~

매 Tick 전체 World를 훑어 목표를 계산하지 않는다.

### 7.3 Threat model

ThreatState는 다음 개념을 소유한다.

- 현재 Pressure Tier
- 누적 Pressure
- 최근 자극의 감쇠 상태
- 활성 PressureEvent
- 예약된 SpawnTicket
- Recovery 상태
- Extraction Pressure 여부

Pressure 입력은 Fact에서 온다.

- 전투 소음
- 채굴과 대형 상호작용
- 작동 중인 설비
- 목표 완료
- 확보 영역 확장
- 탈출 요청

정확한 가중치와 감쇠는 ThreatDefinition에 있다.

### 7.4 PressureEvent

PressureEvent는 고정 Wave 번호가 아니라 다음 수명 주기를 가진다.

~~~text
PLANNED
  → TELEGRAPHED
  → ACTIVE
  → RESOLVED
  → RECOVERY
~~~

- PLANNED: Seed 기반으로 유형과 출현 방향을 정한다.
- TELEGRAPHED: 플레이어에게 방향과 위험 신호를 전달한다.
- ACTIVE: SpawnTicket을 발행하고 적을 추적한다.
- RESOLVED: Event가 소유한 SpawnTicket과 적이 모두 종료됐다.
- RECOVERY: 다음 압박을 바로 겹치지 않도록 상태를 정리한다.

ThreatDirector는 적을 직접 생성하지 않고 SpawnPlanner에 SpawnTicket을 준다.

### 7.5 공정성 규칙

- 화면 바로 안쪽이나 플레이어가 보고 있는 빈 공간에 갑자기 생성하지 않는다.
- Spawn 지점에서 유효한 공격 목표까지 경로가 있어야 한다.
- Telegraph 없이 치명적 상태 전이를 만들지 않는다.
- 플레이어가 설치 화면을 열었다는 이유만으로 Simulation을 몰래 멈추지 않는다.
- 압박 변경은 HUD, 사운드, 환경 표현 중 하나 이상으로 전달한다.

---

## 8. 건축 시스템

건축은 BuildGrid의 논리 상태, Inventory의 자원 상태, Structure Scene의 표현을 하나의 Action으로 연결하는 핵심 기능이다.

### 8.1 논리 Grid와 아이소메트릭 표현

게임 규칙은 정사각 논리 좌표 Vector2i를 사용한다. 아이소메트릭은 표현 변환일 뿐 규칙 좌표가 아니다.

- 화면 또는 World 위치 → BuildTileMap.local_to_map
- Cell → BuildTileMap.map_to_local
- 저장, 경로, 연결, Footprint → Vector2i
- Sprite 방향과 Z 정렬 → View 책임

회전은 논리 좌표에서 먼저 적용한 뒤 World 위치로 변환한다.

### 8.2 Grid 채널

한 Cell은 서로 다른 점유 채널을 가진다.

| 채널 | 예 |
|---|---|
| GROUND | 바닥, 도로, 함정 바닥 |
| SOLID | 벽, Core, 포탑, 작업대 |
| UTILITY | 전력선, 신호선 |
| INTERACTION | 문 사용 지점, 작업 공간 |

StructureDefinition은 자신이 점유하고 배타적으로 막는 채널을 선언한다. 바닥 위에 포탑을 놓을 수 있지만 두 SOLID 구조물이 겹칠 수 없는 식의 규칙을 데이터로 표현한다.

### 8.3 BuildCell

BuildGrid는 희소 Dictionary로 Cell 상태를 보관한다.

~~~text
BuildCell
  terrain_tags
  occupants_by_channel
  reservation_id
  blocked_for_player
  blocked_for_enemy
  build_zone_id
~~~

빈 Cell 객체를 맵 전체에 미리 만들지 않는다. 지형 정보는 TileMap 또는 WorldGeneration 결과에서 조회하고 변경된 Cell만 Runtime State에 둔다.

### 8.4 Footprint

Footprint는 Anchor 기준 상대 좌표 집합이다.

배치 셀 계산:

1. Definition의 상대 좌표를 읽는다.
2. 요청 Rotation을 적용한다.
3. Anchor Cell을 더한다.
4. 정렬된 절대 셀 목록을 만든다.

정렬 순서는 Commit, 저장, 테스트에서 동일해야 한다.

### 8.5 BuildRequest

~~~text
BuildRequest
  action_id
  actor_id
  structure_definition_id
  anchor_cell
  rotation
  expected_grid_revision
  placement_mode
  stroke_cells
~~~

placement_mode는 SINGLE과 STROKE만 G1에서 지원한다. Blueprint 복사, 자동 설계, 대칭 설치는 실제 요구가 생길 때 추가한다.

### 8.6 Preview

Preview는 읽기 전용 계산이다. Runtime State나 Inventory를 바꾸지 않는다.

BuildPreview는 다음을 제공한다.

- valid
- anchor_cell
- footprint_cells
- rejected_cells와 reason_code
- 필요한 Item 요약
- 예상 연결 Variant
- 예상 Utility 연결
- 예상 경로 차단 여부
- 계산에 사용한 grid_revision

검증 순서는 고정한다.

1. Definition 존재
2. Operation 상태에서 건축 허용
3. Actor가 건축 가능
4. 맵 경계
5. Build Zone
6. Terrain Tag
7. 채널 점유
8. 기존 Reservation
9. 지지와 연결 조건
10. 상호작용 공간
11. 필수 경로 보존
12. Inventory 자원

가장 먼저 실패한 기술 이유와 모든 실패 Cell을 함께 반환한다. HUD는 가장 중요한 사용자 안내 하나를 선택하되 Debug Overlay는 전체 이유를 볼 수 있어야 한다.

### 8.7 Preview 표현

- 유효 Cell은 승인 색상으로 표시한다.
- 무효 Cell은 거절 색상과 원인 Icon을 표시한다.
- 연결형 구조물은 새 구조물뿐 아니라 모양이 바뀔 기존 이웃도 미리 보여준다.
- 비용 부족과 위치 무효를 같은 색만으로 구분하지 않는다.
- Confirm 입력 전에는 Collision, Navigation, Inventory를 바꾸지 않는다.
- Preview Node는 OperationState에 저장하지 않는다.

### 8.8 Placement Commit

Confirm 후 BuildController는 Preview 결과를 신뢰하지 않고 현재 상태로 다시 검증한다.

승인 절차:

1. action_id 중복 확인
2. expected_grid_revision 확인
3. Footprint 재계산
4. BuildRules 재검증
5. Inventory 비용 Reservation 생성
6. Grid Cell Reservation 생성
7. BuildSiteState 생성
8. 하나의 Commit으로 Reservation과 BuildSite 적용
9. BUILD_SITE_CREATED 발행
10. BuildSite View 생성
11. 영향 Cell을 Dirty Set에 추가

Scene 생성 실패는 정상 Commit 뒤에 발견되면 안 된다. StructureDefinition의 Scene은 Boot Validator에서 사전 검증한다.

### 8.9 BuildSite lifecycle

~~~text
RESERVED
  → CONSTRUCTING
  → COMPLETED
  ↘ CANCELLED
  ↘ DESTROYED
~~~

BuildSiteState:

- build_site_id
- entity_id
- definition_id
- owner_id
- anchor_cell
- rotation
- footprint_cells
- reserved_items
- committed_items
- work_progress
- state

Build Work가 들어오면 Definition 정책에 따라 예약 Item이 소비 상태로 이동한다. 완료 순간 entity_id를 유지한 채 StructureState로 전환한다.

Node를 삭제하고 새 ID로 다시 만들지 않는다. Target, 저장, Fact가 같은 설치물을 계속 가리킬 수 있어야 한다.

### 8.10 자원 Reservation

건설 비용은 Confirm 시 Inventory에서 예약한다.

- 예약 Item은 다른 소비 Action에서 사용할 수 없다.
- 예약만으로 Container에서 Item을 제거하지 않는다.
- 건설 진행에 따라 예약 일부를 committed로 옮긴다.
- Cancel은 미소비 예약을 해제한다.
- 소비된 부분의 반환 여부는 StructureDefinition의 CancelPolicy가 결정한다.
- BuildSite 파괴도 같은 Settlement 규칙을 사용한다.

Inventory 총량은 available + reserved + committed 전이 중 보존되어야 한다.

### 8.11 STROKE 설치

벽이나 바닥을 드래그하면 BuildRules가 화면 선이 아니라 Cell 경로를 만든다.

처리 규칙:

- 중복 Cell 제거
- Cell 경로를 결정적 순서로 정렬
- 각 Segment Footprint 계산
- 전체 비용과 점유 충돌 계산
- Preview에서 무효 Segment를 개별 표시
- Confirm은 기본적으로 유효 Segment만 설치하지 않고 전체를 원자 처리

부분 설치는 비용과 연결 결과를 예상하기 어렵게 하므로 G1에서 금지한다. 사용성이 실제로 나쁘다고 확인될 때 명시적인 PARTIAL 모드를 별도 UX로 추가한다.

### 8.12 수리

RepairAction은 다음을 검증한다.

- 대상이 ACTIVE Structure인지
- 최대 상태가 아닌지
- Actor가 작업 가능한지
- Repair 비용을 예약할 수 있는지
- 다른 배타 작업이 진행 중이지 않은지

수리는 BuildSite와 같은 Work 모델을 재사용하지만 Structure ID와 점유는 유지한다.

### 8.13 철거

RemoveStructureAction은 플레이어가 의도한 안전한 제거다.

1. 대상과 권한 검증
2. 연결·경로 결과 Preview
3. 철거 Work 시작
4. 완료 시 점유 해제
5. RemovePolicy에 따른 반환 Item 생성
6. 이웃 연결과 Utility Graph Dirty
7. STRUCTURE_REMOVED 발행

핵심 구조물이나 진행 중 Objective 대상은 정책에 따라 거절할 수 있다.

### 8.14 파괴

파괴는 Combat 결과다.

1. Health가 종료 조건에 도달
2. Structure를 DYING으로 표시
3. 기능과 Target 가능 상태 즉시 중단
4. Grid 점유를 DestructionPolicy에 따라 잔해 또는 빈 Cell로 전환
5. Utility 연결 끊기
6. Navigation Revision 증가
7. 이웃 Dirty
8. Drop 또는 Salvage Fact 생성
9. View 파괴 연출 후 제거

파괴 연출이 끝날 때까지 논리 점유 해제를 미루지 않는다.

### 8.15 연결형 구조물의 두 가지 연결

연결은 반드시 분리한다.

#### Visual Connection

인접한 구조물이 한 덩어리처럼 보이게 Sprite Variant를 고른다. Derived State이며 저장하지 않는다.

#### Functional Connection

전력, 신호, 방어 보너스처럼 실제 규칙에 영향을 주는 Graph다. Structure Port로 계산한다.

Visual Connection이 보인다고 자동으로 전력이 흐르면 안 된다. 반대로 숨겨진 Utility가 Sprite 연결 없이 기능적으로 이어질 수 있다.

### 8.16 연결 호환성

StructureDefinition은 connection_group과 compatible_groups를 가진다.

두 Cell A와 B가 연결되는 조건:

1. 둘 다 ACTIVE 또는 Preview 대상
2. 같은 Grid Layer
3. 논리적으로 Cardinal Neighbor
4. A가 B의 Group을 허용
5. B가 A의 Group을 허용
6. 상태가 연결을 금지하지 않음

문이 열렸다는 이유로 벽 외형 연결이 끊어지지 않는다. 통행 상태와 Visual Connection은 별도다.

### 8.17 Connection Mask

각 Cell은 논리 방향 NORTH, EAST, SOUTH, WEST의 연결 여부를 Mask로 표현한다.

Mask는 다음 외형 의미로 해석된다.

- 연결 없음: isolated
- 한 방향: end
- 마주 보는 두 방향: straight
- 직각 두 방향: corner
- 세 방향: tee
- 네 방향: cross

회전은 Variant를 중복 제작하기보다 base_variant와 rotation으로 표현할 수 있다. 아트가 방향별로 다르면 ConnectionSetDefinition이 명시적 Variant를 제공한다.

### 8.18 연결 계산

~~~text
resolve_mask(cell, overlay):
  mask = empty
  for direction in cardinal_directions:
    neighbor = cell + direction
    if can_connect(cell, neighbor, overlay):
      mask.add(direction)
  return mask
~~~

overlay는 Preview Cell과 아직 Commit되지 않은 STROKE를 포함하는 읽기 전용 가상 Grid다.

### 8.19 Dirty Cell 알고리즘

설치, 완료, 회전, 철거, 파괴, 연결 상태 변경 시 다음만 다시 계산한다.

~~~text
dirty = changed_footprint_cells
dirty += cardinal_neighbors(changed_footprint_cells)
dirty = unique_and_sorted(dirty)

for cell in dirty:
  recompute_visual_connection(cell)
  mark_functional_graph_component_dirty(cell)
~~~

맵 전체를 다시 그리지 않는다.

여러 변경이 같은 Tick에 생기면 Dirty Set을 합친 뒤 한 번만 처리한다.

### 8.20 Variant 적용

ConnectionResolver는 Mask를 다음 표현 데이터로 바꾼다.

~~~text
ConnectionVisual
  variant_key
  rotation
  flip
  damaged_overlay
  construction_overlay
~~~

Variant가 누락되면 임의 Sprite를 선택하지 않는다.

- 개발 빌드: Content validation failure
- 출시 빌드: isolated fallback과 오류 로그

### 8.21 TileMap Terrain 사용 범위

Godot 4.2 TileMap Terrain은 바닥, 도로, 토양 가장자리처럼 Collision과 개별 Health를 갖지 않는 대량 셀 표현에 사용한다.

벽, 문, 포탑처럼 Entity ID, Health, Interaction, 상태를 가진 구조물은 독립 Scene과 ConnectionResolver를 사용한다.

Terrain과 Entity 구조물을 한 방식으로 억지 통합하지 않는다.

### 8.22 Collision

- Collision은 논리 Structure 상태에서 결정한다.
- Sprite Variant가 Collision의 진실이 되면 안 된다.
- 일반 벽은 Footprint Cell 단위 Collider를 사용한다.
- 문은 열림 상태에 따라 Collider를 명시적으로 켜고 끈다.
- BuildSite가 길을 막는 시점은 StructureDefinition의 site_collision_policy가 결정한다.
- 파괴 시 Collider는 논리 상태 전이와 같은 Tick에 비활성화한다.

연결 Sprite의 이음새를 없애기 위해 Collider를 합치는 최적화는 G1에서 하지 않는다.

### 8.23 Navigation

적 경로는 BuildGrid와 같은 Cell 좌표를 사용하는 AStarGrid2D 하나를 기준으로 한다.

- Terrain 비용과 통행 가능 여부를 AStarGrid2D에 반영한다.
- SOLID 점유가 바뀌면 해당 Cell의 통행 상태를 바꾼다.
- navigation_revision을 증가시킨다.
- 기존 경로는 Revision과 다음 경로 Cell을 확인해 무효화한다.
- Build Preview의 ROUTE_BLOCKED 검사도 같은 PathService를 사용한다.

Preview와 실제 AI가 서로 다른 Navigation 모델을 사용하면 안 된다.

### 8.24 필수 경로 정책

OperationDefinition은 ProtectedTarget과 HostileEntry 집합을 가진다.

설치 결과가 모든 HostileEntry에서 모든 유효 ProtectedTarget까지의 경로를 제거하면 ROUTE_BLOCKED로 거절한다. 문이 통행 가능한 상태라면 경로로 인정하고, 잠긴 문은 인정하지 않는다.

일부 작전에서 완전 봉쇄를 허용하려면 별도 PathPolicy를 Definition으로 선택한다. BuildController에 작전 이름 예외를 넣지 않는다.

### 8.25 Functional Utility Graph

StructureDefinition의 Port:

- port_type
- local_cell
- direction
- role: SOURCE, SINK, RELAY
- enabled_condition

Graph는 호환 Port가 맞닿을 때 Edge를 만든다.

G1은 topology_revision이 바뀔 때 영향 Utility 종류의 Graph 전체를 다시 계산한다. 실제 맵 규모에서 병목이 측정될 때만 연결 Component 단위 증분 갱신으로 바꾼다.

계산 결과:

- component_id
- sources
- sinks
- reachable
- supplied_state

component_id와 supplied_state는 Derived State다. 저장 후 Structure와 Port로 재구성한다.

### 8.26 동시 변경과 stale Preview

싱글플레이에서도 Preview 이후 다음이 바뀔 수 있다.

- 적이 해당 Cell을 점유
- 구조물이 파괴
- Inventory 자원이 소비
- Operation 상태가 EXTRACTION으로 전이

Confirm은 expected_grid_revision과 inventory_revision을 비교하고 반드시 재검증한다. 오래된 Preview는 STALE_PREVIEW로 거절하고 즉시 새 Preview를 계산한다.

### 8.27 건축 불변식

- 한 Cell의 배타 채널에는 하나의 Occupant만 있다.
- 모든 Occupant는 유효한 Entity 또는 BuildSite를 가리킨다.
- 모든 BuildSite Reservation은 Inventory Reservation과 쌍을 이룬다.
- 구조물 삭제 후 Footprint에 고아 점유가 남지 않는다.
- 연결 Mask는 현재 이웃에서 다시 계산한 결과와 같다.
- 저장에는 Preview와 Visual Variant가 없다.
- Build Preview와 Commit은 같은 BuildRules를 호출한다.
- Path Preview와 AI는 같은 PathService를 호출한다.

---

## 9. Inventory, Loot, 현장 경제

### 9.1 Container

모든 Item 보관 위치는 같은 Container 모델을 사용한다.

- Player Pack
- Core Storage
- Structure Input
- Structure Output
- World Cache
- Reward Pending

ContainerState:

- container_id
- owner_id
- slot_policy
- capacity_policy
- item_stacks
- reservations
- revision

UI Slot Node가 Item을 소유하지 않는다.

### 9.2 Item 상태

작전에서 Item 가치는 다음 상태를 이동한다.

~~~text
WORLD
  → CARRIED
  → SECURED
  → CONSUMED
  → SETTLED
~~~

- WORLD: 맵에 떨어졌거나 Container에 아직 들어가지 않음
- CARRIED: Player Pack에 있어 실패 정책의 영향을 받음
- SECURED: Core Storage에 들어가 작전 중 안전 수준이 높음
- CONSUMED: 건축, 치료, 장비 사용으로 사용됨
- SETTLED: Operation 종료 후 CampaignState에 반영됨

정확한 보존 규칙은 RewardPolicy가 결정한다.

### 9.3 Transfer transaction

TransferItemAction:

1. Source와 Target Container 존재
2. Actor 접근 권한
3. Source Item과 수량
4. Reservation 제외 가용량
5. Target 수용 가능 여부
6. 양쪽 Revision 확인
7. Source 차감과 Target 추가를 한 Commit으로 적용
8. ITEM_TRANSFERRED 발행
9. 상태 경계가 바뀌면 ITEM_ACQUIRED 또는 ITEM_SECURED 발행

Source만 차감되고 Target 추가가 실패하는 상태는 허용하지 않는다.

### 9.4 Pickup

Pickup Entity는 item_stack과 claim 상태를 가진다.

- Interact 시 먼저 claim한다.
- Inventory 수용량을 검증한다.
- 성공하면 Inventory Commit 후 Pickup 제거
- 실패하면 claim 해제
- Pickup View가 먼저 사라지면 안 된다.

자동 줍기는 같은 Transfer 규칙을 호출한다.

### 9.5 소비

UseItemAction과 건축 비용은 공통 InventoryRules를 사용한다.

소비는 다음 중 하나다.

- 즉시 소비
- Reservation 후 진행형 소비
- 장비 Slot으로 이동

ItemDefinition에 없는 임의 소비 방식은 UI에서 만들지 않는다.

### 9.6 자원 보존 검사

개발 빌드에서 거래 전후 다음을 검사할 수 있어야 한다.

~~~text
before_total
  + explicit_created
  - explicit_destroyed
  = after_total
~~~

드롭, 제작, 보상, 소비는 explicit_created 또는 explicit_destroyed Fact를 남긴다.

---

## 10. 전투

### 10.1 공격 경로

~~~text
Input
  → AttackRequest
  → Actor 상태 검증
  → 비용 Reservation 또는 소비
  → Attack Execution
  → Hit
  → DamageRequest
  → DamageRules
  → Health 변경
  → Fact
~~~

Weapon View가 직접 Target Health를 줄이면 안 된다.

### 10.2 AttackState

Actor별 Runtime State:

- equipped_weapon_id
- phase: READY, WINDUP, ACTIVE, RECOVERY, RELOADING, DISABLED
- phase_end_tick
- aim_direction
- queued_action
- cost_reservation_id

Animation 완료 Signal은 표현 완료를 알릴 수 있지만 공격 판정의 권위 시간을 결정하지 않는다. 판정 Tick은 WeaponDefinition에 있다.

### 10.3 공격 방식

G1은 명시적 방식만 지원한다.

- MELEE_ARC
- HITSCAN
- PROJECTILE
- AREA

새 방식이 필요할 때 기존 Controller 안에 명시적 Executor를 추가한다. 범용 Effect Graph는 만들지 않는다.

### 10.4 비용

탄약, 내구도, 에너지 같은 비용은 Item 수치와 관계없이 같은 순서를 따른다.

1. 공격 시작 가능 여부 확인
2. 비용 예약
3. 공격이 취소 불가능 지점을 지나면 소비
4. 그 전에 취소되면 예약 해제
5. 소비 실패 시 공격 판정 생성 금지

### 10.5 Hit

HitResult:

- source_entity_id
- target_entity_id
- attack_definition_id
- hit_position
- hit_direction
- tags
- tick

Physics Layer는 후보를 찾을 뿐, 최종 Friendly Fire, 무적, Target 상태는 DamageRules가 검증한다.

### 10.6 Damage

DamageRules 순서:

1. Source와 Target 유효성
2. Target 수명 상태
3. 팀과 Friendly Fire 정책
4. 무적과 회피
5. 방어막
6. 방어와 저항
7. Health 적용
8. 경직과 Status 후보
9. DAMAGE_APPLIED
10. 사망 전이 판단

각 단계의 값은 Definition에서 오고, 순서는 코드 계약이다.

### 10.7 Projectile

ProjectileState:

- entity_id
- definition_id
- owner_id
- position
- direction
- remaining_lifetime
- pierce_state
- already_hit_ids

Projectile은 Physics Tick에 이동하고 Collision 후보를 DamageRequest로 바꾼다.

- 같은 Target 중복 Hit 여부는 ProjectileDefinition이 결정한다.
- Projectile View와 논리 State를 따로 복제하지 않는다. G1에서는 Projectile Node가 자신의 Runtime State를 소유하고 Save DTO를 제공한다.
- 화면 밖이라는 이유만으로 유효 Projectile을 제거하지 않는다.

### 10.8 Status

StatusInstance:

- status_definition_id
- source_id
- applied_tick
- expiry_tick
- stack_state

Status 갱신은 CombatController의 한 단계에서 처리한다. 각 Status가 독립 Timer Node를 만들지 않는다.

### 10.9 사망

사망 순서:

1. Target을 DYING으로 전이
2. Collision과 AI 중지
3. ENTITY_DEFEATED 발행
4. Objective, Threat, Loot가 Fact를 소비
5. Drop transaction 생성
6. 연출 시작
7. Registry 제거
8. queue_free

보상은 Enemy Node의 die 함수에서 직접 지급하지 않는다.

### 10.10 구조물 전투

포탑과 함정도 CombatController의 AttackRequest를 사용한다.

- Structure 기능 가능 여부는 Functional Utility 결과에서 읽는다.
- Targeting은 TargetPolicyDefinition으로 후보를 정렬한다.
- 포탑 Script가 Inventory를 직접 차감하지 않는다.
- 구조물 피해와 파괴는 일반 DamageRules와 Structure Destruction 흐름을 연결한다.

---

## 11. Enemy AI와 경로

### 11.1 단순 명시적 상태 머신

EnemyAgent는 다음 상태를 가진다.

~~~text
SPAWNING
  → SEEKING
  → MOVING
  → ATTACKING
  → RECOVERING
  → SEEKING
  → DYING
~~~

Archetype 차이는 EnemyDefinition의 감지, Target 정책, 이동, 공격 Definition으로 표현한다.

Behavior Tree는 상태 조합이 실제로 관리 불가능해지기 전까지 만들지 않는다.

### 11.2 Target 선택

Target 후보 우선순위는 명시적 TargetPolicy로 계산한다.

입력 예:

- ProtectedTarget 여부
- Player 여부
- 경로 거리
- 최근 피해 Source
- Structure Tag
- 현재 접근 가능 여부

AI가 SceneTree Group 전체를 매 Tick 검색하지 않는다. EntityRegistry가 활성 Target의 ID와 Cell을 제공한다.

### 11.3 PathService

PathService는 AStarGrid2D의 유일한 소유자다.

제공 API:

- is_cell_walkable
- has_route
- find_path
- estimate_cost
- apply_grid_changes

BuildRules, SpawnPlanner, EnemyAgent가 같은 API를 쓴다.

### 11.4 경로 캐시

EnemyAgent는 다음 경우에만 경로를 다시 요청한다.

- Target 변경
- navigation_revision 변경 후 남은 경로가 막힘
- 다음 Waypoint에 도달할 수 없음
- Recovery 정책이 재탐색을 요청

모든 Enemy가 매 Tick 전체 경로를 다시 계산하지 않는다.

### 11.5 막힘 대응

이동 중 다음 Cell이 막히면:

1. 짧은 지역 회피 시도
2. PathService 재탐색
3. 유효 경로가 없으면 공격 가능한 Blocking Structure 선택
4. 그것도 없으면 SpawnPlanner가 정한 fallback 목표로 이동
5. 계속 불가능하면 진단 Fact를 남기고 안전 제거 정책 적용

적을 아무 설명 없이 순간 이동시키지 않는다.

### 11.6 SpawnPlanner

SpawnTicket:

- ticket_id
- pressure_event_id
- enemy_pool_id
- spawn_region
- target_policy_id
- rng_state_reference
- lifecycle

SpawnPlanner 검증:

- 맵 내부
- 금지 영역 밖
- 플레이어 직접 시야 밖 또는 Telegraph된 지점
- 점유되지 않은 Cell
- Target까지 유효 경로
- 해당 Tick의 Spawn 정책 허용

생성 실패는 Ticket을 잃지 않고 다음 유효 후보를 찾거나 명시적으로 취소한다.

### 11.7 다수 Entity 성능 원칙

G1의 순서:

1. Native Physics와 AStarGrid2D 사용
2. 먼 Enemy의 의사결정 빈도를 Definition 정책으로 낮춤
3. Registry와 공간 Bucket으로 후보 검색 제한
4. 화면 밖 View 표현 단순화
5. 프로파일 후 필요한 Node만 Pool

처음부터 Custom ECS나 Custom Physics를 만들지 않는다.

---

## 12. Reward와 Progression

### 12.1 보상의 입력

SettlementService는 다음 봉인된 입력만 받는다.

~~~text
OperationOutcome
  operation_id
  definition_id
  end_reason
  completed_objectives
  secured_items
  carried_items
  discoveries
  challenge_results
  casualties
  content_revision
~~~

적 Node 수, UI 표시 값, 남은 Pickup Scene을 다시 세지 않는다.

### 12.2 Reward pipeline

~~~text
OperationOutcome
  → RewardPolicy
  → RewardProposal
  → RewardLedger Entries
  → Campaign Commit
  → Reward Choice
  → Settlement ReadModel
~~~

### 12.3 RewardProposal

RewardProposal은 적용 전 결과다.

- 보존되는 Item
- 변환되는 Item
- 영구 자원 변화
- Blueprint 해금 후보
- 선택형 보상 후보
- 실패로 소실되는 항목과 이유

Settlement UI는 Proposal을 보여줄 수 있지만 CampaignState를 직접 바꾸지 않는다.

### 12.4 RewardLedger

LedgerEntry:

- ledger_entry_id
- operation_id
- source_fact_id 또는 outcome_key
- reward_type
- definition_id
- value
- policy_revision
- state: PENDING, APPLIED, CHOSEN, REVOKED

같은 operation_id와 outcome_key로 두 번 생성할 수 없다.

Campaign 적용 절차:

1. PENDING Entry 조회
2. CampaignState 적용 가능성 검증
3. Campaign 변경
4. Entry를 APPLIED로 변경
5. Campaign과 Ledger를 같은 Save Commit에 기록

저장 재시도 후에도 APPLIED Entry는 다시 지급하지 않는다.

### 12.5 보상 선택

선택형 보상은 RewardChoiceState로 유지한다.

- choice_id
- candidate_definition_ids
- state: OPEN, SELECTED
- selected_definition_id
- source_ledger_entry_id

SelectRewardAction은 OPEN 상태와 후보 포함 여부를 검증하고 한 번만 확정한다. UI를 닫아도 선택 상태는 저장된다.

### 12.6 실패 정산

실패도 RewardPolicy를 적용한다.

Policy가 구분할 수 있는 입력:

- 종료 원인
- SECURED와 CARRIED
- 완료한 필수·선택 목표
- 발견했지만 회수하지 못한 정보
- 소비 완료 여부

실패 처리 코드를 각 종료 지점에 복사하지 않는다.

### 12.7 작전 중 보상과 영구 보상

- 작전 중 Loot 생성은 LootRules 책임이다.
- 작전 중 Item 이동은 Inventory 책임이다.
- Operation 종료 후 보존 판단은 RewardRules 책임이다.
- Campaign 반영은 SettlementService 책임이다.

이 네 단계를 하나의 Enemy 사망 Callback에 넣지 않는다.

---

## 13. Presentation과 UI

### 13.1 원칙

UI는 상태를 표시하고 Action을 요청한다. 권위 상태를 소유하지 않는다.

~~~text
Runtime State
  → Presenter
  → ReadModel
  → Widget

Widget Input
  → Controller Action
  → ActionResult
  → Presenter 갱신
~~~

### 13.2 OperationPresenter

Presenter는 다음 ReadModel을 만든다.

- PlayerStatusReadModel
- InventoryReadModel
- BuildPaletteReadModel
- ObjectiveReadModel
- ThreatReadModel
- ExtractionReadModel
- InteractionPromptReadModel

Widget은 Controller 여러 개를 직접 조합하지 않는다.

### 13.3 건축 UI

Build Palette:

- 사용 가능한 Blueprint만 표시
- Definition 설명과 현재 가용 비용 표시
- 잠금 이유 표시
- 선택 시 Preview 모드 진입

Preview HUD:

- 설치 가능 여부
- 거절 이유
- 비용과 예약 예정
- 회전과 취소 안내
- 기존 이웃의 예상 연결 변화
- 필수 경로 차단 경고

Confirm 후 ActionResult가 accepted일 때만 성공 효과를 재생한다.

### 13.4 HUD 일관성

HUD는 Signal을 받을 때마다 전체 모델을 다시 읽을 수 있다. G1에서는 복잡한 UI Delta Protocol을 만들지 않는다.

Presenter는 같은 Frame의 여러 Fact를 모아 한 번 갱신하여 깜박임을 막는다.

### 13.5 View lifecycle

EntityView는 Runtime Entity lifecycle을 따른다.

- Spawn 성공 후 Registry 등록
- Entity ID로 조회
- DYING 중 입력과 Target 표시 제거
- 연출 완료 또는 강제 종료 시 Registry 해제
- Operation 종료 시 Operation Scene과 함께 정리

Node 이름으로 Entity를 찾지 않는다.

### 13.6 VFX와 Audio

VFX와 Audio는 Fact를 소비한다.

- DAMAGE_APPLIED → Hit VFX
- ENTITY_DEFEATED → Death VFX
- CONNECTIONS_CHANGED → Build Snap 효과
- PRESSURE_EVENT_TELEGRAPHED → 경고 Audio
- OPERATION_ENDED → 종료 연출

연출이 실패해도 게임 상태 Commit은 되돌리지 않는다.

### 13.7 접근성 기본

- 설치 가능 여부를 색만으로 전달하지 않는다.
- 위협 방향은 시각과 소리를 함께 제공할 수 있어야 한다.
- 모든 건축 Action은 키보드·마우스에서 취소 경로를 가진다.
- 지속 입력과 토글 입력을 Input 설정으로 분리한다.
- 화면 흔들림과 섬광 강도는 사용자 설정에서 줄일 수 있다.

---

## 14. 저장과 복구

### 14.1 저장 종류

#### Campaign Save

영구 진행과 미확정 RewardChoice를 저장한다.

#### Operation Snapshot

진행 중 작전의 권위 상태를 저장한다.

둘은 같은 format_version 규칙을 쓰지만 별도 파일이다. Operation Snapshot 손상 때문에 Campaign Save까지 잃으면 안 된다.

### 14.2 Save Envelope

~~~text
SaveEnvelope
  format_version
  game_version
  content_hash
  save_id
  created_at
  payload_type
  payload
  checksum
~~~

payload에는 Node, Callable, Resource 객체를 직접 넣지 않는다.

### 14.3 Snapshot barrier

저장은 Tick 중간에 실행하지 않는다.

1. 현재 Tick Commit 완료
2. Action Queue 경계 고정
3. 각 Controller에서 Save DTO 수집
4. 교차 불변식 검사
5. 메모리 Snapshot 생성
6. 파일 인코딩과 기록

파일 기록 중 게임을 계속 돌릴 필요가 실제로 확인되기 전까지 G1은 짧은 동기 저장을 사용한다.

### 14.4 저장 대상

Operation Snapshot:

- Operation lifecycle과 논리 Tick
- RNG Stream 상태
- Player와 Entity Runtime State
- BuildGrid 점유와 BuildSite
- Inventory와 Reservation
- ObjectiveState
- ThreatState와 활성 SpawnTicket
- Operation Ledger
- 아직 처리되지 않은 Action ID 집합

### 14.5 저장 제외

- SceneTree 경로
- Connection Mask와 Sprite Variant
- AStarGrid2D 내부 상태와 Path
- UI, Preview, 선택 상태
- Tween, Particle
- Presenter ReadModel
- Audio 재생 위치

### 14.6 원자 파일 기록

SaveStore는 Godot FileAccess와 DirAccess만 사용한다.

1. payload 인코딩
2. 임시 파일 기록
3. flush와 close
4. 방금 기록한 파일 Decode 검증
5. 기존 정상 파일을 backup으로 이동
6. 임시 파일을 정식 파일로 교체
7. 실패 시 기존 정상 파일 유지

저장 실패는 조용히 무시하지 않고 UI에 복구 가능한 오류로 표시한다.

### 14.7 Restore 순서

1. Envelope와 Checksum 검증
2. format_version Migration
3. Content Hash 호환성 검사
4. CampaignState 또는 OperationState DTO 생성
5. ID Registry 생성
6. BuildGrid와 Inventory 복구
7. Entity 생성
8. Objective와 Threat 복구
9. Derived Connection 재계산
10. AStarGrid2D 재구성
11. Utility Graph 재구성
12. 불변식 검사
13. View와 HUD 연결
14. 입력 허용

복구 중 Fact와 보상을 다시 발행하지 않는다.

### 14.8 Schema Migration

G1의 첫 저장 형식을 version 1로 시작한다. 이후 Migration은 한 단계씩 순차 적용한다.

~~~text
v1 → v2 → v3
~~~

최신 버전으로 바로 건너뛰는 거대한 Migration 함수는 만들지 않는다.

### 14.9 손상 복구

로드 우선순위:

1. 정식 파일
2. backup 파일
3. 사용자에게 새 작전 시작 제안

Campaign Save를 자동 초기화하기 전에 사용자에게 오류와 backup 사용 여부를 알려야 한다.

---

## 15. 오류와 장애 정책

| 상황 | 처리 |
|---|---|
| 예상 가능한 Action 거절 | ActionResult reason_code, 상태 변경 없음 |
| 누락 Definition | Boot 중 실패, 플레이 시작 금지 |
| Scene 생성 실패 | Action 이전 사전 검증; Runtime에서는 안전 중단과 오류 기록 |
| Commit 불변식 실패 | 해당 Action 중단, 개발 빌드 Assert, Trace 보존 |
| View 갱신 실패 | 권위 상태 유지, View 재동기화 시도 |
| Path 계산 실패 | 설치 거절 또는 AI fallback |
| Reward 중복 적용 | Ledger idempotency로 무시 |
| Save 실패 | 기존 파일 보존, 사용자 알림, 재시도 |
| Restore 불변식 실패 | backup 시도, 작전 Snapshot 격리 |
| 알 수 없는 Action | 거절하고 상태 변경 없음 |

### 15.1 Reservation 정리

Action이 거절되거나 BuildSite가 종료될 때 Reservation을 한 곳에서 해제한다.

Operation 종료 전 검사:

- 고아 Grid Reservation 없음
- 고아 Inventory Reservation 없음
- PENDING BuildSite가 종료 정책 없이 남지 않음
- 아직 적용되지 않은 Reward Entry의 소유 Operation이 존재

### 15.2 출시 빌드의 방어

개발 Assert만 믿지 않는다.

- 잘못된 ID 입력은 거절한다.
- 배열과 Dictionary 접근 전에 존재를 확인한다.
- Save 입력은 스키마와 타입을 검증한다.
- 외부 파일 경로는 SaveStore가 고정한 사용자 데이터 경로만 사용한다.
- View 오류가 권위 상태를 파괴하지 못하게 한다.

---

## 16. 테스트 아키텍처

### 16.1 테스트 층

#### Pure rule test

Node 없이 BuildRules, InventoryRules, DamageRules, RewardRules를 검사한다.

#### Feature scenario

최소 Scene과 실제 Controller로 한 기능의 전체 흐름을 검사한다.

#### Operation scenario

Headless Operation을 Action으로 진행하고 최종 State와 Fact를 검사한다.

#### Save round-trip

진행 상태 저장 → 새 Process State로 복구 → Derived State 재생성 후 동일성 검사.

### 16.2 필수 건축 시나리오

- 빈 Cell 단일 설치
- Terrain 불일치 거절
- Footprint 일부 겹침 거절
- Preview 후 Grid 변경 시 stale 거절
- 자원 부족 시 Grid 미변경
- Grid 실패 시 Inventory 미변경
- BuildSite Cancel 후 Reservation 회수
- BuildSite 파괴 후 고아 점유 없음
- 연결 없음, 끝, 직선, 모서리, T, 교차 Variant
- 설치·철거·파괴 후 이웃 Variant 갱신
- STROKE 전체 원자성
- 문 상태와 Visual Connection 독립
- 필수 경로 차단 거절
- 저장 복구 후 같은 연결 결과

### 16.3 필수 경제·보상 시나리오

- Transfer 성공 시 총량 보존
- Target 수용 실패 시 Source 유지
- 예약 Item 이중 소비 거절
- Pickup 실패 시 World Item 유지
- SECURED와 CARRIED 분리
- 같은 Outcome 두 번 정산 시 중복 지급 없음
- RewardChoice 두 번 선택 거절
- Save 실패 후 Ledger와 Campaign 불일치 없음

### 16.4 필수 전투·AI 시나리오

- 비용 실패 시 공격 판정 없음
- 같은 사망 Fact 한 번만 발생
- Structure 파괴와 Navigation 갱신
- Spawn 지점에서 Target까지 경로 검증
- 경로 중간 변경 후 재탐색
- Enemy 제거 후 PressureEvent 종료
- View 제거 전 권위 상태 종료

### 16.5 결정성 검사

동일한 Catalog, Seed, Action Sequence를 두 번 실행하여 다음을 비교한다.

- Operation lifecycle
- Objective 결과
- BuildGrid
- Inventory
- RewardProposal
- 생성된 게임 Fact 순서

VFX와 Audio 결과는 비교 대상이 아니다.

### 16.6 Property 검사

별도 프레임워크 없이 Seed 반복으로 다음 불변식을 검사한다.

- 임의 설치·철거 순서 뒤 고아 점유 없음
- 임의 Item 거래 뒤 총량 보존
- 임의 연결 배치에서 이웃 양쪽 연결 대칭
- 임의 저장 지점에서 Restore 후 규칙 상태 동일

---

## 17. 진단과 성능

### 17.1 Action Trace

개발 빌드는 최근 Action과 Fact를 Ring Buffer에 보관한다.

Trace 항목:

- tick
- action_id
- actor_id
- action_type
- accepted
- reason_code
- changed_revisions
- emitted_fact_ids

전체 상태를 매 Tick 로그 파일로 쓰지 않는다.

### 17.2 Debug Overlay

토글 가능한 Overlay:

- Operation lifecycle
- logical_tick
- grid_revision
- navigation_revision
- topology_revision
- Dirty Cell
- Build Reservation
- Utility Component
- AStar Path
- Enemy Target
- PressureEvent
- Objective Graph

### 17.3 측정 항목

- Physics Tick 처리 시간
- Action Queue 지연
- Build Preview 계산 시간
- Dirty 연결 갱신 시간
- Path 요청 수와 Cache 무효화 수
- 활성 Entity와 Projectile
- Fact 처리량
- Save Snapshot 생성과 기록 시간

허용 값은 BenchmarkProfile과 목표 기기 측정으로 정한다. 문서에 임의의 숫자를 박지 않는다.

### 17.4 최적화 순서

1. Profiler로 병목 확인
2. 불필요한 전체 검색 제거
3. Registry 또는 공간 Bucket 사용
4. 업데이트 빈도 조절
5. Native API Batch 사용
6. 필요한 객체만 Pool
7. 그래도 부족할 때 데이터 구조 변경

Custom ECS와 멀티스레드는 마지막 선택이다.

---

## 18. 신규 구현 순서

이 순서는 기존 코드 이전 계획이 아니다. 빈 새 루트에서 기능을 세로로 완성하는 순서다.

### Slice A — Boot와 Content

- 새 AppRoot
- ContentManifest와 Catalog
- Definition 최소 집합
- ContentValidator
- Main Menu 진입

완료 조건: 잘못된 콘텐츠는 Headless 검증에서 실패하고 정상 콘텐츠만 게임을 시작한다.

### Slice B — 빈 Operation

- OperationState와 lifecycle
- Seed와 Clock
- Player 이동
- Core와 기본 맵
- Operation 종료와 정리

완료 조건: Operation을 시작하고 끝낸 뒤 Scene과 상태가 남지 않는다.

### Slice C — Inventory와 Loot

- Container
- Pickup
- Transfer
- Core Storage
- Reservation

완료 조건: World → Carried → Secured 흐름과 총량 보존이 검증된다.

### Slice D — 건축 Vertical Slice

- BuildGrid
- 단일 StructureDefinition
- Preview와 Commit
- BuildSite
- 연결형 벽
- 철거와 파괴
- AStarGrid2D 갱신

완료 조건: 설치·연결·철거·복구까지 한 시나리오가 Headless에서 통과한다.

### Slice E — 전투와 적

- AttackState
- DamageRules
- 한 EnemyAgent
- PathService
- SpawnPlanner
- 구조물 피해

완료 조건: 적이 유효 경로로 Core를 공격하고 구조물 변경에 재탐색한다.

### Slice F — Objective와 Threat

- Objective Graph
- Fact 기반 진행
- ThreatDirector
- PressureEvent
- Telegraph

완료 조건: 플레이어 행동이 압박을 만들고 목표 완료가 탈출 자격을 연다.

### Slice G — Extraction과 Settlement

- RequestExtractionAction
- OperationOutcome
- RewardPolicy
- RewardLedger
- RewardChoice
- Campaign Commit

완료 조건: 성공과 실패가 서로 다른 정산을 만들고 재시도해도 중복 지급되지 않는다.

### Slice H — Save와 Restore

- Campaign Save
- Operation Snapshot
- 원자 기록
- Restore
- Derived State 재생성

완료 조건: 건설, Inventory Reservation, Objective, Threat가 진행 중인 상태에서 저장하고 동일하게 복구한다.

### Slice I — Presentation 완성

- Presenter와 HUD
- Build Palette와 Preview 안내
- Threat Telegraph
- Settlement 화면
- 접근성 설정

완료 조건: UI가 상태를 직접 수정하지 않고 모든 변경이 ActionResult를 거친다.

### 18.1 기존 코드 처리

새 Slice는 기존 scripts, scenes, data 폴더 안에 덧대지 않는다. game 루트에서 독립적으로 만든다.

새 Vertical Slice가 같은 사용자 경험을 완성하면 대응하는 기존 진입점을 제거한다. 클래스별 Adapter, 구 저장 호환층, 양쪽 EventBus 연결은 만들지 않는다.

---

## 19. 명시적 설계 결정

| 주제 | G1 결정 | 이유 |
|---|---|---|
| 게임 흐름 | 한 맵의 연속 작전 | 탐사·건축·압박 선택을 같은 공간에서 충돌시킴 |
| 권위 | 단일 로컬 OperationController | 현재 제품 요구에 충분하고 테스트 가능 |
| 코드 구조 | Feature 단위 | 변경 이유가 같은 코드가 함께 있음 |
| 통신 | 직접 호출 + 지역 Signal + Fact | 전역 Bus와 추상화 비용 방지 |
| 입력 변경 | ActionResult 계약 | Preview 재검증과 향후 권위 분리에 필요 |
| 건축 좌표 | Vector2i 논리 Grid | 설치, 연결, 저장, 경로가 같은 좌표를 사용 |
| 바닥 연결 | Godot TileMap Terrain | 엔진 기능 재사용 |
| Entity 연결 | 명시적 Connection Mask | Health와 기능을 가진 구조물 제어 |
| 적 경로 | AStarGrid2D | BuildGrid와 동일한 통행 모델 |
| 기능망 | Port Graph | 시각 연결과 규칙 연결 분리 |
| AI | 명시적 상태 머신 | 현재 복잡도에 Behavior Tree 불필요 |
| 저장 | Snapshot + 짧은 Trace | 전체 Event Sourcing 불필요 |
| 데이터 | Resource Definition + Manifest | Godot Editor와 검증 활용 |
| 보상 | Outcome + Idempotent Ledger | 중복 지급과 UI 의존 방지 |
| 스레드 | 메인 스레드 | Node 안전성과 단순성 우선 |
| 네트워크 | 구현하지 않음 | 확정되지 않은 요구를 위한 비용 금지 |

---

## 20. 금지 규칙

- 기존 GameManager에 새 기능을 계속 붙이지 않는다.
- UI에서 Inventory, Health, Grid를 직접 수정하지 않는다.
- Enemy 사망 함수에서 보상을 직접 지급하지 않는다.
- Sprite Variant를 저장하지 않는다.
- Scene Node 이름과 경로를 영구 ID로 쓰지 않는다.
- Build Preview 결과를 재검증 없이 Commit하지 않는다.
- Visual Connection을 Functional Connection으로 간주하지 않는다.
- 건축과 자원 차감을 별도 Commit으로 처리하지 않는다.
- Build Preview와 AI가 다른 경로 모델을 쓰지 않는다.
- 작전 종료 후 Scene을 스캔해 보상을 계산하지 않는다.
- 각 Entity에 독립 Timer Node를 남발하지 않는다.
- 새 의미 없이 Interface, Factory, Service Locator를 만들지 않는다.
- 실측 없이 Pool, ECS, Worker Thread를 추가하지 않는다.
- 기존 저장 호환을 위해 새 모델을 훼손하지 않는다.

---

## 21. 최종 불변식

### 상태

- 각 권위 상태에는 한 작성자만 있다.
- Definition은 불변이고 Runtime 값의 단일 출처다.
- Derived State는 삭제 후 다시 만들 수 있다.
- Entity ID는 Node lifecycle과 분리돼 있다.

### Action

- 모든 변경은 공개 Action 또는 소유 Controller API를 통한다.
- 거절된 Action은 상태를 바꾸지 않는다.
- 복합 변경은 전부 성공하거나 전부 실패한다.
- 같은 action_id는 한 번만 Commit된다.

### 건축

- Grid 점유와 Inventory Reservation은 항상 일치한다.
- 연결 모양은 현재 Cell과 이웃에서 결정된다.
- 설치·철거·파괴는 변경 Cell과 이웃을 갱신한다.
- Preview와 Commit은 같은 규칙을 사용한다.
- 시각 연결, Collision, Navigation, Utility는 서로 다른 책임이다.

### 전투와 AI

- 공격 비용이 확정되지 않으면 Hit가 생기지 않는다.
- 사망 Fact는 Entity마다 한 번만 발생한다.
- 모든 적 Spawn은 유효한 출현 지점과 경로를 가진다.
- 구조물 통행 변경은 Navigation Revision을 바꾼다.

### 보상

- 작전 보상은 봉인된 OperationOutcome에서만 계산한다.
- RewardLedger Entry는 멱등 적용된다.
- 선택형 보상은 한 번만 확정된다.
- 실패도 명시적인 RewardPolicy를 거친다.

### 저장

- 저장은 Tick Commit 경계에서 만든다.
- 권위 State만 저장한다.
- 복구 중 보상과 Fact를 재발행하지 않는다.
- 새 파일 검증 전 기존 정상 Save를 덮지 않는다.

---

## 22. Architecture 완료 조건

다음 질문에 모두 예라고 답할 수 있을 때 G1 아키텍처가 구현된 것이다.

- 기존 진입점 없이 새 AppRoot에서 게임이 시작되는가?
- 하나의 Operation 맵에서 탐사, 운반, 확보, 건축, 전투, 탈출이 이어지는가?
- 설치 Preview와 Commit이 같은 BuildRules를 사용하는가?
- 인접 설치, 철거, 파괴 때 모든 관련 구조물 모양이 즉시 바뀌는가?
- Visual Connection과 Utility Graph를 독립적으로 검증할 수 있는가?
- Inventory 비용과 Grid 점유가 원자적으로 바뀌는가?
- 적 AI와 설치 경로 검사가 같은 AStarGrid2D 상태를 사용하는가?
- 작전 결과가 Scene과 UI를 스캔하지 않고 정산되는가?
- 저장 재시도와 복구 뒤에도 보상이 중복 지급되지 않는가?
- Save를 지우지 않고 Derived State만 전부 재생성할 수 있는가?
- 새 Structure가 Definition, Scene, Manifest 등록만으로 기존 흐름에 들어가는가?
- 새 Objective 조건이 명시적 Handler 하나로 추가되는가?
- Headless Operation Scenario가 전체 흐름을 재현하는가?
- 기존 코드의 호환층 없이 새 게임 루트가 독립 실행되는가?

---

## 23. 공식 참고 자료

- [The Riftbreaker 공식 사이트](https://www.riftbreaker.com/) — 액션, 탐사, 자원 수집, 기지 건설을 하나의 경험으로 결합하는 제품 원리
- [They Are Billions 공식 사이트](https://www.theyarebillions.com/TheyAreBillions/) — 확장, 방어선, 소음, 대규모 압박의 상호작용
- [The Last Spell 공식 사이트](https://lastspell.com/) — 희소 자원을 전투력과 거점 방어 사이에서 선택하는 긴장
- [Godot 4.2 TileMap 문서](https://docs.godotengine.org/en/4.2/classes/class_tilemap.html) — 좌표 변환과 Terrain 연결 API
- [Godot 4.2 AStarGrid2D 문서](https://docs.godotengine.org/en/4.2/classes/class_astargrid2d.html) — 건축 Grid와 공유하는 경로 모델

참고작은 문제 구조를 확인하는 자료일 뿐이다. Vivv의 연속 작전, 선택형 탈출, 가치 상태 전이, 이중 연결 건축은 이 문서가 새로 정한 설계다.
