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
const CHARACTER_SHEET_PATHS := [
    "res://assets/graphics/animated/player_scavenger_sheet_v1.png",
    "res://assets/graphics/animated/player_medic_sheet_v1.png",
    "res://assets/graphics/animated/player_ranger_sheet_v1.png",
    "res://assets/graphics/animated/player_bulwark_sheet_v1.png",
    "res://assets/graphics/animated/player_pyro_sheet_v1.png",
    "res://assets/graphics/animated/player_engineer_sheet_v1.png",
    "res://assets/graphics/animated/player_reaper_sheet_v1.png",
    "res://assets/graphics/animated/player_chronomancer_sheet_v1.png"
]
var elapsed := 0.0
var map_scene: PackedScene
var map_instance: Node
var map_index := -1
var transitioning := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    print("Starting map load test...")
    await _verify_modal_queue()

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
    _verify_character_sheets()

    _load_next_map()

func _verify_modal_queue() -> void:
    var first := Node.new()
    var second := Node.new()
    add_child(first)
    add_child(second)
    var opened: Array[String] = []
    ModalManager.clear()
    ModalManager.request(first, func() -> void: opened.append("first"))
    ModalManager.request(second, func() -> void: opened.append("second"))
    assert(opened == ["first"] and get_tree().paused, "Modal queue opened overlapping panels")
    ModalManager.release(first)
    await get_tree().process_frame
    assert(opened == ["first", "second"] and get_tree().paused, "Queued modal was not granted")
    ModalManager.release(second)
    await get_tree().process_frame
    assert(not get_tree().paused, "Modal queue left the game paused")
    first.free()
    second.free()

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
                if enemy.collision_layer == 0:
                    continue # Death fade: visible briefly, but intentionally non-colliding.
                assert(enemy.collision_layer == 4 and enemy.collision_mask == 2, "Enemies must collide with World only")
                active_enemy_count += 1
        if active_enemy_count == 0:
            push_error("Assertion failed: No zombies spawned")
            get_tree().quit(1)
            return
        if map_index == 0:
            var pooled_enemy_count := get_tree().get_nodes_in_group("enemies").size()
            assert(pooled_enemy_count <= 120, "Enemy pool warm-up regressed to a scene-freezing size: %d" % pooled_enemy_count)

        if map_index == 0:
            var mission := (load("res://scenes/world/mission_event.tscn") as PackedScene).instantiate()
            map_instance.add_child(mission)
            mission.call("configure_for_map", "map_1")
            mission.call("_activate")
            assert(not get_tree().paused, "MissionEvent paused seamless combat")
            assert(is_instance_valid(mission.choice_layer) and mission.choice_layer.get_parent() != mission, "Mission choice UI is not scene-root independent")
            assert(mission.choice_layer.process_mode == Node.PROCESS_MODE_ALWAYS, "Mission choice UI cannot process during pause")
            mission.call("_select_default_if_pending", mission.choice_generation)
            assert(mission.branch_name == "현장 수색" and not is_instance_valid(mission.choice_layer), "Mission safety fallback did not close the choice UI")
            mission.queue_free()
            for direction in ["up", "down", "left", "right"]:
                player.facing = direction
                player.call("_set_character_frame", 0)
                var expected_row := 3 if direction == "up" else (0 if direction == "down" else 1)
                assert(int(player.sprite.region_rect.position.y / player.sprite.region_rect.size.y) == expected_row)
                assert(player.call("_gun_mount_for_facing").length() < 30.0, "Gun mount is detached from the player hands")
            player.skill_cooldown = 0.0
            Input.action_press("move_right")
            var space_event := InputEventKey.new()
            space_event.pressed = true
            space_event.keycode = KEY_SPACE
            player._unhandled_input(space_event)
            var skill_event := InputEventKey.new()
            skill_event.pressed = true
            skill_event.keycode = KEY_E
            player._unhandled_input(skill_event)
            Input.action_release("move_right")
            assert(player.dash_time > 0.0 and player.skill_cooldown == 0.0, "Dash + skill input overlap was not blocked")
            player.dash_time = 0.0
            assert(player._get_active_enemies().size() < get_tree().get_nodes_in_group("enemies").size(), "Pooled enemies leaked into skill targets")

        print("Map assertions passed: ", MAP_PATHS[map_index])
        transitioning = true
        map_instance.process_mode = Node.PROCESS_MODE_DISABLED
        if map_instance is CanvasItem:
            map_instance.visible = false
        call_deferred("_finish_map_transition")
        return

func _verify_character_sheets() -> void:
    for sheet_path in CHARACTER_SHEET_PATHS:
        var texture := load(sheet_path) as Texture2D
        assert(texture != null, "Character sheet failed to load: " + sheet_path)
        assert(texture.get_width() > 0 and texture.get_height() > 0, "Character sheet has no dimensions: " + sheet_path)
        var aspect := float(texture.get_width()) / float(texture.get_height())
        assert(texture.get_width() >= 800 and texture.get_height() >= 800 and aspect > 0.85 and aspect < 1.15, "Invalid 4x4 character sheet: " + sheet_path)

func _finish_map_transition() -> void:
    if is_instance_valid(map_instance):
        map_instance.free()
    ObjectPoolManager.clear()
    SpatialGrid.clear()
    transitioning = false
    _load_next_map()
