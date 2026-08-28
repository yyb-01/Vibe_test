extends Node

const CELL_SIZE: int = 128

# Key: Vector2i (grid cell coordinates)
# Value: Array of Nodes (Zombies)
var grid: Dictionary = {}

func clear() -> void:
	grid.clear()

func insert(entity: Node2D) -> void:
	var cell := _get_cell(entity.global_position)
	if not grid.has(cell):
		grid[cell] = []
	grid[cell].append(entity)

func remove(entity: Node2D) -> void:
	var cell := _get_cell(entity.global_position)
	if grid.has(cell):
		grid[cell].erase(entity)

func update_entity(entity: Node2D, old_pos: Vector2, new_pos: Vector2) -> void:
	var old_cell := _get_cell(old_pos)
	var new_cell := _get_cell(new_pos)

	if old_cell != new_cell:
		if grid.has(old_cell):
			grid[old_cell].erase(entity)
		if not grid.has(new_cell):
			grid[new_cell] = []
		grid[new_cell].append(entity)

func get_nearby_entities(pos: Vector2) -> Array:
	var cell := _get_cell(pos)
	var nearby = []

	# Check current cell and 8 neighbors
	for x in range(-1, 2):
		for y in range(-1, 2):
			var check_cell = cell + Vector2i(x, y)
			if grid.has(check_cell):
				nearby.append_array(grid[check_cell])

	return nearby

func _get_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / CELL_SIZE)), int(floor(pos.y / CELL_SIZE)))
