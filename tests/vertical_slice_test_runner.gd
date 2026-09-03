extends Node

const GameStateMachineClass = preload("res://scripts/core/game_state_machine.gd")

var total_tests: int = 0
var failed_tests: int = 0

func _ready() -> void:
	var main := load("res://scenes/main.tscn").instantiate() as Main
	add_child(main)
	await get_tree().process_frame
	assert_true(main.building_manager.ground_layer != null, "Main wires the isometric ground layer")
	assert_true(not main.building_manager.build_grid.core_cells.is_empty(), "Main reserves HQ cells in BuildGrid")
	assert_true(main.building_manager.navigation_region != null, "Main wires dynamic navigation")
	assert_true(main.building_manager.build_grid.region.has_point(Vector2i.ZERO), "Main grid contains the HQ anchor cell")
	var projectile_pool := main.find_child("ProjectilePool", true, false) as ProjectilePool
	var vfx_pool := main.find_child("VFXPool", true, false) as VFXPool
	var first := projectile_pool.spawn(Vector2.ZERO, Vector2.RIGHT, 1.0, 100.0, null)
	projectile_pool.release(first)
	var second := projectile_pool.spawn(Vector2.ZERO, Vector2.RIGHT, 1.0, 100.0, null)
	assert_true(first == second, "ProjectilePool reuses a released projectile")
	projectile_pool.release(second)
	vfx_pool.spawn_impact(Vector2.ZERO, Vector2.RIGHT)
	vfx_pool.spawn_melee_arc(Vector2.ZERO, Vector2.RIGHT, 86.0, PI * 0.5, Color(1.0, 0.8, 0.3, 0.5))
	vfx_pool.play_feedback(false)
	await get_tree().process_frame
	assert_true(InputMap.has_action("melee"), "Right-click melee action is registered")
	GameManager.state_machine.current_state = GameStateMachineClass.State.NIGHT_DEFENSE
	main.player._update_control_state()
	assert_true(main.player.try_dash(), "Player starts a dash from the defense state")
	assert_equal(main.player.collision_mask, 9, "Dash keeps World and Structure collision while removing Enemy collision")
	main.player._end_dash()
	assert_equal(main.player.collision_mask, 13, "Dash restores the normal collision mask")
	var zombie := load("res://entities/zombies/zombie.tscn").instantiate() as Zombie
	zombie.position = Vector2(60.0, 0.0)
	main.actors_container.add_child(zombie)
	zombie.set_physics_process(false)
	await get_tree().physics_frame
	main.player.aim_direction = Vector2.RIGHT
	assert_equal(main.player.melee(), 1, "Melee cone damages one visible zombie")
	main.free()
	print("VERTICAL SLICE TESTS: %d passed, %d failed" % [total_tests - failed_tests, failed_tests])
	get_tree().quit(1 if failed_tests > 0 else 0)

func assert_true(condition: bool, test_name: String) -> void:
	total_tests += 1
	if not condition:
		failed_tests += 1
		printerr("[FAIL] ", test_name)
	else:
		print("[PASS] ", test_name)

func assert_equal(actual, expected, test_name: String) -> void:
	assert_true(actual == expected, "%s (expected %s, got %s)" % [test_name, str(expected), str(actual)])
