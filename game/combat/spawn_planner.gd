class_name SpawnPlanner
extends RefCounted

const ACCEPTED: StringName = &"ACCEPTED"
const SPAWN_INVALID: StringName = &"SPAWN_INVALID"
const ROUTE_MISSING: StringName = &"ROUTE_MISSING"

static func plan(path_service, spawn_cell: Vector2i, target_cell: Vector2i) -> Dictionary:
	if path_service == null or not path_service.is_cell_walkable(spawn_cell) or not path_service.is_cell_walkable(target_cell):
		return {"accepted": false, "reason": SPAWN_INVALID, "path": []}
	var path: Array = path_service.find_path(spawn_cell, target_cell)
	if path.is_empty():
		return {"accepted": false, "reason": ROUTE_MISSING, "path": []}
	return {"accepted": true, "reason": ACCEPTED, "path": path}

static func plan_entries(path_service, spawn_entries: Array, target_cell: Vector2i) -> Dictionary:
	if path_service == null or spawn_entries.is_empty():
		return {"accepted": false, "reason": SPAWN_INVALID, "entries": []}
	var planned: Array = []
	var used_ids: Dictionary = {}
	for value in spawn_entries:
		if typeof(value) != TYPE_DICTIONARY:
			return {"accepted": false, "reason": SPAWN_INVALID, "entries": []}
		var entry: Dictionary = value
		var enemy_id := StringName(entry.get("id", ""))
		var definition_id := StringName(entry.get("definition_id", ""))
		var spawn_cell: Vector2i = entry.get("spawn_cell", Vector2i.ZERO)
		if String(enemy_id).is_empty() or String(definition_id).is_empty() or used_ids.has(enemy_id):
			return {"accepted": false, "reason": SPAWN_INVALID, "entries": []}
		var result := plan(path_service, spawn_cell, target_cell)
		if not bool(result.get("accepted", false)):
			return {"accepted": false, "reason": result.get("reason", ROUTE_MISSING), "entries": []}
		used_ids[enemy_id] = true
		planned.append({"id": enemy_id, "definition_id": definition_id, "spawn_cell": spawn_cell, "path": result.path.duplicate()})
	return {"accepted": true, "reason": ACCEPTED, "entries": planned}
