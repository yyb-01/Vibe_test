extends Node

# res://tests/combat_wave_test_runner.gd
# Test runner for Phase 4: Combat layers, Zombie AI target/barricade breakthrough, and Wave completion

const HealthComponentClass = preload("res://scripts/components/health_component.gd")
const HitboxComponentClass = preload("res://scripts/components/hitbox_component.gd")
const ProjectileClass = preload("res://entities/combat/projectile.gd")
const ZombieClass = preload("res://entities/zombies/zombie.gd")
const StructureBaseClass = preload("res://entities/structures/structure_base.gd")
const StructureDataClass = preload("res://scripts/data/structure_data.gd")
const WaveDataClass = preload("res://scripts/data/wave_data.gd")
const WaveSpawnEntryDataClass = preload("res://scripts/data/wave_spawn_entry_data.gd")
const WaveControllerClass = preload("res://scenes/defense/wave_controller.gd")
const GameStateMachine = preload("res://scripts/core/game_state_machine.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _ready() -> void:
	print("========================================")
	print(" RUNNING PHASE 4 COMBAT & WAVE TEST SUITE")
	print("========================================")
	
	test_collision_layers_and_damage_pipeline()
	test_health_component_rules()
	test_zombie_structure_attack_and_repath()
	test_wave_controller_flow_and_victory()
	
	print("========================================")
	print(" TEST RESULTS: %d Passed, %d Failed (Total: %d)" % [passed_tests, failed_tests, total_tests])
	print("========================================")
	
	if failed_tests > 0:
		print("FAILED: Some combat/wave tests failed.")
		get_tree().quit(1)
	else:
		print("SUCCESS: All Phase 4 combat & wave tests passed successfully!")
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

func test_collision_layers_and_damage_pipeline() -> void:
	print("\n--- Test: Combat Collision Layers (Section E.3) ---")
	var zombie_scene = load("res://entities/zombies/zombie.tscn")
	var zombie = zombie_scene.instantiate() as Node2D
	add_child(zombie)
	
	assert_equal(zombie.get("collision_layer"), 4, "Zombie body collision layer is 4 (Layer 3: Enemy)")
	
	var zombie_hitbox = zombie.find_child("HitboxComponent", true, false) as Area2D
	assert_true(zombie_hitbox != null, "Zombie has HitboxComponent")
	assert_equal(zombie_hitbox.collision_layer, 4, "Zombie hitbox layer is 4 (Enemy)")
	assert_true((zombie_hitbox.collision_mask & 16) != 0, "Zombie hitbox listens to Layer 5 (PlayerHit=16)")
	
	var proj_scene = load("res://entities/combat/projectile.tscn")
	var proj = proj_scene.instantiate() as Area2D
	add_child(proj)
	
	assert_equal(proj.collision_layer, 16, "Projectile layer is 16 (Layer 5: PlayerHit)")
	assert_true((proj.collision_mask & 4) != 0, "Projectile mask includes Layer 3 (Enemy=4)")
	assert_true((proj.collision_mask & 2) == 0, "Projectile mask excludes Layer 2 (Player friendly-fire immunity)")
	
	# Test projectile hit directly
	var zombie_hc = zombie.find_child("HealthComponent", true, false) as HealthComponentClass
	assert_true(zombie_hc != null, "Zombie has HealthComponent")
	
	var initial_hp = zombie_hc.current_health
	proj._handle_hit(zombie_hitbox)
	assert_equal(zombie_hc.current_health, initial_hp - proj.damage, "Direct projectile hit accurately applies damage")
	
	zombie.queue_free()
	proj.queue_free()

func test_health_component_rules() -> void:
	print("\n--- Test: HealthComponent Clamp, Cooldown and Single-Died Signal ---")
	var hc = HealthComponentClass.new()
	hc.max_health = 100.0
	hc.current_health = 100.0
	add_child(hc)
	
	var died_counter = [0]
	hc.died.connect(func(_src): died_counter[0] += 1)
	
	# Damage apply
	var dmg_applied = hc.apply_damage(40.0)
	assert_true(dmg_applied, "Damage applied")
	assert_equal(hc.current_health, 60.0, "Health reduced to 60")
	
	# Heal
	var healed = hc.heal(30.0)
	assert_equal(healed, 30.0, "Healed 30")
	assert_equal(hc.current_health, 90.0, "Health now 90")
	
	# Overheal clamp
	var overheal = hc.heal(50.0)
	assert_equal(overheal, 10.0, "Overheal clamped to max (10 healed)")
	assert_equal(hc.current_health, 100.0, "Health clamped at max 100")
	
	# Lethal damage
	hc.apply_damage(150.0)
	assert_equal(hc.current_health, 0.0, "Health clamped at 0.0")
	assert_true(hc.is_dead, "is_dead is true")
	assert_equal(died_counter[0], 1, "Died signal emitted once")
	
	# Subsequent damage on dead target
	var extra_dmg = hc.apply_damage(50.0)
	assert_true(not extra_dmg, "Dead entity rejects further damage")
	assert_equal(died_counter[0], 1, "Died signal not emitted repeatedly")
	
	hc.queue_free()

func test_zombie_structure_attack_and_repath() -> void:
	print("\n--- Test: Zombie Attack on Structure and Repath after Destruction ---")
	var zombie_scene = load("res://entities/zombies/zombie.tscn")
	var zombie = zombie_scene.instantiate() as ZombieClass
	add_child(zombie)
	
	var barricade_scene = load("res://entities/structures/barricade.tscn")
	var barricade = barricade_scene.instantiate() as StructureBaseClass
	add_child(barricade)
	
	# Add health component to barricade for destruction test
	var hc = HealthComponentClass.new()
	hc.name = "HealthComponent"
	hc.max_health = 30.0
	hc.current_health = 30.0
	barricade.add_child(hc)
	barricade.current_health = 30.0
	
	# Set zombie target to barricade
	zombie.current_target = barricade
	zombie.current_state = ZombieClass.State.ATTACK
	
	# Simulate attack
	zombie._apply_attack_damage(barricade)
	assert_equal(hc.current_health, 15.0, "Barricade took 15 damage from zombie")
	
	# Lethal second attack
	zombie._apply_attack_damage(barricade)
	assert_equal(hc.current_health, 0.0, "Barricade destroyed")
	assert_true(hc.is_dead, "Barricade dead")
	
	# Barricade freed
	barricade.free()
	
	# Next process tick: Zombie detects target destroyed and returns to SEEK
	zombie._handle_attack()
	assert_equal(zombie.current_state, ZombieClass.State.SEEK, "Zombie returns to SEEK after target destruction")
	
	zombie.queue_free()

func test_wave_controller_flow_and_victory() -> void:
	print("\n--- Test: WaveController Spawning, Tracking and State Resolution ---")
	var wc = WaveControllerClass.new()
	add_child(wc)
	
	# Setup test wave with 2 zombies
	var wave_res = WaveDataClass.new()
	wave_res.day = 1
	wave_res.completion_delay = 0.1
	
	var entry = WaveSpawnEntryDataClass.new()
	entry.count = 2
	entry.spawn_interval = 0.05
	entry.start_delay = 0.0
	wave_res.entries = [entry]
	
	# Spawner dummy
	var spawner = Node2D.new()
	spawner.name = "DummySpawner"
	add_child(spawner)
	
	var spawner_script = load("res://scenes/defense/zombie_spawner.gd")
	spawner.set_script(spawner_script)
	wc.spawner = spawner
	
	wc.start_wave(wave_res)
	assert_equal(wc.total_to_spawn, 2, "Total zombies to spawn is 2")
	assert_true(wc.is_wave_active, "Wave is active")
	
	# Process spawner ticks
	wc._process(0.1)
	wc._process(0.1)
	assert_equal(wc.spawned_count, 2, "Both zombies spawned")
	assert_equal(wc.alive_count, 2, "2 zombies alive")
	
	# Track wave completed signal
	var wave_done = [false]
	EventBus.wave_completed.connect(func(_d): wave_done[0] = true)
	
	# Kill first zombie
	var enemies = wc.enemies_container.get_children()
	if enemies.size() > 0:
		var z_hc = enemies[0].find_child("HealthComponent", true, false)
		if z_hc != null:
			z_hc.apply_damage(100.0)
	assert_equal(wc.alive_count, 1, "1 zombie alive after kill")
	assert_true(not wave_done[0], "Wave not done yet")
	
	# Transition state machine to NIGHT_DEFENSE to verify complete_night
	if GameManager.current_state != GameStateMachine.State.NIGHT_DEFENSE:
		GameManager.state_machine.current_state = GameStateMachine.State.NIGHT_DEFENSE
		
	# Kill second zombie
	if enemies.size() > 1:
		var z_hc = enemies[1].find_child("HealthComponent", true, false)
		if z_hc != null:
			z_hc.apply_damage(100.0)
	assert_equal(wc.alive_count, 0, "0 zombies alive")
	assert_true(wave_done[0], "Wave victory signal triggered when alive_count reaches 0")
	
	wc.queue_free()
	spawner.queue_free()
