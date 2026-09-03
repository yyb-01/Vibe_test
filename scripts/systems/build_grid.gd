class_name BuildGrid
extends RefCounted

# res://scripts/systems/build_grid.gd
# Manages cell occupancy, reserved areas, and AStarGrid2D route validation per Section 0.2 & E.1

var region: Rect2i = Rect2i(-15, -15, 31, 31)
var astar: AStarGrid2D = AStarGrid2D.new()

var core_cells: Array[Vector2i] = []
var spawn_cells: Array[Vector2i] = []

var occupied_cells: Dictionary = {} # cell: Vector2i -> structure instance / occupant
var reserved_cells: Dictionary = {} # cell: Vector2i -> reason

func _init(p_region: Rect2i = Rect2i(-15, -15, 31, 31)) -> void:
	region = p_region
	_init_astar()

func _init_astar() -> void:
	astar.region = region
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	astar.update()

func setup(p_region: Rect2i, p_core_cells: Array = [], p_spawn_cells: Array = []) -> void:
	region = p_region
	core_cells.clear()
	for c in p_core_cells:
		core_cells.append(Vector2i(c))
	spawn_cells.clear()
	for s in p_spawn_cells:
		spawn_cells.append(Vector2i(s))
		
	_init_astar()
	
	# Mark reserved core cells
	for c in core_cells:
		reserved_cells[c] = &"core"
	for s in spawn_cells:
		reserved_cells[s] = &"spawn"

func is_in_bounds(cell: Vector2i) -> bool:
	return region.has_point(cell)

func is_occupied(cell: Vector2i) -> bool:
	return occupied_cells.has(cell)

func is_reserved(cell: Vector2i) -> bool:
	return reserved_cells.has(cell)

func set_cell_solid(cell: Vector2i, solid: bool) -> void:
	if is_in_bounds(cell):
		astar.set_point_solid(cell, solid)

func check_route_to_core(test_cells: Array = []) -> bool:
	if core_cells.is_empty() or spawn_cells.is_empty():
		return true
		
	# 1. Temporarily apply solid flags
	for item in test_cells:
		var cell: Vector2i = Vector2i(item)
		if cell in core_cells or cell in spawn_cells:
			return false
		if is_in_bounds(cell):
			astar.set_point_solid(cell, true)
			
	# 2. Check each spawn cell has a path to at least one core cell
	var all_reachable: bool = true
	for spawn in spawn_cells:
		var has_path_to_core: bool = false
		for core in core_cells:
			var path = astar.get_point_path(spawn, core)
			if path.size() > 0:
				has_path_to_core = true
				break
		if not has_path_to_core:
			all_reachable = false
			break
			
	# 3. Revert temporary solid flags
	for item in test_cells:
		var cell: Vector2i = Vector2i(item)
		if is_in_bounds(cell):
			var was_solid: bool = occupied_cells.has(cell)
			astar.set_point_solid(cell, was_solid)
			
	return all_reachable

func register_structure(structure: Node, cells: Array, blocks_nav: bool = true) -> void:
	for item in cells:
		var cell: Vector2i = Vector2i(item)
		occupied_cells[cell] = structure
		if blocks_nav and is_in_bounds(cell):
			astar.set_point_solid(cell, true)

func unregister_structure(structure: Node) -> Array[Vector2i]:
	var freed_cells: Array[Vector2i] = []
	var to_remove: Array[Vector2i] = []
	for cell in occupied_cells:
		if occupied_cells[cell] == structure:
			to_remove.append(cell)
			freed_cells.append(cell)
			if is_in_bounds(cell):
				astar.set_point_solid(cell, false)
				
	for cell in to_remove:
		occupied_cells.erase(cell)
	return freed_cells

func clear() -> void:
	occupied_cells.clear()
	reserved_cells.clear()
	core_cells.clear()
	spawn_cells.clear()
	_init_astar()
