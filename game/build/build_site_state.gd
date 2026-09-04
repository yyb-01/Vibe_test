class_name BuildSiteState
extends RefCounted

enum Lifecycle { RESERVED, CONSTRUCTING, COMPLETED, CANCELLED, DESTROYED }

var build_site_id: StringName
var entity_id: StringName
var definition_id: StringName
var owner_id: StringName
var anchor_cell: Vector2i
var rotation: int = 0
var footprint_cells: Array = []
var reserved_items: Dictionary = {}
var committed_items: Dictionary = {}
var work_progress: int = 0
var lifecycle: Lifecycle = Lifecycle.RESERVED

func _init(next_id: StringName, next_entity_id: StringName, next_definition_id: StringName, next_owner_id: StringName, next_anchor: Vector2i, next_rotation: int, next_cells: Array) -> void:
	build_site_id = next_id
	entity_id = next_entity_id
	definition_id = next_definition_id
	owner_id = next_owner_id
	anchor_cell = next_anchor
	rotation = next_rotation
	footprint_cells = next_cells.duplicate()
