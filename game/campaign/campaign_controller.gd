class_name CampaignController
extends Node

const ActionResultClass = preload("res://game/shared/action_result.gd")
const StartOperationActionClass = preload("res://game/campaign/start_operation_action.gd")
const ItemDefinitionClass = preload("res://game/content/definitions/item_definition.gd")
const StructureDefinitionClass = preload("res://game/content/definitions/structure_definition.gd")
const TerrainDefinitionClass = preload("res://game/content/definitions/terrain_definition.gd")
const OperationDefinitionClass = preload("res://game/content/definitions/operation_definition.gd")

var state
var catalog
var _processed_actions: Dictionary = {}

func setup(next_state, next_catalog) -> bool:
	if next_state == null or next_catalog == null:
		return false
	state = next_state
	catalog = next_catalog
	_processed_actions.clear()
	return true

func get_operation(operation_id: StringName):
	return catalog.get_definition(operation_id) if catalog != null else null

func start_operation(action_id: StringName, operation_id: StringName, loadout_item_ids: Array = [], blueprint_ids: Array = [], risk_id: StringName = &"standard", terrain_id: StringName = &""):
	var previous = _processed_actions.get(action_id) if _processed_actions.has(action_id) else null
	if previous != null:
		return previous
	var action = StartOperationActionClass.new(action_id, operation_id, loadout_item_ids, blueprint_ids, risk_id, terrain_id)
	if String(action.action_id).is_empty():
		return _reject(action.action_id, &"ACTION_INVALID")
	if state == null or catalog == null:
		return _reject(action.action_id, &"CAMPAIGN_NOT_READY")
	if not state.accessible_operation_ids.has(action.operation_id):
		return _reject(action.action_id, &"OPERATION_LOCKED")
	var operation = get_operation(action.operation_id)
	if operation == null or operation.get_script() != OperationDefinitionClass:
		return _reject(action.action_id, &"UNKNOWN_OPERATION")
	for item_id in action.loadout_item_ids:
		var item = catalog.get_definition(StringName(item_id))
		if item == null or item.get_script() != ItemDefinitionClass:
			return _reject(action.action_id, &"UNKNOWN_LOADOUT")
	for blueprint_id in action.blueprint_ids:
		if not state.unlocked_blueprint_ids.has(StringName(blueprint_id)):
			return _reject(action.action_id, &"BLUEPRINT_LOCKED")
		var blueprint = catalog.get_definition(StringName(blueprint_id))
		if blueprint == null or blueprint.get_script() != StructureDefinitionClass:
			return _reject(action.action_id, &"UNKNOWN_BLUEPRINT")
	if String(action.risk_id).is_empty():
		return _reject(action.action_id, &"RISK_INVALID")
	var selected_terrain_id := StringName(action.terrain_id)
	if String(selected_terrain_id).is_empty():
		selected_terrain_id = StringName(operation.terrain_id)
	var terrain = catalog.get_definition(selected_terrain_id)
	if terrain == null or terrain.get_script() != TerrainDefinitionClass:
		return _reject(action.action_id, &"UNKNOWN_TERRAIN")
	var result = ActionResultClass.accepted_result(action.action_id, state.revision)
	_processed_actions[action.action_id] = result
	return result

func _reject(action_id: StringName, reason: StringName):
	var result = ActionResultClass.rejected(action_id, reason, state.revision if state != null else 0)
	if not String(action_id).is_empty():
		_processed_actions[action_id] = result
	return result
