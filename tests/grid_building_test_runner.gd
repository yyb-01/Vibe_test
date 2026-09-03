extends Node

# res://tests/grid_building_test_runner.gd
# Test runner for Phase 3: footprint rotation, path blocking prevention, and placement transaction rollback

const IsometricGridBuildingSystem = preload("res://scripts/systems/isometric_grid_building_system.gd")
const StructureData = preload("res://scripts/data/structure_data.gd")
const BuildGrid = preload("res://scripts/systems/build_grid.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _ready() -> void:
	print("========================================")
	print(" RUNNING PHASE 3 GRID BUILDING TEST SUITE")
	print("========================================")
	
	test_footprint_calculation_and_rotation()
	test_route_blocking_rejection()
	test_transaction_material_deduction_and_rollback()
	test_structure_removal()
	
	print("========================================")
	print(" TEST RESULTS: %d Passed, %d Failed (Total: %d)" % [passed_tests, failed_tests, total_tests])
	print("========================================")
	
	if failed_tests > 0:
		print("FAILED: Some tests did not pass.")
		get_tree().quit(1)
	else:
		print("SUCCESS: All Phase 3 grid building tests passed successfully!")
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

func test_footprint_calculation_and_rotation() -> void:
	print("\n--- Test: 1x1, 2x1 and 2x2 Footprint Rotation ---")
	var system = IsometricGridBuildingSystem.new()
	add_child(system)
	
	# 1x1
	var fp_1x1 = system.get_footprint_cells(Vector2i(2, 3), Vector2i(1, 1), 0)
	assert_equal(fp_1x1.size(), 1, "1x1 footprint has 1 cell")
	assert_equal(fp_1x1[0], Vector2i(2, 3), "1x1 cell is (2, 3)")
	
	# 2x1 horizontal at rot 0
	var fp_2x1_rot0 = system.get_footprint_cells(Vector2i(0, 0), Vector2i(2, 1), 0)
	assert_equal(fp_2x1_rot0.size(), 2, "2x1 rot 0 has 2 cells")
	assert_equal(fp_2x1_rot0[0], Vector2i(0, 0), "Cell 0 is (0, 0)")
	assert_equal(fp_2x1_rot0[1], Vector2i(1, 0), "Cell 1 is (1, 0)")
	
	# 2x1 rotated 90 degrees (rot 1 -> 1x2 vertical)
	var fp_2x1_rot1 = system.get_footprint_cells(Vector2i(0, 0), Vector2i(2, 1), 1)
	assert_equal(fp_2x1_rot1.size(), 2, "2x1 rot 1 has 2 cells")
	assert_equal(fp_2x1_rot1[0], Vector2i(0, 0), "Rotated cell 0 is (0, 0)")
	assert_equal(fp_2x1_rot1[1], Vector2i(0, 1), "Rotated cell 1 is (0, 1)")
	
	# 2x2 (Base Core)
	var fp_2x2 = system.get_footprint_cells(Vector2i(4, 4), Vector2i(2, 2), 0)
	assert_equal(fp_2x2.size(), 4, "2x2 footprint has 4 cells")
	assert_true(Vector2i(4, 4) in fp_2x2, "(4, 4) in 2x2")
	assert_true(Vector2i(5, 4) in fp_2x2, "(5, 4) in 2x2")
	assert_true(Vector2i(4, 5) in fp_2x2, "(4, 5) in 2x2")
	assert_true(Vector2i(5, 5) in fp_2x2, "(5, 5) in 2x2")
	
	system.queue_free()

func test_route_blocking_rejection() -> void:
	print("\n--- Test: Rejection of Placements that Block Route to Core ---")
	var system = IsometricGridBuildingSystem.new()
	add_child(system)
	
	# Setup small grid: region -5..5
	# Core at (0, 0)
	# Spawn point at (3, 0)
	system.build_grid.setup(Rect2i(-5, -5, 11, 11), [Vector2i(0, 0)], [Vector2i(3, 0)])
	
	# Create a narrow wall corridor around (0, 0) such that the ONLY route from (3, 0) is via (1, 0)
	# Surround (0, 0) above and below: (0, 1), (1, 1), (0, -1), (1, -1), (-1, 0)
	var dummy_wall_node = Node2D.new()
	var blocker_cells: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(1, 1),
		Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0)
	]
	system.build_grid.register_structure(dummy_wall_node, blocker_cells, true)
	
	# Verify that route from (3, 0) to (0, 0) is currently OPEN via (1, 0)
	assert_true(system.build_grid.check_route_to_core([]), "Initial corridor route to core is open")
	
	# Barricade structure data
	var barricade_data = StructureData.new()
	barricade_data.id = &"barricade_wood"
	barricade_data.footprint = Vector2i(1, 1)
	barricade_data.blocks_navigation = true
	barricade_data.required_materials = {}
	
	# Attempt to place barricade directly in the chokepoint cell (1, 0)
	var val_result = system.validate_placement(barricade_data, Vector2i(1, 0), 0)
	assert_true(not val_result["valid"], "Chokepoint barricade placement must be rejected")
	assert_equal(val_result["reason"], &"blocks_required_route", "Reason is blocks_required_route")
	
	var placed = system.try_place(barricade_data, Vector2i(1, 0), 0)
	assert_true(not placed, "try_place returns false when route is blocked")
	assert_true(not system.build_grid.is_occupied(Vector2i(1, 0)), "Cell (1, 0) remains unoccupied")
	assert_true(system.build_grid.check_route_to_core([]), "Route to core remains functional after rollback")
	
	# Placement in non-blocking cell (2, 0) allows detour if there is space, or non-blocking area
	# Clear blockers
	system.build_grid.unregister_structure(dummy_wall_node)
	dummy_wall_node.free()
	system.queue_free()

func test_transaction_material_deduction_and_rollback() -> void:
	print("\n--- Test: Material Deduction and Placement Transaction Rollback ---")
	var system = IsometricGridBuildingSystem.new()
	add_child(system)
	system.build_grid.setup(Rect2i(-5, -5, 11, 11), [Vector2i(0, 0)], [Vector2i(4, 4)])
	
	var struct_data = StructureData.new()
	struct_data.id = &"test_turret"
	struct_data.footprint = Vector2i(1, 1)
	struct_data.required_materials = { &"wood": 10 }
	struct_data.blocks_navigation = true
	
	# Case 1: Insufficient materials
	InventoryManager.storage.clear()
	InventoryManager.storage[&"wood"] = 4 # Only 4 wood available, need 10
	
	var val = system.validate_placement(struct_data, Vector2i(2, 2), 0)
	assert_true(not val["valid"], "Validation fails when materials are insufficient")
	assert_equal(val["reason"], &"insufficient_materials", "Reason is insufficient_materials")
	
	var place_fail = system.try_place(struct_data, Vector2i(2, 2), 0)
	assert_true(not place_fail, "try_place fails")
	assert_equal(InventoryManager.storage.get(&"wood", 0), 4, "Storage wood untouched (4)")
	assert_true(not system.build_grid.is_occupied(Vector2i(2, 2)), "Cell (2, 2) not occupied")
	
	# Case 2: Sufficient materials
	InventoryManager.storage[&"wood"] = 15
	var place_ok = system.try_place(struct_data, Vector2i(2, 2), 0)
	assert_true(place_ok, "try_place succeeds with sufficient materials")
	assert_equal(InventoryManager.storage.get(&"wood", 0), 5, "Storage wood deducted: 15 - 10 = 5")
	assert_true(system.build_grid.is_occupied(Vector2i(2, 2)), "Cell (2, 2) is now occupied")
	
	# Case 3: Attempting to build on already occupied cell
	var duplicate_place = system.try_place(struct_data, Vector2i(2, 2), 0)
	assert_true(not duplicate_place, "Cannot place on already occupied cell")
	assert_equal(InventoryManager.storage.get(&"wood", 0), 5, "Materials not deducted for failed duplicate placement")
	
	system.queue_free()

func test_structure_removal() -> void:
	print("\n--- Test: Structure Removal and Occupancy Release ---")
	var system = IsometricGridBuildingSystem.new()
	add_child(system)
	system.build_grid.setup(Rect2i(-5, -5, 11, 11), [], [])
	
	var struct_data = StructureData.new()
	struct_data.id = &"wall"
	struct_data.footprint = Vector2i(1, 1)
	struct_data.required_materials = {}
	
	var placed = system.try_place(struct_data, Vector2i(1, 1), 0)
	assert_true(placed, "Structure placed")
	assert_true(system.build_grid.is_occupied(Vector2i(1, 1)), "Cell (1, 1) occupied")
	
	var placed_node = system.build_grid.occupied_cells.get(Vector2i(1, 1))
	assert_true(placed_node != null, "Placed structure node found")
	
	var removed = system.remove_structure(placed_node)
	assert_true(removed, "Structure removed successfully")
	assert_true(not system.build_grid.is_occupied(Vector2i(1, 1)), "Cell (1, 1) is now freed")
	
	system.queue_free()
