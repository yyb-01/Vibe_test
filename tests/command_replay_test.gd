extends SceneTree

# res://tests/command_replay_test.gd
# Verifies deterministic simulation replay: identical command log + seed yields identical rule checksum.

const SimulationHostClass = preload("res://scripts/simulation/simulation_host.gd")
const SimulationCommandsClass = preload("res://scripts/simulation/commands/simulation_commands.gd")
const EntityStateClass = preload("res://scripts/simulation/model/entity_state.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("========================================")
	print(" RUNNING COMMAND REPLAY TEST SUITE")
	print("========================================")

	test_deterministic_replay()

	print("========================================")
	print(" TEST RESULTS: %d Passed, %d Failed (Total: %d)" % [passed_tests, failed_tests, total_tests])
	print("========================================")

	quit(1 if failed_tests > 0 else 0)

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

func test_deterministic_replay() -> void:
	print("\n--- Test: Same Command Log + Seed -> Same Checksum ---")
	var seed_val: int = 98765

	# Run Run 1
	var host1 := SimulationHostClass.new(seed_val)
	_setup_host_entities(host1)
	var checksum1 := _run_simulation_script(host1)

	# Run Run 2
	var host2 := SimulationHostClass.new(seed_val)
	_setup_host_entities(host2)
	var checksum2 := _run_simulation_script(host2)

	assert_equal(checksum1, checksum2, "Simulation run 1 and run 2 produce identical rule checksums")

func _setup_host_entities(host: SimulationHostClass) -> void:
	var player := EntityStateClass.new(100, &"player", 1)
	player.position = Vector2.ZERO
	player.health = 100.0
	player.max_health = 100.0
	host.world.add_entity(player)
	host.world.players[1].controlled_entity_id = 100

func _run_simulation_script(host: SimulationHostClass) -> int:
	var final_checksum: int = 0

	for tick in range(1, 61):
		if tick == 5:
			# Move right
			host.enqueue_command(SimulationCommandsClass.create_move_intent(1, 100, Vector2.RIGHT, 1, tick))
		elif tick == 15:
			# Dash
			host.enqueue_command(SimulationCommandsClass.create_ability_command(1, 100, &"dash", true, Vector2.RIGHT, 2, tick))
		elif tick == 25:
			# Shoot
			host.enqueue_command(SimulationCommandsClass.create_ability_command(1, 100, &"shoot", true, Vector2.RIGHT, 3, tick))
		elif tick == 35:
			# Build barricade
			host.enqueue_command(SimulationCommandsClass.create_build_command(1, 100, &"barricade_wood", Vector2i(2, 2), 0, 0, 4, tick))

		var res = host.step_one_tick()
		final_checksum = res["checksum"]

	return final_checksum
