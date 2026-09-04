class_name BuildRules
extends RefCounted

const ACCEPTED: StringName = &"ACCEPTED"
const WRONG_OPERATION_STATE: StringName = &"WRONG_OPERATION_STATE"
const ACTOR_NOT_AVAILABLE: StringName = &"ACTOR_NOT_AVAILABLE"
const UNKNOWN_DEFINITION: StringName = &"UNKNOWN_DEFINITION"
const OUT_OF_BOUNDS: StringName = &"OUT_OF_BOUNDS"
const OCCUPIED: StringName = &"OCCUPIED"
const RESERVED: StringName = &"RESERVED"
const NOT_ENOUGH_RESOURCE: StringName = &"NOT_ENOUGH_RESOURCE"

static func plan(definition, grid, inventory, actor_id: StringName, anchor_cell: Vector2i, rotation: int, expected_grid_revision: int = -1) -> Dictionary:
	if definition == null:
		return _result(false, UNKNOWN_DEFINITION, [], [], grid.revision if grid != null else 0)
	if actor_id != &"player":
		return _result(false, ACTOR_NOT_AVAILABLE, [], [], grid.revision)
	if grid == null or inventory == null:
		return _result(false, WRONG_OPERATION_STATE, [], [], 0)
	if expected_grid_revision >= 0 and grid.revision != expected_grid_revision:
		return _result(false, &"STALE_PREVIEW", [], [], grid.revision)
	var footprint := compute_footprint(definition, anchor_cell, rotation)
	var rejected_cells: Array = []
	var reason: StringName = ACCEPTED
	for cell_id in footprint:
		var cell_reason: StringName = ACCEPTED
		if not grid.is_in_bounds(cell_id):
			cell_reason = OUT_OF_BOUNDS
		elif grid.is_reserved(cell_id):
			cell_reason = RESERVED
		else:
			for channel in definition.occupied_channels:
				if not String(grid.get_occupant(cell_id, channel)).is_empty():
					cell_reason = OCCUPIED
					break
		if cell_reason != ACCEPTED:
			rejected_cells.append(cell_id)
			if reason == ACCEPTED:
				reason = cell_reason
	if reason == ACCEPTED and inventory.get_available_amount(&"player_pack", definition.cost_item_id) < definition.cost_amount:
		reason = NOT_ENOUGH_RESOURCE
	return _result(reason == ACCEPTED, reason, footprint, rejected_cells, grid.revision, definition.cost_item_id, definition.cost_amount)

static func compute_footprint(definition, anchor_cell: Vector2i, rotation: int) -> Array:
	var cells: Array = []
	for relative_value in definition.footprint:
		var relative := Vector2i(relative_value)
		var rotated := _rotate(relative, rotation)
		var absolute := anchor_cell + rotated
		if not cells.has(absolute):
			cells.append(absolute)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return cells

static func _rotate(cell: Vector2i, rotation: int) -> Vector2i:
	var switch_rotation := posmod(rotation, 4)
	match switch_rotation:
		1:
			return Vector2i(-cell.y, cell.x)
		2:
			return Vector2i(-cell.x, -cell.y)
		3:
			return Vector2i(cell.y, -cell.x)
	return cell

static func _result(valid: bool, reason: StringName, footprint: Array, rejected_cells: Array, revision: int, cost_item_id: StringName = &"", cost_amount: int = 0) -> Dictionary:
	return {"accepted": valid, "reason": reason, "footprint_cells": footprint, "rejected_cells": rejected_cells, "grid_revision": revision, "cost_item_id": cost_item_id, "cost_amount": cost_amount}
