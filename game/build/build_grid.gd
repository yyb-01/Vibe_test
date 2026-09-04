class_name BuildGrid
extends RefCounted

const CELL_SIZE: float = 32.0
const SOLID: StringName = &"SOLID"

var map_size: Vector2
var cells: Dictionary = {}
var revision: int = 0
var navigation_revision: int = 0
var navigation := AStarGrid2D.new()
var _min_cell: Vector2i
var _grid_size: Vector2i

func _init(next_map_size: Vector2 = Vector2.ZERO) -> void:
	if next_map_size != Vector2.ZERO:
		configure(next_map_size)

func configure(next_map_size: Vector2) -> void:
	map_size = next_map_size
	_grid_size = Vector2i(int(ceil(map_size.x / CELL_SIZE)), int(ceil(map_size.y / CELL_SIZE)))
	_min_cell = Vector2i(-_grid_size.x / 2, -_grid_size.y / 2)
	cells.clear()
	revision = 0
	navigation_revision = 0
	navigation.region = Rect2i(_min_cell, _grid_size)
	navigation.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()

func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(int(floor(position.x / CELL_SIZE + 0.5)), int(floor(position.y / CELL_SIZE + 0.5)))

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_SIZE

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= _min_cell.x and cell.x < _min_cell.x + _grid_size.x and cell.y >= _min_cell.y and cell.y < _min_cell.y + _grid_size.y

func get_occupant(cell: Vector2i, channel: StringName = SOLID):
	var value = cells.get(cell)
	return value.get("occupants_by_channel", {}).get(channel, &"") if value != null else &""

func is_reserved(cell: Vector2i) -> bool:
	var value = cells.get(cell)
	return value != null and not String(value.get("reservation_id", &"")).is_empty()

func can_reserve(footprint_cells: Array, channel: StringName = SOLID) -> bool:
	for cell in footprint_cells:
		if not is_in_bounds(cell) or is_reserved(cell) or not String(get_occupant(cell, channel)).is_empty():
			return false
	return true

func reserve_cells(reservation_id: StringName, footprint_cells: Array) -> bool:
	if String(reservation_id).is_empty() or not can_reserve(footprint_cells):
		return false
	for cell_id in footprint_cells:
		_ensure_cell(cell_id)["reservation_id"] = reservation_id
	revision += 1
	return true

func commit_structure(structure_id: StringName, footprint_cells: Array, definition, reservation_id: StringName) -> bool:
	for cell_id in footprint_cells:
		var cell = cells.get(cell_id)
		if cell == null or cell.get("reservation_id", &"") != reservation_id:
			return false
	var navigation_changed := false
	for cell_id in footprint_cells:
		var cell = _ensure_cell(cell_id)
		for channel in definition.occupied_channels:
			cell["occupants_by_channel"][channel] = structure_id
			cell["connection_groups"][channel] = definition.connection_group
			cell["compatible_groups"][channel] = definition.compatible_groups.duplicate()
			if StringName(channel) == SOLID:
				navigation_changed = true
		cell["blocked_for_player"] = definition.blocks_player
		cell["blocked_for_enemy"] = definition.blocks_enemy
		cell["reservation_id"] = &""
	revision += 1
	if navigation_changed:
		navigation_revision += 1
		_sync_navigation()
	return true

func seed_structure(structure_id: StringName, footprint_cells: Array, channels: Array, connection_group: StringName, compatible_groups: Array) -> void:
	var navigation_changed := false
	for cell_id in footprint_cells:
		var cell = _ensure_cell(cell_id)
		for channel in channels:
			cell["occupants_by_channel"][channel] = structure_id
			cell["connection_groups"][channel] = connection_group
			cell["compatible_groups"][channel] = compatible_groups.duplicate()
			if StringName(channel) == SOLID:
				navigation_changed = true
		revision += 1
	if navigation_changed:
		navigation_revision += 1
		_sync_navigation()

func remove_structure(structure_id: StringName, footprint_cells: Array, channels: Array) -> bool:
	var changed := false
	var navigation_changed := false
	for cell_id in footprint_cells:
		var cell = cells.get(cell_id)
		if cell == null:
			continue
		for channel in channels:
			if cell["occupants_by_channel"].get(channel, &"") != structure_id:
				continue
			cell["occupants_by_channel"].erase(channel)
			cell["connection_groups"].erase(channel)
			cell["compatible_groups"].erase(channel)
			changed = true
			if StringName(channel) == SOLID:
				navigation_changed = true
		if cell["occupants_by_channel"].is_empty() and String(cell.get("reservation_id", &"")).is_empty():
			cells.erase(cell_id)
	if not changed:
		return false
	revision += 1
	if navigation_changed:
		navigation_revision += 1
		_sync_navigation()
	return true

func get_connection_mask(cell_id: Vector2i, channel: StringName = SOLID) -> int:
	var cell = cells.get(cell_id)
	if cell == null or String(cell["occupants_by_channel"].get(channel, &"")).is_empty():
		return 0
	var group: StringName = cell["connection_groups"].get(channel, &"")
	var compatible: Array = cell["compatible_groups"].get(channel, [])
	var directions := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var bits := [1, 2, 4, 8]
	var mask := 0
	for index in range(directions.size()):
		var neighbor = cells.get(cell_id + directions[index])
		if neighbor == null:
			continue
		var neighbor_group: StringName = neighbor["connection_groups"].get(channel, &"")
		var neighbor_compatible: Array = neighbor["compatible_groups"].get(channel, [])
		if not String(neighbor_group).is_empty() and compatible.has(neighbor_group) and neighbor_compatible.has(group):
			mask |= bits[index]
	return mask

func has_path(start: Vector2i, target: Vector2i) -> bool:
	return not get_id_path(start, target).is_empty()

func get_id_path(start: Vector2i, target: Vector2i) -> Array:
	if not is_in_bounds(start) or not is_in_bounds(target):
		return []
	return navigation.get_id_path(start, target)

func rebuild_navigation() -> void:
	_sync_navigation()

func _ensure_cell(cell_id: Vector2i) -> Dictionary:
	if not cells.has(cell_id):
		cells[cell_id] = {"occupants_by_channel": {}, "connection_groups": {}, "compatible_groups": {}, "reservation_id": &"", "blocked_for_player": false, "blocked_for_enemy": false}
	return cells[cell_id]

func _sync_navigation() -> void:
	navigation.update()
	for cell_id in cells.keys():
		if not String(cells[cell_id]["occupants_by_channel"].get(SOLID, &"")).is_empty():
			navigation.set_point_solid(cell_id, true)
