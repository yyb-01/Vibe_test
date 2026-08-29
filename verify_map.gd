extends SceneTree

const SPAWN_WAIT_SECONDS := 3.0
var elapsed := 0.0
var map_scene: PackedScene
var map_instance: Node

func _initialize() -> void:
    print("Starting map load test...")
    var root = get_root()

    # SceneTree scripts do not instantiate project autoloads automatically.
    # Create the same singleton nodes before loading scenes that reference them.
    var autoloads := {
        "EventBus": "res://scripts/autoloads/event_bus.gd",
        "ObjectPoolManager": "res://scripts/autoloads/object_pool_manager.gd",
        "SpatialGrid": "res://scripts/autoloads/spatial_grid.gd",
        "SaveManager": "res://scripts/autoloads/save_manager.gd",
        "AudioManager": "res://scripts/autoloads/audio_manager.gd",
        "RunStats": "res://scripts/autoloads/run_stats.gd"
    }
    for singleton_name in autoloads:
        var singleton = load(autoloads[singleton_name]).new()
        singleton.name = singleton_name
        root.add_child(singleton)

    map_scene = load("res://scenes/maps/map_1.tscn") as PackedScene
    map_instance = map_scene.instantiate()
    root.add_child(map_instance)

func _process(delta: float) -> bool:
    elapsed += delta
    if elapsed >= SPAWN_WAIT_SECONDS:
        print("Checking verification assertions...")
        var players = get_nodes_in_group("player")
        if players.size() == 0:
            push_error("Assertion failed: No player found in map")
            quit(1)
            return true

        var player = players[0]
        var camera = player.get_node_or_null("Camera2D")
        if not camera:
            push_error("Assertion failed: Camera not found on player")
            quit(1)
            return true

        if not camera.enabled:
            push_error("Assertion failed: Camera is not enabled")
            quit(1)
            return true

        var active_enemy_count := 0
        for enemy in get_nodes_in_group("enemies"):
            if enemy is CanvasItem and enemy.process_mode != Node.PROCESS_MODE_DISABLED and enemy.visible:
                active_enemy_count += 1
        if active_enemy_count == 0:
            push_error("Assertion failed: No zombies spawned")
            quit(1)
            return true

        print("All assertions passed. Map loaded and ran successfully.")
        quit(0)
        return true
    return false
