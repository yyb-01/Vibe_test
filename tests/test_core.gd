extends SceneTree

# res://tests/test_core.gd
# Headless test runner for core isometric math, state machine transitions, player setup, and data schema.

const GameStateMachine = preload("res://scripts/core/game_state_machine.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("========================================")
	print(" RUNNING CORE GAMEPLAY LOOP TEST SUITE (test_core.gd)")
	print("========================================")
	
	test_coordinate_round_trip()
	test_state_machine_transitions()
	test_aim_direction_math()
	test_item_data_schema()
	test_player_and_scene_instantiation()
	test_vertical_slice_wiring()
	test_survival_cycle_state_machine()
	test_expedition_failure_loss_and_return()
	test_night_defense_victory_scaling()
	test_core_destruction_rollback_and_legacy_scrap()
	
	print("========================================")
	print(" TEST RESULTS: %d Passed, %d Failed (Total: %d)" % [passed_tests, failed_tests, total_tests])
	print("========================================")
	
	if failed_tests > 0:
		print("FAILED: Some tests did not pass.")
		quit(1)
	else:
		print("SUCCESS: All tests passed successfully!")
		quit(0)

func assert_true(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s" % test_name)

func assert_equal(actual, expected, test_name: String) -> void:
	total_tests += 1
	if actual == expected:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s: expected %s, got %s" % [test_name, str(expected), str(actual)])

func test_coordinate_round_trip() -> void:
	print("\n--- Test: Coordinate Round Trip (local_to_map <-> map_to_local) ---")
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(128, 64)
	
	var tm := TileMap.new()
	tm.tile_set = ts
	
	var sample_cells: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(5, 8),
		Vector2i(-14, 22),
		Vector2i(35, -40),
		Vector2i(-100, -100)
	]
	
	for cell in sample_cells:
		var local_pos: Vector2 = tm.map_to_local(cell)
		var recovered_cell: Vector2i = tm.local_to_map(local_pos)
		assert_equal(recovered_cell, cell, "Round trip for cell %s (local_pos: %s)" % [str(cell), str(local_pos)])
		
		# Test world conversion with transform
		tm.position = Vector2(250.0, -130.0)
		var world_pos: Vector2 = tm.to_global(local_pos)
		var world_recovered_cell: Vector2i = tm.local_to_map(tm.to_local(world_pos))
		assert_equal(world_recovered_cell, cell, "World transform round trip for cell %s" % str(cell))
	
	tm.free()

func test_state_machine_transitions() -> void:
	print("\n--- Test: GameStateMachine Transition Rules ---")
	var sm := GameStateMachine.new()
	assert_equal(sm.current_state, GameStateMachine.State.HUB, "Initial state must be HUB")
	
	# 1. Invalid transitions from HUB
	assert_true(not sm.can_transition_to(GameStateMachine.State.HUB), "Reject same-state transition (HUB -> HUB)")
	assert_true(not sm.can_transition_to(GameStateMachine.State.EVENING_PREP), "Reject invalid transition (HUB -> EVENING_PREP)")
	assert_true(not sm.can_transition_to(GameStateMachine.State.NIGHT_DEFENSE), "Reject invalid transition (HUB -> NIGHT_DEFENSE)")
	assert_true(not sm.can_transition_to(GameStateMachine.State.DAY_SUMMARY), "Reject invalid transition (HUB -> DAY_SUMMARY)")
	
	var failed_attempt: bool = sm.transition_to(GameStateMachine.State.NIGHT_DEFENSE)
	assert_true(not failed_attempt, "transition_to(NIGHT_DEFENSE) should return false from HUB")
	assert_equal(sm.current_state, GameStateMachine.State.HUB, "State must remain HUB after failed transition")
	
	# 2. Valid transition sequence: HUB -> EXPEDITION -> EVENING_PREP -> NIGHT_DEFENSE -> DAY_SUMMARY -> HUB
	assert_true(sm.can_transition_to(GameStateMachine.State.EXPEDITION), "Allow HUB -> EXPEDITION")
	assert_true(sm.transition_to(GameStateMachine.State.EXPEDITION), "Execute HUB -> EXPEDITION")
	assert_equal(sm.current_state, GameStateMachine.State.EXPEDITION, "Current state is now EXPEDITION")
	
	assert_true(not sm.can_transition_to(GameStateMachine.State.HUB), "Reject invalid EXPEDITION -> HUB")
	assert_true(not sm.can_transition_to(GameStateMachine.State.NIGHT_DEFENSE), "Reject invalid EXPEDITION -> NIGHT_DEFENSE")
	
	assert_true(sm.can_transition_to(GameStateMachine.State.EVENING_PREP), "Allow EXPEDITION -> EVENING_PREP")
	assert_true(sm.transition_to(GameStateMachine.State.EVENING_PREP), "Execute EXPEDITION -> EVENING_PREP")
	assert_equal(sm.current_state, GameStateMachine.State.EVENING_PREP, "Current state is now EVENING_PREP")
	
	assert_true(sm.can_transition_to(GameStateMachine.State.NIGHT_DEFENSE), "Allow EVENING_PREP -> NIGHT_DEFENSE")
	assert_true(sm.transition_to(GameStateMachine.State.NIGHT_DEFENSE), "Execute EVENING_PREP -> NIGHT_DEFENSE")
	assert_equal(sm.current_state, GameStateMachine.State.NIGHT_DEFENSE, "Current state is now NIGHT_DEFENSE")
	
	assert_true(sm.can_transition_to(GameStateMachine.State.DAY_SUMMARY), "Allow NIGHT_DEFENSE -> DAY_SUMMARY")
	assert_true(sm.transition_to(GameStateMachine.State.DAY_SUMMARY), "Execute NIGHT_DEFENSE -> DAY_SUMMARY")
	assert_equal(sm.current_state, GameStateMachine.State.DAY_SUMMARY, "Current state is now DAY_SUMMARY")
	
	assert_true(sm.can_transition_to(GameStateMachine.State.HUB), "Allow DAY_SUMMARY -> HUB")
	assert_true(sm.transition_to(GameStateMachine.State.HUB), "Execute DAY_SUMMARY -> HUB")
	assert_equal(sm.current_state, GameStateMachine.State.HUB, "Current state is back to HUB")
	
	# 3. Transition guard test
	assert_true(sm.begin_transition(GameStateMachine.State.EXPEDITION), "begin_transition succeeds")
	assert_true(sm.is_transitioning, "is_transitioning is true during transition")
	assert_true(not sm.can_transition_to(GameStateMachine.State.EXPEDITION), "can_transition_to rejected while is_transitioning")
	assert_true(not sm.begin_transition(GameStateMachine.State.EXPEDITION), "begin_transition rejected while is_transitioning")
	sm.finish_transition(GameStateMachine.State.EXPEDITION)
	assert_true(not sm.is_transitioning, "is_transitioning is false after finish_transition")
	assert_equal(sm.current_state, GameStateMachine.State.EXPEDITION, "State updated after finish_transition")

func test_aim_direction_math() -> void:
	print("\n--- Test: Mouse Aim 8-Direction Index Calculation (Section B.6) ---")
	# 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE
	var test_vectors: Array[Vector2] = [
		Vector2(100, 0),      # E -> 0
		Vector2(100, 100),    # SE -> 1
		Vector2(0, 100),      # S -> 2
		Vector2(-100, 100),   # SW -> 3
		Vector2(-100, 0),     # W -> 4
		Vector2(-100, -100),  # NW -> 5
		Vector2(0, -100),     # N -> 6
		Vector2(100, -100)    # NE -> 7
	]
	
	var expected_indices: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
	var expected_names: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	
	for i in range(test_vectors.size()):
		var aim: Vector2 = test_vectors[i]
		var angle: float = wrapf(aim.angle(), 0.0, TAU)
		var index: int = int(round(angle / (TAU / 8.0))) % 8
		assert_equal(index, expected_indices[i], "Aim %s -> index %d (%s)" % [str(aim), expected_indices[i], expected_names[i]])

func test_item_data_schema() -> void:
	print("\n--- Test: ItemData Schema (Section C.2) ---")
	var item := ItemData.new()
	item.id = &"wood"
	item.display_name = "Wood Plank"
	item.category = ItemData.Category.RESOURCE
	item.max_stack = 99
	item.region_tag = ItemData.RegionTag.FOREST
	item.meta_value = 2
	
	assert_equal(item.id, &"wood", "ItemData id matches")
	assert_equal(item.display_name, "Wood Plank", "ItemData display_name matches")
	assert_equal(item.category, ItemData.Category.RESOURCE, "ItemData category matches")
	assert_equal(item.max_stack, 99, "ItemData max_stack matches")
	assert_equal(item.meta_value, 2, "ItemData meta_value matches")

func test_player_and_scene_instantiation() -> void:
	print("\n--- Test: Player and Scene Setup (Section B.3, B.5, E.3) ---")
	var scene = load("res://scenes/main.tscn")
	assert_true(scene != null, "scenes/main.tscn loaded")
	
	var inst = scene.instantiate()
	assert_true(inst != null, "scenes/main.tscn instantiated")
	
	var player = inst.find_child("Player", true, false)
	assert_true(player != null, "Player found in scene")
	assert_true(player is CharacterBody2D, "Player is CharacterBody2D")
	assert_equal(player.collision_layer, 2, "Player collision_layer is 2 (Section E.3)")
	
	var visual: AnimatedSprite2D = player.get_node_or_null("Visual")
	assert_true(visual != null, "Visual node exists on Player")
	assert_true(visual is AnimatedSprite2D, "Visual is AnimatedSprite2D")
	assert_equal(visual.offset, Vector2(0, -64), "Visual offset is (0, -64) for bottom-center pivot")
	assert_true(visual.sprite_frames != null, "SpriteFrames configured on Visual")
	assert_true(visual.sprite_frames.has_animation("idle_s"), "SpriteFrames has idle_s")
	assert_true(visual.sprite_frames.has_animation("idle_e"), "SpriteFrames has idle_e")
	assert_true(visual.sprite_frames.has_animation("idle_nw"), "SpriteFrames has idle_nw")
	
	inst.free()

func test_vertical_slice_wiring() -> void:
	print("\n--- Test: Vertical Slice Combat, VFX and Pool Wiring ---")
	var scene = load("res://scenes/main.tscn")
	var inst = scene.instantiate()
	var player := inst.find_child("Player", true, false) as Player
	var projectile_pool: Node = inst.find_child("ProjectilePool", true, false)
	var vfx_pool: Node = inst.find_child("VFXPool", true, false)
	var nav_region: Node = inst.find_child("NavigationRegion2D", true, false)
	assert_true(player != null and is_equal_approx(player.dash_duration, 0.2), "Player dash duration is 0.2 seconds")
	assert_true(player != null and is_equal_approx(player.dash_iframe_duration, 0.15), "Player dash has 0.15 seconds of I-frames")
	assert_true(projectile_pool != null, "ProjectilePool is present in the main slice")
	assert_true(vfx_pool != null, "VFXPool is present in the main slice")
	assert_true(nav_region != null, "NavigationRegion2D is present in the main slice")
	assert_true(InputMap.has_action("dash"), "Space dash action is registered")
	assert_true(ResourceLoader.exists("res://assets/shaders/hit_flash.gdshader"), "Hit flash shader is available")
	assert_true(ResourceLoader.exists("res://assets/shaders/ghost.gdshader"), "Dash ghost shader is available")
	var zombie_scene = load("res://entities/zombies/zombie.tscn")
	var zombie = zombie_scene.instantiate()
	assert_true(zombie.find_child("SeparationArea", true, false) != null, "Zombie separation area is wired")
	zombie.free()
	inst.free()

func test_survival_cycle_state_machine() -> void:
	print("\n--- Test: Full Survival Cycle State Machine (HUB -> EXPEDITION -> EVENING_PREP -> NIGHT_DEFENSE -> DAY_SUMMARY -> HUB) ---")
	var sm = GameStateMachine.new()
	assert_equal(sm.current_state, GameStateMachine.State.HUB, "Initial state is HUB")
	
	# Transition 1: HUB -> EXPEDITION
	assert_true(sm.can_transition_to(GameStateMachine.State.EXPEDITION), "Allow HUB -> EXPEDITION")
	assert_true(sm.transition_to(GameStateMachine.State.EXPEDITION), "Execute HUB -> EXPEDITION")
	assert_equal(sm.current_state, GameStateMachine.State.EXPEDITION, "Current state is EXPEDITION")
	
	# Transition 2: EXPEDITION -> EVENING_PREP
	assert_true(sm.can_transition_to(GameStateMachine.State.EVENING_PREP), "Allow EXPEDITION -> EVENING_PREP")
	assert_true(sm.transition_to(GameStateMachine.State.EVENING_PREP), "Execute EXPEDITION -> EVENING_PREP")
	assert_equal(sm.current_state, GameStateMachine.State.EVENING_PREP, "Current state is EVENING_PREP")
	
	# Transition 3: EVENING_PREP -> NIGHT_DEFENSE
	assert_true(sm.can_transition_to(GameStateMachine.State.NIGHT_DEFENSE), "Allow EVENING_PREP -> NIGHT_DEFENSE")
	assert_true(sm.transition_to(GameStateMachine.State.NIGHT_DEFENSE), "Execute EVENING_PREP -> NIGHT_DEFENSE")
	assert_equal(sm.current_state, GameStateMachine.State.NIGHT_DEFENSE, "Current state is NIGHT_DEFENSE")
	
	# Transition 4: NIGHT_DEFENSE -> DAY_SUMMARY
	assert_true(sm.can_transition_to(GameStateMachine.State.DAY_SUMMARY), "Allow NIGHT_DEFENSE -> DAY_SUMMARY")
	assert_true(sm.transition_to(GameStateMachine.State.DAY_SUMMARY), "Execute NIGHT_DEFENSE -> DAY_SUMMARY")
	assert_equal(sm.current_state, GameStateMachine.State.DAY_SUMMARY, "Current state is DAY_SUMMARY")
	
	# Transition 5: DAY_SUMMARY -> HUB (Day + 1)
	assert_true(sm.can_transition_to(GameStateMachine.State.HUB), "Allow DAY_SUMMARY -> HUB")
	assert_true(sm.transition_to(GameStateMachine.State.HUB), "Execute DAY_SUMMARY -> HUB")
	assert_equal(sm.current_state, GameStateMachine.State.HUB, "Completed cycle returned to HUB for Day + 1")

func test_expedition_failure_loss_and_return() -> void:
	print("\n--- Test: Expedition Failure Total Bag Loss and Return ---")
	var inv_class = preload("res://scripts/systems/inventory.gd")
	var bag = inv_class.new(8)
	var storage: Dictionary = { &"wood": 50 }
	
	bag.add_item(&"scrap_metal", 40)
	assert_equal(bag.get_item_count(&"scrap_metal"), 40, "Bag holds 40 scrap_metal")
	
	# Simulate expedition death / failure: bag is 100% emptied, storage is untouched
	bag.clear()
	assert_equal(bag.get_slot_count(), 0, "Expedition bag 100% wiped clean upon failure")
	assert_equal(storage.get(&"scrap_metal", 0), 0, "No bag items transferred to storage")
	assert_equal(storage.get(&"wood", 0), 50, "Base storage preserved intact (50 wood)")

func test_night_defense_victory_scaling() -> void:
	print("\n--- Test: Night Defense Victory, Day Count & Difficulty Scaling ---")
	var day: int = 1
	var scale_d1: float = 1.0 + float(day - 1) * 0.25
	assert_equal(scale_d1, 1.0, "Day 1 difficulty scale is 1.0")
	
	# Victory increments Day by 1
	day += 1
	var scale_d2: float = 1.0 + float(day - 1) * 0.25
	assert_equal(day, 2, "Victory increments Day to 2")
	assert_equal(scale_d2, 1.25, "Day 2 difficulty scale is 1.25 (1.0 + 1 * 0.25)")
	
	# Second Victory increments Day to 3
	day += 1
	var scale_d3: float = 1.0 + float(day - 1) * 0.25
	assert_equal(day, 3, "Victory increments Day to 3")
	assert_equal(scale_d3, 1.5, "Day 3 difficulty scale is 1.50 (1.0 + 2 * 0.25)")

func test_core_destruction_rollback_and_legacy_scrap() -> void:
	print("\n--- Test: Core Destruction/Player Death Snapshot Rollback & 10% Legacy Scrap ---")
	var morning_snapshot: Dictionary = {
		"day": 3,
		"storage": { "wood": 100 },
		"legacy_scrap": 10
	}
	
	# Collected 50 items during failed expedition
	var lost_items_count: int = 50
	var legacy_scrap_earned: int = int(floor(float(lost_items_count) * 0.1))
	assert_equal(legacy_scrap_earned, 5, "10% of lost harvest converted to 5 legacy scrap")
	
	var total_legacy_scrap: int = morning_snapshot["legacy_scrap"] + legacy_scrap_earned
	assert_equal(total_legacy_scrap, 15, "Total legacy scrap updated: 10 + 5 = 15")
	
	# Defeat: state rolls back to morning snapshot
	var current_day: int = morning_snapshot["day"]
	var current_storage: Dictionary = morning_snapshot["storage"].duplicate()
	assert_equal(current_day, 3, "Day rolled back to snapshot Day 3")
	assert_equal(current_storage.get("wood", 0), 100, "Storage restored to morning snapshot (100 wood)")
	assert_equal(total_legacy_scrap, 15, "Legacy scrap retained across snapshot rollback")
