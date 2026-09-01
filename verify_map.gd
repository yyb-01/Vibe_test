extends Node

const SPAWN_WAIT_SECONDS := 3.0
const MAP_PATHS := [
    "res://scenes/maps/map_1.tscn",
    "res://scenes/maps/map_2.tscn",
    "res://scenes/maps/map_3.tscn",
    "res://scenes/maps/map_4.tscn"
]
const BOSS_PATHS := [
    "res://scenes/enemies/boss_quarantine_warden.tscn",
    "res://scenes/enemies/boss_foundry_juggernaut.tscn",
    "res://scenes/enemies/boss_mire_leviathan.tscn",
    "res://scenes/enemies/boss_director_null.tscn"
]
const WEAPON_UPGRADE_PATHS := [
    "res://data/perks/weap_pistol.tres", "res://data/perks/weap_shotgun.tres",
    "res://data/perks/weap_smg.tres", "res://data/perks/weap_burst.tres",
    "res://data/perks/weap_railgun.tres", "res://data/perks/weap_lightning.tres",
    "res://data/perks/weap_nova.tres", "res://data/perks/weap_orbital.tres"
]
var elapsed := 0.0
var map_scene: PackedScene
var map_instance: Node
var map_index := -1
var transitioning := false

func _ready() -> void:
    print("Starting map load test...")

    RunStats.start_run("statistics_test")
    RunStats.register_weapon("Pistol")
    RunStats.register_combat_hit(25, "critical", "Pistol")
    RunStats.register_evolution("Pistol")
    RunStats.register_damage(18, "스피터", "산성 부채꼴", true)
    var statistics_summary := RunStats.get_summary()
    assert(int(statistics_summary.weapon_damage.Pistol) == 25)
    assert("Pistol" in statistics_summary.used_weapons and "Pistol" in statistics_summary.evolved_weapons)
    assert(String(statistics_summary.death_cause).contains("스피터 · 산성 부채꼴"))

    assert(load("res://scripts/effects/boss_skill_effect.gd") != null)
    assert(load("res://scripts/effects/visual_shadow.gd") != null)
    for sound_paths in AudioManager.SFX_PATHS.values():
        for audio_path in sound_paths:
            assert(load(audio_path) != null, "Audio resource missing: " + audio_path)
    assert(load(AudioManager.WAVE_BGM) != null and load(AudioManager.BOSS_BGM) != null)
    assert(SaveManager.UPGRADE_DEFINITIONS.size() == 18)
    for upgrade_id in SaveManager.UPGRADE_DEFINITIONS:
        var definition: Dictionary = SaveManager.UPGRADE_DEFINITIONS[upgrade_id]
        assert(int(definition.max) > 0 and int(definition.base_cost) > 0)
    var zombie_script := load("res://scripts/enemies/zombie.gd")
    var warning_zombie = zombie_script.new()
    warning_zombie.detonation_countdown = 0.4
    warning_zombie.detonation_duration = 0.8
    assert(is_equal_approx(1.0 - warning_zombie.detonation_countdown / warning_zombie.detonation_duration, 0.5))
    warning_zombie.free()
    var weapon_script := load("res://scripts/weapons/weapon.gd")
    assert(weapon_script.EVOLUTION_CATALOG.size() == WEAPON_UPGRADE_PATHS.size())
    for upgrade_path in WEAPON_UPGRADE_PATHS:
        var weapon = weapon_script.new()
        weapon.data = load(upgrade_path).weapon_data
        assert(weapon.get_evolution_requirements().size() == 2, "Evolution recipe missing: " + upgrade_path)
        weapon.free()
    for boss_path in BOSS_PATHS:
        assert(load(boss_path) != null, "Boss scene failed to load: " + boss_path)

    _load_next_map()

func _load_next_map() -> void:
    map_index += 1
    elapsed = 0.0
    if map_index >= MAP_PATHS.size():
        print("All assertions passed. All four maps loaded and spawned zombies successfully.")
        get_tree().quit(0)
        return

    var map_path: String = MAP_PATHS[map_index]
    print("Loading verification map: ", map_path)
    map_scene = load(map_path) as PackedScene
    if not map_scene:
        push_error("Assertion failed: Could not load " + map_path)
        get_tree().quit(1)
        return
    map_instance = map_scene.instantiate()
    get_tree().root.add_child.call_deferred(map_instance)

func _process(delta: float) -> void:
    if transitioning:
        return
    elapsed += delta
    if elapsed >= SPAWN_WAIT_SECONDS:
        print("Checking verification assertions...")
        var players = get_tree().get_nodes_in_group("player")
        if players.size() == 0:
            push_error("Assertion failed: No player found in map")
            get_tree().quit(1)
            return

        var player = players[0]
        assert(player.collision_layer == 1 and player.collision_mask == 2, "Player collision layers must be Player=1, World mask=2")
        var walls := map_instance.get_node_or_null("Walls") as StaticBody2D
        assert(walls and walls.collision_layer == 2, "Map walls must use World layer 2")
        if map_index == 0:
            var stress_origin: Vector2 = player.global_position
            player.velocity = Vector2(100000.0, 0.0)
            player.call("_move_safely", 300.0, 1.0 / 60.0)
            assert(player.global_position.distance_to(stress_origin) <= 21.01, "Abnormal physics displacement was not clamped")
            player.global_position = stress_origin
            player.velocity = Vector2.ZERO
        var camera = player.get_node_or_null("Camera2D")
        if not camera:
            push_error("Assertion failed: Camera not found on player")
            get_tree().quit(1)
            return

        if not camera.enabled:
            push_error("Assertion failed: Camera is not enabled")
            get_tree().quit(1)
            return

        var active_enemy_count := 0
        for enemy in get_tree().get_nodes_in_group("enemies"):
            if enemy is CanvasItem and enemy.process_mode != Node.PROCESS_MODE_DISABLED and enemy.visible:
                assert(enemy.collision_layer == 4 and enemy.collision_mask == 2, "Enemies must collide with World only")
                active_enemy_count += 1
        if active_enemy_count == 0:
            push_error("Assertion failed: No zombies spawned")
            get_tree().quit(1)
            return

        print("Map assertions passed: ", MAP_PATHS[map_index])
        transitioning = true
        map_instance.process_mode = Node.PROCESS_MODE_DISABLED
        if map_instance is CanvasItem:
            map_instance.visible = false
        call_deferred("_finish_map_transition")
        return

func _finish_map_transition() -> void:
    if is_instance_valid(map_instance):
        map_instance.free()
    ObjectPoolManager.clear()
    SpatialGrid.clear()
    transitioning = false
    _load_next_map()
