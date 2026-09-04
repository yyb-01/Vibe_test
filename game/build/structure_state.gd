class_name StructureState
extends RefCounted

enum Lifecycle { ACTIVE, REMOVED, DESTROYED }

var structure_id: StringName
var definition_id: StringName
var owner_id: StringName
var anchor_cell: Vector2i
var rotation: int = 0
var footprint_cells: Array = []
var connection_masks: Dictionary = {}
var lifecycle: Lifecycle = Lifecycle.ACTIVE

func _init(next_id: StringName, next_definition_id: StringName, next_owner_id: StringName, next_anchor: Vector2i, next_rotation: int, next_cells: Array) -> void:
	structure_id = next_id
	definition_id = next_definition_id
	owner_id = next_owner_id
	anchor_cell = next_anchor
	rotation = next_rotation
	footprint_cells = next_cells.duplicate()
