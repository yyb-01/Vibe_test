extends Node

var _pools: Dictionary = {} # Key: String (pool_id), Value: Dictionary { "free": Array[Node], "scene": PackedScene, "parent": Node }

func clear() -> void:
	_pools.clear()

func register_pool(pool_id: String, scene: PackedScene, parent: Node, initial_size: int = 0) -> void:
	if _pools.has(pool_id) and is_instance_valid(_pools[pool_id]["parent"]):
		return

	_pools[pool_id] = {
		"free": [] as Array[Node],
		"scene": scene,
		"parent": parent
	}
	warm_pool(pool_id, initial_size)

func warm_pool(pool_id: String, target_size: int) -> void:
	if not _pools.has(pool_id):
		return
	var pool: Dictionary = _pools[pool_id]
	var missing_count: int = maxi(0, target_size - pool["free"].size())
	for i in range(missing_count):
		var instance = pool["scene"].instantiate()
		instance.set_meta("pool_id", pool_id)
		instance.process_mode = Node.PROCESS_MODE_DISABLED
		if instance is CanvasItem:
			instance.visible = false
		pool["parent"].add_child(instance)
		# Pool warm-up runs _ready(), so remove any spatial registration made there.
		if instance.is_in_group("enemies"):
			SpatialGrid.remove(instance)
		elif instance.has_method("get_exp_amount"):
			SpatialGrid.remove_item(instance)
		pool["free"].append(instance)

func acquire(pool_id: String, global_pos: Vector2) -> Node:
	if not _pools.has(pool_id):
		push_error("ObjectPoolManager: Pool ID not found: " + pool_id)
		return null

	var pool: Dictionary = _pools[pool_id]
	var instance: Node = null

	# Clean up any dangling references from scene transitions before popping
	while pool["free"].size() > 0:
		instance = pool["free"].pop_back()
		if is_instance_valid(instance):
			break
		else:
			instance = null

	if not instance:
		instance = pool["scene"].instantiate()
		instance.set_meta("pool_id", pool_id)
		if is_instance_valid(pool["parent"]):
			pool["parent"].add_child(instance)
		else:
			# Fallback if parent was deleted
			get_tree().current_scene.add_child(instance)

	if instance is Node2D:
		instance.global_position = global_pos

	instance.set_meta("_pool_release_pending", false)
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	if instance is CanvasItem:
		instance.visible = true
	if instance.has_node("CollisionShape2D"):
		instance.get_node("CollisionShape2D").disabled = false
	# also for exp gems, check Area2D
	if instance is Area2D:
		for child in instance.get_children():
			if child is CollisionShape2D:
				child.disabled = false

	if instance.has_method("reset"):
		instance.reset()

	return instance

func release(instance: Node) -> void:
	if not is_instance_valid(instance) or instance.get_meta("_pool_release_pending", false):
		return
	instance.set_meta("_pool_release_pending", true)
	if instance is CanvasItem:
		instance.visible = false
	instance.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	call_deferred("_finish_release", instance)

func _finish_release(instance: Node) -> void:
	if not is_instance_valid(instance):
		return
	var pool_id = instance.get_meta("pool_id", "")
	if pool_id == "" or not _pools.has(pool_id):
		# Fallback if it wasn't spawned from pool properly
		instance.queue_free()
		return

	var free_list: Array = _pools[pool_id]["free"]
	if not free_list.has(instance):
		instance.process_mode = Node.PROCESS_MODE_DISABLED
		if instance.has_node("CollisionShape2D"):
			instance.get_node("CollisionShape2D").disabled = true
		if instance is Area2D:
			for child in instance.get_children():
				if child is CollisionShape2D:
					child.disabled = true
		free_list.append(instance)
