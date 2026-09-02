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
	item_cells.clear()
	_clustering_cells.clear()

func insert(entity: Node2D) -> void:
	if not is_instance_valid(entity) or entity.is_queued_for_deletion():
		return
	remove(entity)
	var cell := _get_cell(entity.global_position)
	if not grid.has(cell):
		grid[cell] = []
	grid[cell].append(entity)
	entity_cells[entity] = cell

func remove(entity: Node2D) -> void:
	if not entity_cells.has(entity):
		return
	var cell: Vector2i = entity_cells[entity]
	if grid.has(cell):
		grid[cell].erase(entity)
		if grid[cell].is_empty():
			grid.erase(cell)
	entity_cells.erase(entity)

func update_entity(entity: Node2D, old_pos: Vector2, new_pos: Vector2) -> void:
	if not is_instance_valid(entity) or entity.is_queued_for_deletion():
		return
	var old_cell: Vector2i = entity_cells.get(entity, _get_cell(old_pos))
	var new_cell := _get_cell(new_pos)

	if old_cell != new_cell:
		if grid.has(old_cell):
			grid[old_cell].erase(entity)
			if grid[old_cell].is_empty():
				grid.erase(old_cell)
		if not grid.has(new_cell):
			grid[new_cell] = []
		grid[new_cell].append(entity)
		entity_cells[entity] = new_cell
	elif not entity_cells.has(entity):
		insert(entity)

func get_nearby_entities(pos: Vector2, radius: float = CELL_SIZE) -> Array:
	var cell := _get_cell(pos)
	var nearby = []
	var cell_radius := maxi(1, ceili(maxf(radius, 0.0) / float(CELL_SIZE)))

	for x in range(-cell_radius, cell_radius + 1):
		for y in range(-cell_radius, cell_radius + 1):
			var check_cell = cell + Vector2i(x, y)
			if grid.has(check_cell):
				for entity in grid[check_cell]:
					if is_instance_valid(entity) and not entity.is_queued_for_deletion():
						nearby.append(entity)

	return nearby

func _get_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / CELL_SIZE)), int(floor(pos.y / CELL_SIZE)))

# Clustering logic for items
var item_grid: Dictionary = {}
var item_cells: Dictionary = {}
var _clustering_cells: Dictionary = {}

func insert_item(item: Node2D) -> void:
	if not is_instance_valid(item) or item.is_queued_for_deletion():
		return
	remove_item(item)
	var cell := _get_cell(item.global_position)
	if not item_grid.has(cell):
		item_grid[cell] = []
	item_grid[cell].append(item)
	item_cells[item] = cell

	_check_cluster(cell)

func remove_item(item: Node2D) -> void:
	if not item_cells.has(item):
		return
	var cell: Vector2i = item_cells[item]
	if item_grid.has(cell):
		item_grid[cell].erase(item)
		if item_grid[cell].is_empty():
			item_grid.erase(cell)
	item_cells.erase(item)

func _check_cluster(cell: Vector2i) -> void:
	if not item_grid.has(cell) or _clustering_cells.has(cell): return
	var cell_items = item_grid[cell]

	var exp_gems = []
	for item in cell_items:
		if is_instance_valid(item) and item.has_method("get_exp_amount"):
			exp_gems.append(item)

	if exp_gems.size() > 20:
		_clustering_cells[cell] = true
		var total_exp := 0
		var pos = exp_gems[0].global_position
		var new_gem = ObjectPoolManager.acquire("exp_gem", pos)
		if not new_gem:
			_clustering_cells.erase(cell)
			return
		for gem in exp_gems:
			total_exp += maxi(0, int(gem.get_exp_amount()))
			remove_item(gem)
			ObjectPoolManager.release(gem)

		new_gem.set_exp_amount(total_exp)
		_clustering_cells.erase(cell)
