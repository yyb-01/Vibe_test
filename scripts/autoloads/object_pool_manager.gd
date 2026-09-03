extends Node

## PackedScene-keyed pool. `acquire/release` remains for the existing game code.
var active_pool: Dictionary = {}
var inactive_pool: Dictionary = {}

var _configs: Dictionary = {}
var _pool_ids: Dictionary = {}
var _instance_keys: Dictionary = {}

func configure_pool(scene: PackedScene, pool_size: int, max_size: int, parent: Node = null) -> void:
	if scene == null:
		push_error("ObjectPoolManager: scene is required")
		return
	var pool_parent := parent if is_instance_valid(parent) else get_tree().current_scene
	if not is_instance_valid(pool_parent):
		push_error("ObjectPoolManager: pool parent is required")
		return
	var key := _scene_key(scene)
	if _configs.has(key):
		var config: Dictionary = _configs[key]
		config["parent"] = pool_parent
		config["max_size"] = maxi(int(config["max_size"]), maxi(pool_size, max_size))
		_configs[key] = config
	else:
		_configs[key] = {"scene": scene, "parent": pool_parent, "max_size": maxi(pool_size, max_size)}
		active_pool[key] = [] as Array[Node2D]
		inactive_pool[key] = [] as Array[Node2D]
	warm_pool_scene(scene, pool_size)

func register_pool(pool_id: String, scene: PackedScene, parent: Node, initial_size: int = 0) -> void:
	if scene == null or not is_instance_valid(parent):
		push_error("ObjectPoolManager: Invalid pool registration: " + pool_id)
		return
	_pool_ids[pool_id] = scene
	configure_pool(scene, initial_size, 4096, parent)

func warm_pool(pool_id: String, target_size: int) -> void:
	if not _pool_ids.has(pool_id):
		return
	warm_pool_scene(_pool_ids[pool_id] as PackedScene, target_size)

func warm_pool_scene(scene: PackedScene, target_size: int) -> void:
	var key := _scene_key(scene)
	if not _configs.has(key):
		configure_pool(scene, target_size, maxi(target_size, 1), get_tree().current_scene)
		return
	var config: Dictionary = _configs[key]
	var parent: Node = config["parent"] as Node
	if not is_instance_valid(parent):
		return
	var free_list: Array[Node2D] = inactive_pool[key]
	var total := free_list.size() + (active_pool[key] as Array[Node2D]).size()
	var count := mini(maxi(0, target_size - free_list.size()), maxi(0, int(config["max_size"]) - total))
	for _index in range(count):
		var instance := _create_instance(scene, key, parent)
		if instance == null:
			return
		free_list.append(instance)

func spawn(scene: PackedScene, global_pos: Vector2, rot: float = 0.0, args: Array = []) -> Node2D:
	if scene == null:
		return null
	var key := _scene_key(scene)
	if not _configs.has(key):
		configure_pool(scene, 0, 1024, get_tree().current_scene)
	if not _configs.has(key):
		return null

	var config: Dictionary = _configs[key]
	var parent: Node = config["parent"] as Node
	if not is_instance_valid(parent):
		return null
	var free_list: Array[Node2D] = inactive_pool[key]
	var instance: Node2D = null
	while not free_list.is_empty():
		var candidate: Node2D = free_list.pop_back()
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			instance = candidate
			break
	if instance == null:
		var active_count := (active_pool[key] as Array[Node2D]).size()
		if active_count + free_list.size() >= int(config["max_size"]):
			return null
		instance = _create_instance(scene, key, parent)
		if instance == null:
			return null

	_instance_keys[instance] = key
	instance.set_meta("_pool_release_pending", false)
	instance.global_position = global_pos
	instance.rotation = rot
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	instance.set_process(true)
	instance.set_physics_process(true)
	instance.show()
	_restore_collision(instance)
	var active_list: Array[Node2D] = active_pool[key]
	active_list.append(instance)
	if instance.has_method("on_spawn"):
		instance.callv("on_spawn", args)
	elif instance.has_method("reset"):
		instance.call("reset")
	return instance

func despawn(instance: Node2D) -> void:
	if not is_instance_valid(instance) or instance.is_queued_for_deletion():
		return
	if not _instance_keys.has(instance) or instance.get_meta("_pool_release_pending", false):
		return
	var key: String = _instance_keys[instance]
	if not _configs.has(key):
		return
	instance.set_meta("_pool_release_pending", true)
	if instance.has_method("on_despawn"):
		instance.call("on_despawn")
	_remove_from_spatial_index(instance)
	instance.hide()
	instance.set_process(false)
	instance.set_physics_process(false)
	instance.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_disable_collision(instance)
	var active_list: Array[Node2D] = active_pool[key]
	active_list.erase(instance)
	var free_list: Array[Node2D] = inactive_pool[key]
	free_list.append(instance)

const DEFAULT_POOL_SCENES := {
	"bullet": "res://scenes/weapons/bullet.tscn",
	"damage_number": "res://scenes/ui/effects/damage_number.tscn",
	"blood_impact": "res://scenes/effects/blood_impact.tscn",
	"player_hit": "res://scenes/effects/player_hit.tscn",
	"exp_gem": "res://scenes/items/exp_gem.tscn",
	"acid_projectile": "res://scenes/weapons/acid_projectile.tscn"
}

func _try_register_default_pool(pool_id: String) -> bool:
	if not DEFAULT_POOL_SCENES.has(pool_id):
		return false
	var scene_path: String = DEFAULT_POOL_SCENES[pool_id]
	if not ResourceLoader.exists(scene_path):
		return false
	var scene: PackedScene = load(scene_path)
	if not scene:
		return false
	var parent: Node = get_tree().current_scene
	if not is_instance_valid(parent):
		parent = self
	register_pool(pool_id, scene, parent)
	return true

func acquire(pool_id: String, global_pos: Vector2) -> Node:
	if not _pool_ids.has(pool_id):
		if not _try_register_default_pool(pool_id):
			push_error("ObjectPoolManager: Pool ID not found: " + pool_id)
			return null
	return spawn(_pool_ids[pool_id] as PackedScene, global_pos)

func release(instance: Node) -> void:
	if instance is Node2D:
		despawn(instance as Node2D)

func get_active_count(scene: PackedScene) -> int:
	var key := _scene_key(scene)
	return (active_pool.get(key, []) as Array).size()

func get_active(scene: PackedScene) -> Array[Node2D]:
	var key := _scene_key(scene)
	return active_pool.get(key, [] as Array[Node2D]) as Array[Node2D]

func clear() -> void:
	var configs := _configs.duplicate()
	var nodes_by_key: Dictionary = {}
	for key in configs:
		var nodes: Array = []
		nodes.append_array(active_pool.get(key, []))
		nodes.append_array(inactive_pool.get(key, []))
		nodes_by_key[key] = nodes
	_configs.clear()
	_pool_ids.clear()
	_instance_keys.clear()
	active_pool.clear()
	inactive_pool.clear()
	for key in configs:
		var nodes: Array = nodes_by_key[key]
		for instance in nodes:
			if is_instance_valid(instance) and not instance.is_queued_for_deletion():
				_remove_from_spatial_index(instance)
				instance.free()

func _scene_key(scene: PackedScene) -> String:
	if scene.resource_path.is_empty():
		return "instance:%d" % scene.get_instance_id()
	return scene.resource_path

func _create_instance(scene: PackedScene, key: String, parent: Node) -> Node2D:
	var instance := scene.instantiate() as Node2D
	if instance == null:
		push_error("ObjectPoolManager: scene root must extend Node2D: " + scene.resource_path)
		return null
	instance.set_meta("_pool_scene_key", key)
	instance.set_meta("_pool_release_pending", true)
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	instance.set_process(false)
	instance.set_physics_process(false)
	instance.hide()
	parent.add_child(instance)
	_instance_keys[instance] = key
	if instance.has_method("on_despawn"):
		instance.call("on_despawn")
	instance.tree_exiting.connect(_on_pooled_instance_exiting.bind(instance), CONNECT_ONE_SHOT)
	_disable_collision(instance)
	_remove_from_spatial_index(instance)
	return instance

func _disable_collision(instance: Node2D) -> void:
	var collision := instance as CollisionObject2D
	if collision:
		if not instance.has_meta("_pool_collision_layer"):
			instance.set_meta("_pool_collision_layer", collision.collision_layer)
			instance.set_meta("_pool_collision_mask", collision.collision_mask)
		collision.set_deferred("collision_layer", 0)
		collision.set_deferred("collision_mask", 0)
	for shape in instance.find_children("*", "CollisionShape2D", true, false):
		(shape as CollisionShape2D).set_deferred("disabled", true)

func _restore_collision(instance: Node2D) -> void:
	var collision := instance as CollisionObject2D
	if collision:
		var layer = int(instance.get_meta("_pool_collision_layer", collision.collision_layer))
		var mask = int(instance.get_meta("_pool_collision_mask", collision.collision_mask))
		collision.set_deferred("collision_layer", layer)
		collision.set_deferred("collision_mask", mask)
	for shape in instance.find_children("*", "CollisionShape2D", true, false):
		(shape as CollisionShape2D).set_deferred("disabled", false)

func _remove_from_spatial_index(instance: Node) -> void:
	var grid := get_node_or_null("/root/SpatialGrid")
	if not is_instance_valid(grid):
		return
	if instance.is_in_group("enemies") and grid.has_method("remove"):
		grid.call("remove", instance)
	elif instance.has_method("get_exp_amount") and grid.has_method("remove_item"):
		grid.call("remove_item", instance)

func _on_pooled_instance_exiting(instance: Node2D) -> void:
	if not _instance_keys.has(instance):
		return
	var key: String = _instance_keys[instance]
	if active_pool.has(key):
		(active_pool[key] as Array[Node2D]).erase(instance)
	if inactive_pool.has(key):
		(inactive_pool[key] as Array[Node2D]).erase(instance)
	_instance_keys.erase(instance)
