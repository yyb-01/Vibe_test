extends SceneTree

const SPAWN_WAIT_SECONDS := 3.0
var elapsed := 0.0
var map_scene = preload("res://scenes/maps/map_1.tscn")
var map_instance: Node

func _initialize() -> void:
    print("Starting map load test...")
    var root = get_root()
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
