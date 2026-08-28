extends SceneTree

var frames_to_wait = 300
var map_scene = preload("res://scenes/maps/map_1.tscn")
var map_instance: Node

func _initialize() -> void:
    print("Starting map load test...")
    var root = get_root()
    map_instance = map_scene.instantiate()
    root.add_child(map_instance)

func _process(delta: float) -> bool:
    frames_to_wait -= 1
    if frames_to_wait <= 0:
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

        var enemies = get_nodes_in_group("enemies")
        if enemies.size() == 0:
            push_error("Assertion failed: No zombies spawned")
            quit(1)
            return true

        print("All assertions passed. Map loaded and ran successfully.")
        quit(0)
        return true
    return false
