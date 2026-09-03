class_name BuildGridState
extends RefCounted

# res://scripts/simulation/model/build_grid_state.gd
# Pure data representation of authoritative grid occupancy and structure footprints.

var region: Rect2i = Rect2i(-15, -15, 31, 31)
var core_cells: Array[Vector2i] = []
var spawn_cells: Array[Vector2i] = []
var grid_revision: int = 0

var occupied_cells: Dictionary = {} # Vector2i -> entity_id: int
var structures: Dictionary = {}     # entity_id: int -> Dictionary

func is_cell_valid(cell: Vector2i) -> bool:
	return region.has_point(cell)

func is_cell_occupied(cell: Vector2i) -> bool:
	return occupied_cells.has(cell) or cell in core_cells or cell in spawn_cells

func can_place_footprint(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if not is_cell_valid(cell) or is_cell_occupied(cell):
			return false
	return true

func occupy(entity_id: int, structure_def_id: StringName, anchor: Vector2i, rot: int, cells: Array[Vector2i]) -> void:
	for cell in cells:
		occupied_cells[cell] = entity_id
	structures[entity_id] = {
		"definition_id": str(structure_def_id),
		"anchor_cell": [anchor.x, anchor.y],
		"rotation_quarters": rot,
		"cells": cells.duplicate()
	}
	grid_revision += 1

func vacate(entity_id: int) -> Array[Vector2i]:
	if not structures.has(entity_id):
		return []
	var info: Dictionary = structures[entity_id]
	var cells: Array = info.get("cells", [])
	var vacated_cells: Array[Vector2i] = []
	for c in cells:
		var cell: Vector2i = c if c is Vector2i else Vector2i(c[0], c[1])
		occupied_cells.erase(cell)
		vacated_cells.append(cell)
	structures.erase(entity_id)
	grid_revision += 1
	return vacated_cells

func to_dict() -> Dictionary:
	var structs_dict: Dictionary = {}
	for s_id in structures:
		structs_dict[str(s_id)] = structures[s_id].duplicate(true)

	var core_arr: Array = []
	for c in core_cells:
		core_arr.append([c.x, c.y])

	var spawn_arr: Array = []
	for s in spawn_cells:
		spawn_arr.append([s.x, s.y])

	return {
		"region": [region.position.x, region.position.y, region.size.x, region.size.y],
		"grid_revision": grid_revision,
		"core_cells": core_arr,
		"spawn_cells": spawn_arr,
		"structures": structs_dict
	}

func from_dict(d: Dictionary) -> void:
	if not (d is Dictionary):
		return
	grid_revision = int(d.get("grid_revision", 0))
	var reg_arr = d.get("region", [-15, -15, 31, 31])
	if reg_arr is Array and reg_arr.size() >= 4:
		region = Rect2i(int(reg_arr[0]), int(reg_arr[1]), int(reg_arr[2]), int(reg_arr[3]))

	core_cells = []
	var raw_core = d.get("core_cells", [])
	if raw_core is Array:
		for c in raw_core:
			if c is Array and c.size() >= 2:
				core_cells.append(Vector2i(int(c[0]), int(c[1])))

	spawn_cells = []
	var raw_spawn = d.get("spawn_cells", [])
	if raw_spawn is Array:
		for s in raw_spawn:
			if s is Array and s.size() >= 2:
				spawn_cells.append(Vector2i(int(s[0]), int(s[1])))

	occupied_cells.clear()
	structures.clear()
	var raw_structs = d.get("structures", {})
	if raw_structs is Dictionary:
		for id_str in raw_structs:
			var s_id: int = int(id_str)
			var info: Dictionary = raw_structs[id_str]
			structures[s_id] = info.duplicate(true)
			var cells = info.get("cells", [])
			if cells is Array:
				for c in cells:
					var cell: Vector2i = c if c is Vector2i else Vector2i(c[0], c[1])
					occupied_cells[cell] = s_id
