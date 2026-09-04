class_name PathService
extends RefCounted

var grid

func _init(next_grid = null) -> void:
	grid = next_grid

func is_cell_walkable(cell: Vector2i) -> bool:
	return grid != null and grid.is_in_bounds(cell) and String(grid.get_occupant(cell)).is_empty()

func has_route(start: Vector2i, target: Vector2i) -> bool:
	return not find_path(start, target).is_empty()

func find_path(start: Vector2i, target: Vector2i) -> Array:
	return grid.get_id_path(start, target) if grid != null else []

func navigation_revision() -> int:
	return grid.navigation_revision if grid != null else -1
