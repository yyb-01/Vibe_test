extends Node

# res://tests/inventory_test_runner.gd
# Test runner node for Phase 2: inventory stack split, excess return, atomic unload, resource conservation, and expedition success/failure handling

const InventoryClass = preload("res://scripts/systems/inventory.gd")
const GameStateMachine = preload("res://scripts/core/game_state_machine.gd")
const MapData = preload("res://scripts/data/map_data.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _ready() -> void:
	print("========================================")
	print(" RUNNING PHASE 2 INVENTORY TEST SUITE")
	print("========================================")
	
	test_stack_splitting()
	test_excess_return()
	test_atomic_unload()
	test_resource_conservation_formula()
	test_expedition_success_and_failure_rules()
	test_weighted_resource_spawn()
	
	print("========================================")
	print(" TEST RESULTS: %d Passed, %d Failed (Total: %d)" % [passed_tests, failed_tests, total_tests])
	print("========================================")
	
	if failed_tests > 0:
		print("FAILED: Some tests did not pass.")
		get_tree().quit(1)
	else:
		print("SUCCESS: All Phase 2 tests passed successfully!")
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

func test_stack_splitting() -> void:
	print("\n--- Test: Stack Splitting across Slots ---")
	var inv = InventoryClass.new(8)
	var max_stack: int = 50
	
	var added: int = inv.add_item(&"wood", 75, max_stack)
	assert_equal(added, 75, "All 75 wood added")
	assert_equal(inv.get_slot_count(), 2, "Took exactly 2 slots")
	assert_equal(inv.get_item_count(&"wood"), 75, "Total wood count is 75")
	
	var slots = inv.get_slots()
	assert_equal(slots[0]["amount"], 50, "Slot 0 is capped at max_stack 50")
	assert_equal(slots[1]["amount"], 25, "Slot 1 holds remainder 25")
	
	var added_more: int = inv.add_item(&"wood", 30, max_stack)
	assert_equal(added_more, 30, "Added 30 more wood")
	assert_equal(inv.get_slot_count(), 3, "Now takes 3 slots")
	assert_equal(inv.get_item_count(&"wood"), 105, "Total count is 105")
	
	slots = inv.get_slots()
	assert_equal(slots[1]["amount"], 50, "Slot 1 filled to 50")
	assert_equal(slots[2]["amount"], 5, "Slot 2 holds 5")

func test_excess_return() -> void:
	print("\n--- Test: Excess Return on Full Bag ---")
	var inv = InventoryClass.new(4)
	var max_stack: int = 50
	
	inv.add_item(&"stone", 50, max_stack)
	inv.add_item(&"wood", 50, max_stack)
	inv.add_item(&"food", 30, max_stack)
	assert_equal(inv.get_slot_count(), 3, "3 slots filled")
	assert_true(not inv.is_full(), "Bag is not yet full (1 slot left)")
	
	var added_ammo: int = inv.add_item(&"ammo", 80, max_stack)
	assert_equal(added_ammo, 50, "Only 50 ammo added, 30 excess returned to world")
	assert_true(inv.is_full(), "Bag is now completely full (4 slots)")
	
	var added_scrap: int = inv.add_item(&"scrap_metal", 10, max_stack)
	assert_equal(added_scrap, 0, "Cannot add new item to full bag; 0 added")

func test_atomic_unload() -> void:
	print("\n--- Test: Atomic Unload to Storage ---")
	InventoryManager.storage.clear()
	InventoryManager.storage[&"wood"] = 20
	InventoryManager.storage[&"scrap_metal"] = 5
	
	InventoryManager.expedition_bag.clear()
	InventoryManager.add_to_bag(&"wood", 35)
	InventoryManager.add_to_bag(&"food", 10)
	
	assert_equal(InventoryManager.expedition_bag.get_item_count(&"wood"), 35, "Bag has 35 wood before unload")
	
	InventoryManager.unload_bag_to_storage()
	
	assert_equal(InventoryManager.expedition_bag.get_slot_count(), 0, "Bag is empty after unload")
	assert_equal(InventoryManager.storage.get(&"wood", 0), 55, "Storage wood updated: 20 + 35 = 55")
	assert_equal(InventoryManager.storage.get(&"scrap_metal", 0), 5, "Storage scrap_metal preserved: 5")
	assert_equal(InventoryManager.storage.get(&"food", 0), 10, "Storage food updated: 10")

func test_resource_conservation_formula() -> void:
	print("\n--- Test: Resource Conservation Equation (Section F.3) ---")
	InventoryManager.storage.clear()
	var initial_wood: int = 100
	InventoryManager.storage[&"wood"] = initial_wood
	
	var inflow_wood: int = 45
	InventoryManager.expedition_bag.clear()
	InventoryManager.add_to_bag(&"wood", inflow_wood)
	InventoryManager.unload_bag_to_storage()
	
	var consumption_wood: int = 30
	var costs: Dictionary = { &"wood": consumption_wood }
	assert_true(InventoryManager.has_materials(costs), "Sufficient materials available")
	var consumed: bool = InventoryManager.consume_materials(costs)
	assert_true(consumed, "Materials consumed successfully")
	
	var expected_final: int = initial_wood + inflow_wood - consumption_wood
	var actual_final: int = int(InventoryManager.storage.get(&"wood", 0))
	assert_equal(actual_final, expected_final, "Resource conservation holds: 100 + 45 - 30 = 115")

func test_expedition_success_and_failure_rules() -> void:
	print("\n--- Test: Expedition Success Unload vs Failure Total Bag Loss ---")
	
	# Case A: Success
	GameManager.state_machine.current_state = GameStateMachine.State.HUB
	assert_true(GameManager.request_expedition(&"forest"), "HUB -> EXPEDITION allowed")
	
	InventoryManager.storage.clear()
	InventoryManager.storage[&"wood"] = 10
	InventoryManager.expedition_bag.clear()
	InventoryManager.add_to_bag(&"wood", 25)
	
	GameManager.complete_expedition(true)
	assert_equal(GameManager.state_machine.current_state, GameStateMachine.State.EVENING_PREP, "Success leads to EVENING_PREP")
	assert_equal(InventoryManager.storage.get(&"wood", 0), 35, "Bag items transferred to storage on success")
	assert_equal(InventoryManager.expedition_bag.get_slot_count(), 0, "Bag emptied on success")
	
	# Transition back to HUB
	GameManager.state_machine.transition_to(GameStateMachine.State.NIGHT_DEFENSE)
	GameManager.state_machine.transition_to(GameStateMachine.State.DAY_SUMMARY)
	GameManager.state_machine.transition_to(GameStateMachine.State.HUB)
	
	# Case B: Failure (Timeout or Death)
	assert_true(GameManager.request_expedition(&"city"), "HUB -> EXPEDITION allowed")
	InventoryManager.storage.clear()
	InventoryManager.storage[&"scrap_metal"] = 10
	InventoryManager.expedition_bag.clear()
	InventoryManager.add_to_bag(&"scrap_metal", 40)
	
	GameManager.complete_expedition(false)
	assert_equal(GameManager.state_machine.current_state, GameStateMachine.State.DAY_SUMMARY, "Failure leads to DAY_SUMMARY")
	assert_equal(InventoryManager.storage.get(&"scrap_metal", 0), 10, "Storage scrap_metal untouched on failure")
	assert_equal(InventoryManager.expedition_bag.get_slot_count(), 0, "Bag fully lost on failure")

func test_weighted_resource_spawn() -> void:
	print("\n--- Test: Weighted Resource Selection (weights > 0 only) ---")
	var map_data = MapData.new()
	map_data.resource_spawn_weights = {
		&"wood": 0.5,
		&"stone": 0.5,
		&"unused_item": 0.0
	}
	
	var picked_counts: Dictionary = { &"wood": 0, &"stone": 0, &"unused_item": 0 }
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	
	for i in range(100):
		var pick = map_data.pick_random_resource(rng)
		picked_counts[pick] = picked_counts.get(pick, 0) + 1
		
	assert_true(picked_counts[&"wood"] > 0, "Wood was picked (count: %d)" % picked_counts[&"wood"])
	assert_true(picked_counts[&"stone"] > 0, "Stone was picked (count: %d)" % picked_counts[&"stone"])
	assert_equal(picked_counts[&"unused_item"], 0, "Weight 0 item was never picked")
