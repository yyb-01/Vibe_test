extends Node

const CELL_SIZE: int = 128

# Key: Vector2i (grid cell coordinates)
# Value: Array of Nodes (Zombies)
var grid: Dictionary = {}
var entity_cells: Dictionary = {}

func clear() -> void:
	grid.clear()
	entity_cells.clear()
	item_grid.clear()
	_clustering_cells.clear()

func insert(entity: Node2D) -> void:
	remove(entity)
	var cell := _get_cell(entity.global_position)
	if not grid.has(cell):
		grid[cell] = []
	grid[cell].append(entity)
	entity_cells[entity] = cell

func remove(entity: Node2D) -> void:
	var cell: Vector2i = entity_cells.get(entity, _get_cell(entity.global_position))
	if grid.has(cell):
		grid[cell].erase(entity)
	entity_cells.erase(entity)

func update_entity(entity: Node2D, old_pos: Vector2, new_pos: Vector2) -> void:
	var old_cell: Vector2i = entity_cells.get(entity, _get_cell(old_pos))
	var new_cell := _get_cell(new_pos)

	if old_cell != new_cell:
		if grid.has(old_cell):
			grid[old_cell].erase(entity)
		if not grid.has(new_cell):
			grid[new_cell] = []
		grid[new_cell].append(entity)
		entity_cells[entity] = new_cell

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

# Clustering logic for items
var item_grid: Dictionary = {}
var _clustering_cells: Dictionary = {}

func insert_item(item: Node2D) -> void:
	remove_item(item)
	var cell := _get_cell(item.global_position)
	if not item_grid.has(cell):
		item_grid[cell] = []
	item_grid[cell].append(item)

	_check_cluster(cell)

func remove_item(item: Node2D) -> void:
	for cell in item_grid.keys():
		item_grid[cell].erase(item)

func _check_cluster(cell: Vector2i) -> void:
	if not item_grid.has(cell) or _clustering_cells.has(cell): return
	var cell_items = item_grid[cell]

	var exp_gems = []
	for item in cell_items:
		if is_instance_valid(item) and item.has_method("get_exp_amount"):
			exp_gems.append(item)

	if exp_gems.size() > 20:
		_clustering_cells[cell] = true
		var total_exp = 0
		var pos = exp_gems[0].global_position
		for gem in exp_gems:
			total_exp += gem.get_exp_amount()
			item_grid[cell].erase(gem)
			ObjectPoolManager.release(gem)

		var new_gem = ObjectPoolManager.acquire("exp_gem", pos)
		if new_gem:
			new_gem.set_exp_amount(total_exp)
		_clustering_cells.erase(cell)
