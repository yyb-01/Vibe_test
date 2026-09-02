extends Node

var _current_owner: Node
var _queue: Array[Dictionary] = []
var _connected_owners: Array[Node] = []
var _owner_callbacks: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func has_active_modal() -> bool:
	return is_instance_valid(_current_owner) or not _queue.is_empty()

func request(owner: Node, on_granted: Callable) -> void:
	if not is_instance_valid(owner):
		return
	if owner == _current_owner:
		on_granted.call()
		return
	for entry in _queue:
		if entry.get("owner") == owner:
			return
	_queue.append({"owner": owner, "callback": on_granted})
	_try_grant_next()

func release(owner: Node) -> void:
	_queue = _queue.filter(func(entry: Dictionary) -> bool:
		var queued_owner = entry.get("owner")
		return is_instance_valid(queued_owner) and queued_owner != owner
	)
	if owner == _current_owner or not is_instance_valid(_current_owner):
		_current_owner = null
		if _queue.is_empty():
			_cancel_hit_stop()
			get_tree().paused = false
		else:
			call_deferred("_try_grant_next")

func clear() -> void:
	_queue.clear()
	_current_owner = null
	for owner in _connected_owners:
		var callback = _owner_callbacks.get(owner)
		if is_instance_valid(owner) and callback is Callable and callback.is_valid() and owner.tree_exiting.is_connected(callback):
			owner.tree_exiting.disconnect(callback)
	_connected_owners.clear()
	_owner_callbacks.clear()
	_cancel_hit_stop()
	get_tree().paused = false

func _try_grant_next() -> void:
	if is_instance_valid(_current_owner) and _current_owner.is_inside_tree():
		return
	_current_owner = null
	while not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		var owner := entry.owner as Node
		if not is_instance_valid(owner) or not owner.is_inside_tree():
			continue
		_current_owner = owner
		_connect_owner_exit(owner)
		_cancel_hit_stop()
		get_tree().paused = true
		(entry.callback as Callable).call()
		return
	get_tree().paused = false

func _connect_owner_exit(owner: Node) -> void:
	if owner in _connected_owners:
		return
	_connected_owners.append(owner)
	var callback := _on_owner_tree_exiting.bind(owner)
	_owner_callbacks[owner] = callback
	owner.tree_exiting.connect(callback, CONNECT_ONE_SHOT)

func _on_owner_tree_exiting(owner: Node) -> void:
	_connected_owners.erase(owner)
	_owner_callbacks.erase(owner)
	release(owner)

func _cancel_hit_stop() -> void:
	var hit_effect_manager := get_node_or_null("/root/HitEffectManager")
	if is_instance_valid(hit_effect_manager) and hit_effect_manager.has_method("cancel_hit_stop"):
		hit_effect_manager.call("cancel_hit_stop")
