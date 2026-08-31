extends SceneTree

const SPAWN_WAIT_SECONDS := 3.0
const MAP_PATHS := [
    "res://scenes/maps/map_1.tscn",
    "res://scenes/maps/map_2.tscn",
    "res://scenes/maps/map_3.tscn",
    "res://scenes/maps/map_4.tscn"
]
var elapsed := 0.0
var map_scene: PackedScene
var map_instance: Node
var map_index := -1
var transitioning := false

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

    _load_next_map()

func _load_next_map() -> void:
    map_index += 1
    elapsed = 0.0
    if map_index >= MAP_PATHS.size():
        print("All assertions passed. All four maps loaded and spawned zombies successfully.")
        quit(0)
        return

    var map_path: String = MAP_PATHS[map_index]
    print("Loading verification map: ", map_path)
    map_scene = load(map_path) as PackedScene
    if not map_scene:
        push_error("Assertion failed: Could not load " + map_path)
        quit(1)
        return
    map_instance = map_scene.instantiate()
    get_root().add_child(map_instance)

func _process(delta: float) -> bool:
    if transitioning:
        return false
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

        print("Map assertions passed: ", MAP_PATHS[map_index])
        transitioning = true
        map_instance.process_mode = Node.PROCESS_MODE_DISABLED
        if map_instance is CanvasItem:
            map_instance.visible = false
        call_deferred("_finish_map_transition")
        return false
    return false

func _finish_map_transition() -> void:
    if is_instance_valid(map_instance):
        map_instance.free()
    get_root().get_node("ObjectPoolManager").call("clear")
    get_root().get_node("SpatialGrid").call("clear")
    transitioning = false
    _load_next_map()
