extends Node

# res://tests/navigation_test_runner.gd
# Test runner for Phase 3: NavigationRegion2D polygon baking and dynamic update verification

const ZombieClass = preload("res://entities/zombies/zombie.gd")
const StructureBaseClass = preload("res://entities/structures/structure_base.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _ready() -> void:
	print("========================================")
	print(" RUNNING PHASE 3 NAVIGATION TEST SUITE")
	print("========================================")
	
	test_navigation_polygon_baking()
	test_structure_placement_dynamic_rebake_and_zombie_repath()
	
	print("========================================")
	print(" TEST RESULTS: %d Passed, %d Failed (Total: %d)" % [passed_tests, failed_tests, total_tests])
	print("========================================")
	
	if failed_tests > 0:
		print("FAILED: Some tests did not pass.")
		get_tree().quit(1)
	else:
		print("SUCCESS: All Phase 3 navigation tests passed successfully!")
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

func test_navigation_polygon_baking() -> void:
	print("\n--- Test: NavigationRegion2D Polygon Baking ---")
	var nav_region = NavigationRegion2D.new()
	add_child(nav_region)
	
	var nav_poly = NavigationPolygon.new()
	var outline: PackedVector2Array = [
		Vector2(-500, -500),
		Vector2(500, -500),
		Vector2(500, 500),
		Vector2(-500, 500)
	]
	nav_poly.add_outline(outline)
	nav_poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = nav_poly
	
	assert_true(nav_region.navigation_polygon != null, "NavigationPolygon assigned to NavigationRegion2D")
	assert_true(nav_poly.get_polygon_count() > 0, "Initial navigation polygon contains walkable polygons")
	
	# Add a static obstacle inside the region
	var obstacle = StaticBody2D.new()
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(80, 80)
	col.shape = shape
	obstacle.add_child(col)
	obstacle.position = Vector2(0, 0)
	nav_region.add_child(obstacle)
	
	# Trigger synchronous bake (false = on current thread)
	nav_region.bake_navigation_polygon(false)
	
	var baked_poly = nav_region.navigation_polygon
	assert_true(baked_poly != null, "Baked navigation polygon exists")
	assert_true(baked_poly.get_polygon_count() > 0, "Baked navigation polygon has walkable polygons after obstacle insertion")
	
	nav_region.queue_free()

func test_structure_placement_dynamic_rebake_and_zombie_repath() -> void:
	print("\n--- Test: Dynamic Navigation Rebake and Zombie Route Recalculation ---")
	var nav_region = NavigationRegion2D.new()
	add_child(nav_region)
	
	var nav_poly = NavigationPolygon.new()
	var outline: PackedVector2Array = [
		Vector2(-600, -600),
		Vector2(600, -600),
		Vector2(600, 600),
		Vector2(-600, 600)
	]
	nav_poly.add_outline(outline)
	nav_poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = nav_poly
	nav_region.bake_navigation_polygon(false)
	
	# Create Core target
	var core = Node2D.new()
	core.name = "BaseCore"
	core.position = Vector2(0, 0)
	add_child(core)
	
	# Create Zombie at (0, 300)
	var zombie_scene = load("res://entities/zombies/zombie.tscn")
	var zombie = zombie_scene.instantiate() as ZombieClass
	zombie.position = Vector2(0, 300)
	add_child(zombie)
	
	# Initial route evaluation: Core is target
	zombie._evaluate_target_and_route()
	assert_equal(zombie.current_target, core, "Zombie initial target is BaseCore")
	
	# Place Barricade structure blocking the path at (0, 150)
	var barricade_scene = load("res://entities/structures/barricade.tscn")
	var barricade = barricade_scene.instantiate() as StructureBaseClass
	barricade.position = Vector2(0, 150)
	nav_region.add_child(barricade)
	
	# Trigger dynamic rebake of navigation polygon
	nav_region.bake_navigation_polygon(false)
	var new_poly = nav_region.navigation_polygon
	assert_true(new_poly != null, "NavigationPolygon rebaked dynamically after structure placement")
	assert_true(new_poly.get_polygon_count() > 0, "Updated navigation polygon contains walkable polygons")
	
	# Zombie recalculates route with structure in place
	zombie._evaluate_target_and_route()
	assert_true(zombie.current_target != null, "Zombie evaluated target and recalculated route after structure placement")
	
	# Cleanup
	zombie.queue_free()
	barricade.queue_free()
	core.queue_free()
	nav_region.queue_free()
