extends Node

var _current_owner: Node
var _queue: Array[Dictionary] = []

func request(owner: Node, on_granted: Callable) -> void:
	if not is_instance_valid(owner):
		return
	if owner == _current_owner:
		on_granted.call()
		return
	for entry in _queue:
		if entry.owner == owner:
			return
	_queue.append({"owner": owner, "callback": on_granted})
	_try_grant_next()

func release(owner: Node) -> void:
	_queue = _queue.filter(func(entry: Dictionary) -> bool: return entry.owner != owner)
	if owner != _current_owner:
		return
	_current_owner = null
	call_deferred("_try_grant_next")

func clear() -> void:
	_queue.clear()
	_current_owner = null
	get_tree().paused = false

func _try_grant_next() -> void:
	if is_instance_valid(_current_owner):
		return
	while not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		var owner := entry.owner as Node
		if not is_instance_valid(owner) or not owner.is_inside_tree():
			continue
		_current_owner = owner
		get_tree().paused = true
		owner.tree_exiting.connect(release.bind(owner), CONNECT_ONE_SHOT)
		(entry.callback as Callable).call()
		return
	get_tree().paused = false
