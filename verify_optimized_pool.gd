extends Node

const ZOMBIE_SCENE: PackedScene = preload("res://scenes/enemies/optimized_zombie.tscn")
const TEST_COUNT: int = 1000

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var target := Node2D.new()
	target.add_to_group("player")
	add_child(target)
	ObjectPoolManager.configure_pool(ZOMBIE_SCENE, TEST_COUNT, 1200, self)
	assert(ObjectPoolManager.get_active_count(ZOMBIE_SCENE) == 0)
	var key: String = ZOMBIE_SCENE.resource_path
	assert((ObjectPoolManager.inactive_pool[key] as Array).size() == TEST_COUNT)

	for index in range(TEST_COUNT):
		var zombie: Node2D = ObjectPoolManager.spawn(ZOMBIE_SCENE, Vector2(index, 0), 0.0, [30, 100.0, target])
		assert(zombie != null)
	assert(ObjectPoolManager.get_active_count(ZOMBIE_SCENE) == TEST_COUNT)

	var snapshot: Array[Node2D] = ObjectPoolManager.get_active(ZOMBIE_SCENE).duplicate()
	for index in range(snapshot.size()):
		ObjectPoolManager.despawn(snapshot[index])
	assert(ObjectPoolManager.get_active_count(ZOMBIE_SCENE) == 0)
	assert((ObjectPoolManager.inactive_pool[key] as Array).size() == TEST_COUNT)
	print("Optimized pool self-check passed: 1000 instances reused.")
	get_tree().quit(0)
