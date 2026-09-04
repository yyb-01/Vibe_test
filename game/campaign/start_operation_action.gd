class_name StartOperationAction
extends RefCounted

var action_id: StringName
var operation_id: StringName
var loadout_item_ids: Array = []
var blueprint_ids: Array = []
var risk_id: StringName
var terrain_id: StringName

func _init(next_action_id: StringName, next_operation_id: StringName, next_loadout: Array, next_blueprints: Array, next_risk_id: StringName, next_terrain_id: StringName = &"") -> void:
	action_id = next_action_id
	operation_id = next_operation_id
	loadout_item_ids = next_loadout.duplicate()
	blueprint_ids = next_blueprints.duplicate()
	risk_id = next_risk_id
	terrain_id = next_terrain_id
