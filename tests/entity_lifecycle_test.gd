extends SceneTree

# res://tests/entity_lifecycle_test.gd
# Conformance test for authoritative EntityId reservation, lifecycle state, damage resolution, and cleanup.

const SimulationHostClass = preload("res://scripts/simulation/simulation_host.gd")
const EntityStateClass = preload("res://scripts/simulation/model/entity_state.gd")
const DomainEventsClass = preload("res://scripts/simulation/events/domain_events.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("========================================")
	print(" RUNNING ENTITY LIFECYCLE TEST SUITE")
	print("========================================")

	test_entity_id_issuance()
	test_entity_damage_and_despawn_lifecycle()
	test_snapshot_capture_and_restore()

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

func test_entity_id_issuance() -> void:
	print("\n--- Test: EntityId Generation and Monotonicity ---")
	var host := SimulationHostClass.new(123)
	var id1 := host.world.id_generator.generate_entity_id()
	var id2 := host.world.id_generator.generate_entity_id()
	assert_true(id2 > id1, "Subsequent EntityIds are monotonically increasing")
	assert_true(id1 > 0, "EntityId is positive non-zero")

func test_entity_damage_and_despawn_lifecycle() -> void:
	print("\n--- Test: Damage, Death Event, and Despawn Lifecycle ---")
	var host := SimulationHostClass.new(123)

	var zombie := EntityStateClass.new(201, &"zombie_basic", 0)
	zombie.health = 30.0
	zombie.max_health = 30.0
	host.world.add_entity(zombie)

	assert_true(host.world.get_entity(201) != null, "Zombie added to world")
	assert_true(zombie.is_alive(), "Zombie starts in alive state")

	var events: Array[Dictionary] = []
	# Inflict lethal damage
	host.combat_system.apply_damage(201, 100, 35.0, false, events)

	assert_equal(zombie.health, 0.0, "Zombie health reduced to 0")
	assert_equal(zombie.lifecycle, EntityStateClass.Lifecycle.DESPAWNING, "Zombie lifecycle set to DESPAWNING")

	# Verify death event emitted
	var found_death: bool = false
	for ev in events:
		if ev.get("event_type", 0) == DomainEventsClass.EventType.ENTITY_DIED:
			found_death = true
			assert_equal(ev["payload"].get("entity_id", 0), 201, "Death event contains zombie entity ID")
	assert_true(found_death, "EntityDied event generated on lethal damage")

	# Step tick to commit lifecycle cleanup
	host.step_one_tick()
	assert_true(host.world.get_entity(201) == null, "Zombie removed from active simulation world after lifecycle commit")

func test_snapshot_capture_and_restore() -> void:
	print("\n--- Test: World Snapshot Capture and Full Restore ---")
	var host := SimulationHostClass.new(555)
	host.world.session_state.day = 3
	host.world.session_state.shared_storage[&"wood"] = 150

	var entity := EntityStateClass.new(301, &"barricade_wood", 1)
	entity.position = Vector2(128.0, 64.0)
	entity.health = 80.0
	host.world.add_entity(entity)

	var snapshot = host.capture_snapshot()
	assert_true(snapshot is Dictionary, "Snapshot captured as dictionary")

	# Create new host and restore
	var new_host := SimulationHostClass.new(999)
	new_host.restore_snapshot(snapshot)

	assert_equal(new_host.world.session_state.day, 3, "Restored session day matches")
	assert_equal(new_host.world.session_state.shared_storage.get(&"wood", 0), 150, "Restored shared storage matches")
	var restored_entity = new_host.world.get_entity(301)
	assert_true(restored_entity != null, "Restored entity exists in new world")
	assert_equal(restored_entity.position, Vector2(128.0, 64.0), "Restored entity position matches")
	assert_equal(restored_entity.health, 80.0, "Restored entity health matches")
