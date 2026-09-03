extends Node

# res://tests/full_loop_test_runner.gd
# Full 3-Day gameplay loop simulation, save/load round-trip, defeat rollback, and performance budget verification

const GameStateMachine = preload("res://scripts/core/game_state_machine.gd")
const IsometricGridBuildingSystemClass = preload("res://scripts/systems/isometric_grid_building_system.gd")
const StructureDataClass = preload("res://scripts/data/structure_data.gd")
const ZombieClass = preload("res://entities/zombies/zombie.gd")
const ProjectileClass = preload("res://entities/combat/projectile.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _ready() -> void:
	print("========================================")
	print(" RUNNING PHASE 5 FULL LOOP TEST SUITE")
	print("========================================")
	
	test_three_day_full_loop()
	test_save_load_round_trip()
	test_forced_defeat_and_snapshot_rollback()
	test_performance_budget()
	
	print("========================================")
	print(" TEST RESULTS: %d Passed, %d Failed (Total: %d)" % [passed_tests, failed_tests, total_tests])
	print("========================================")
	
	if failed_tests > 0:
		print("FAILED: Some full-loop tests did not pass.")
		get_tree().quit(1)
	else:
		print("SUCCESS: All Phase 5 full-loop tests passed successfully!")
		get_tree().quit(0)

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

func test_three_day_full_loop() -> void:
	print("\n--- Test: 3-Day Continuous Loop Simulation ---")
	
	var building_system = IsometricGridBuildingSystemClass.new()
	add_child(building_system)
	GameManager.active_building_system = building_system
	
	# Reset game manager
	GameManager.day = 1
	GameManager.state_machine.current_state = GameStateMachine.State.HUB
	InventoryManager.storage.clear()
	InventoryManager.clear_bag()
	GameManager.create_day_start_snapshot()
	
	assert_equal(GameManager.current_state, GameStateMachine.State.HUB, "Initial state is HUB")
	assert_equal(GameManager.day, 1, "Day is 1")
	
	# Day 1: HUB -> EXPEDITION
	var exp_req = GameManager.request_expedition(&"forest")
	assert_true(exp_req, "Expedition request succeeded")
	assert_equal(GameManager.current_state, GameStateMachine.State.EXPEDITION, "State is EXPEDITION")
	
	# Farm items in expedition bag
	InventoryManager.add_to_bag(&"wood", 30)
	assert_equal(InventoryManager.get_bag_count(&"wood"), 30, "Bag has 30 wood")
	
	# Extract successfully: EXPEDITION -> EVENING_PREP
	GameManager.complete_expedition(true)
	assert_equal(GameManager.current_state, GameStateMachine.State.EVENING_PREP, "State is EVENING_PREP")
	assert_equal(InventoryManager.storage.get(&"wood", 0), 30, "Wood unloaded to storage: 30")
	assert_equal(InventoryManager.get_bag_count(&"wood"), 0, "Bag emptied")
	
	# Build barricade at (1, 1) during EVENING_PREP
	var barricade_res = load("res://data/structures/barricade_wood.tres")
	var placed = building_system.try_place(barricade_res, Vector2i(1, 1), 0)
	assert_true(placed, "Barricade placed at (1, 1)")
	assert_equal(InventoryManager.storage.get(&"wood", 0), 25, "5 wood consumed for barricade (30 - 5 = 25)")
	
	# EVENING_PREP -> NIGHT_DEFENSE
	var night_start = GameManager.start_night()
	assert_true(night_start, "Night defense started")
	assert_equal(GameManager.current_state, GameStateMachine.State.NIGHT_DEFENSE, "State is NIGHT_DEFENSE")
	
	# Defend successfully: NIGHT_DEFENSE -> DAY_SUMMARY
	GameManager.complete_night(true)
	assert_equal(GameManager.current_state, GameStateMachine.State.DAY_SUMMARY, "State is DAY_SUMMARY")
	assert_true(GameManager.day_result["survived"], "Day 1 survived")
	
	# Confirm summary: DAY_SUMMARY -> HUB (Day 2)
	GameManager.confirm_summary()
	assert_equal(GameManager.current_state, GameStateMachine.State.HUB, "Back to HUB")
	assert_equal(GameManager.day, 2, "Day incremented to 2")
	assert_equal(InventoryManager.storage.get(&"wood", 0), 25, "Storage preserved in Day 2")
	assert_true(building_system.build_grid.is_occupied(Vector2i(1, 1)), "Structure at (1, 1) preserved in Day 2")
	
	# Day 2 -> Day 3 progression
	GameManager.request_expedition(&"city")
	GameManager.complete_expedition(true)
	GameManager.start_night()
	GameManager.complete_night(true)
	GameManager.confirm_summary()
	
	assert_equal(GameManager.day, 3, "Advanced to Day 3")
	var diff_scale = GameManager.get_difficulty_scale()
	assert_equal(diff_scale, 1.5, "Difficulty scale at Day 3 is 1.5 (1.0 + 2 * 0.25)")
	
	building_system.queue_free()

func test_save_load_round_trip() -> void:
	print("\n--- Test: Atomic Save/Load Round-Trip and Structure Placement Integrity ---")
	var building_system = IsometricGridBuildingSystemClass.new()
	add_child(building_system)
	GameManager.active_building_system = building_system
	
	# Setup test state and free placement
	GameManager.day = 4
	GameManager.legacy_scrap = 22
	
	var barricade_res = load("res://data/structures/barricade_wood.tres")
	building_system.try_place(barricade_res, Vector2i(3, -2), 0, true)
	
	var turret_res = load("res://data/structures/turret_basic.tres")
	building_system.try_place(turret_res, Vector2i(-1, 2), 0, true)
	
	# Set damaged HP on barricade to verify HP restoration without drift
	var placed_barricade = building_system.build_grid.occupied_cells.get(Vector2i(3, -2))
	if placed_barricade != null:
		placed_barricade.current_health = 45.0
		
	InventoryManager.storage = { &"wood": 80, &"scrap_metal": 40 }
	
	# Save game
	var save_success = GameManager.save_current_game()
	assert_true(save_success, "Game saved successfully")
	assert_true(SaveManager.has_save_file(), "Save file exists on disk")
	
	# Mutate current state
	GameManager.day = 1
	GameManager.legacy_scrap = 0
	InventoryManager.storage.clear()
	building_system.build_grid.clear()
	
	# Load game
	var load_success = GameManager.load_saved_game()
	assert_true(load_success, "Game loaded successfully")
	assert_equal(GameManager.day, 4, "Loaded Day is 4")
	assert_equal(GameManager.legacy_scrap, 22, "Loaded legacy scrap is 22")
	assert_equal(InventoryManager.storage.get(&"wood", 0), 80, "Loaded wood is 80")
	assert_equal(InventoryManager.storage.get(&"scrap_metal", 0), 40, "Loaded scrap_metal is 40")
	
	# Verify structure positions and remaining health restored exactly without drift
	assert_true(building_system.build_grid.is_occupied(Vector2i(3, -2)), "Barricade restored at exact cell (3, -2)")
	var restored_barricade = building_system.build_grid.occupied_cells.get(Vector2i(3, -2))
	assert_equal(restored_barricade.current_health, 45.0, "Barricade remaining health restored without drift (45.0 HP)")
	assert_true(building_system.build_grid.is_occupied(Vector2i(-1, 2)), "Turret restored at exact cell (-1, 2)")
	
	# Test: Deliberately inject corrupted JSON into save file
	SaveManager.delete_save()
	var corrupt_file = FileAccess.open("user://save.json", FileAccess.WRITE)
	corrupt_file.store_string("{ corrupt_json: [invalid_syntax without closing brackets")
	corrupt_file.close()
	
	var corrupt_result = SaveManager.load_game()
	assert_true(corrupt_result.is_empty(), "Malformed JSON injection rejected, returns empty dictionary prompting new game")
	assert_true(FileAccess.file_exists("user://save.json.corrupted"), "Original corrupted save file preserved on disk without overwriting")
	
	# Clean up save
	SaveManager.delete_save()
	if FileAccess.file_exists("user://save.json.corrupted"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json.corrupted"))
	building_system.queue_free()

func test_forced_defeat_and_snapshot_rollback() -> void:
	print("\n--- Test: Forced Defeat, Snapshot Rollback & Legacy Scrap Conversion ---")
	
	# Day 1 start
	GameManager.day = 1
	GameManager.legacy_scrap = 5
	GameManager.state_machine.current_state = GameStateMachine.State.HUB
	InventoryManager.storage = { &"wood": 50 }
	InventoryManager.clear_bag()
	GameManager.create_day_start_snapshot()
	
	# Enter expedition
	GameManager.request_expedition(&"forest")
	
	# Pick up 40 items in bag
	InventoryManager.add_to_bag(&"wood", 40)
	assert_equal(InventoryManager.get_bag_count(&"wood"), 40, "Collected 40 wood in bag")
	
	# Suffer defeat (player death or timeout)
	GameManager.complete_expedition(false)
	assert_equal(GameManager.current_state, GameStateMachine.State.DAY_SUMMARY, "State moved to DAY_SUMMARY on failure")
	assert_true(not GameManager.day_result["survived"], "Result marked as not survived")
	
	# 10% value: 40 * 0.1 = 4 scrap
	assert_equal(GameManager.day_result["legacy_scrap_earned"], 4, "4 legacy scrap awarded for 40 lost items")
	assert_equal(GameManager.legacy_scrap, 9, "Total legacy scrap updated: 5 + 4 = 9")
	assert_equal(InventoryManager.get_bag_count(&"wood"), 0, "Bag wiped clean on death")
	
	# Confirm summary and return to HUB
	GameManager.confirm_summary()
	assert_equal(GameManager.current_state, GameStateMachine.State.HUB, "Returned to HUB")
	assert_equal(GameManager.day, 1, "Day rolled back to day 1")
	assert_equal(InventoryManager.storage.get(&"wood", 0), 50, "Storage restored to morning snapshot (50 wood)")
	assert_equal(GameManager.legacy_scrap, 9, "Legacy scrap retained across snapshot rollback")

func test_performance_budget() -> void:
	print("\n--- Test: Performance Budget (100 Zombies & 200 Projectiles) ---")
	var root_bench = Node2D.new()
	add_child(root_bench)
	
	var zombie_scene = load("res://entities/zombies/zombie.tscn")
	var proj_scene = load("res://entities/combat/projectile.tscn")
	
	var dummy_target = Node2D.new()
	dummy_target.position = Vector2(0, 0)
	root_bench.add_child(dummy_target)
	
	var zombies: Array = []
	for i in range(100):
		var z = zombie_scene.instantiate()
		z.position = Vector2(randf_range(-400, 400), randf_range(-300, 300))
		z.current_target = dummy_target
		z.current_state = ZombieClass.State.MOVE
		root_bench.add_child(z)
		zombies.append(z)
		
	var projs: Array = []
	for i in range(200):
		var p = proj_scene.instantiate()
		p.position = Vector2(randf_range(-400, 400), randf_range(-300, 300))
		p.velocity = Vector2(300, 300)
		root_bench.add_child(p)
		projs.append(p)
		
	assert_equal(zombies.size(), 100, "100 zombies spawned for stress test")
	assert_equal(projs.size(), 200, "200 projectiles spawned for stress test")
	
	# Measure 10 physics ticks
	var start_usec: int = Time.get_ticks_usec()
	for tick in range(10):
		for z in zombies:
			if z != null and is_instance_valid(z):
				z._physics_process(0.016)
		for p in projs:
			if p != null and is_instance_valid(p):
				p._physics_process(0.016)
				
	var elapsed_usec: int = Time.get_ticks_usec() - start_usec
	var avg_ms_per_tick: float = (float(elapsed_usec) / 10.0) / 1000.0
	print("  [BENCHMARK] Average processing time per tick: %.3f ms (Budget: 25.0 ms)" % avg_ms_per_tick)
	
	assert_true(avg_ms_per_tick < 25.0, "100 zombies + 200 projectiles execute without bottleneck (< 25.0 ms)")
	
	root_bench.queue_free()
