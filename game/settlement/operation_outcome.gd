class_name OperationOutcome
extends RefCounted

const OperationOutcomeClass = preload("res://game/settlement/operation_outcome.gd")

var outcome_key: StringName
var operation_id: StringName
var definition_id: StringName
var end_reason: int
var completed_objectives: Array = []
var secured_items: Dictionary = {}
var carried_items: Dictionary = {}
var discoveries: Array = []
var challenge_results: Dictionary = {}
var casualties: Array = []
var content_revision: String = ""
var sealed: bool = false

func _init(next_operation_id: StringName, next_definition_id: StringName, next_end_reason: int, next_content_revision: String) -> void:
	operation_id = next_operation_id
	definition_id = next_definition_id
	end_reason = next_end_reason
	content_revision = next_content_revision
	outcome_key = StringName("outcome_%s" % String(operation_id))

static func from_runtime(operation_state, inventory_state, objective_state, combat_state, next_content_revision: String):
	var outcome = OperationOutcomeClass.new(operation_state.operation_id, operation_state.definition_id, operation_state.end_reason, next_content_revision)
	if objective_state != null:
		outcome.completed_objectives = objective_state.completed_objective_ids.duplicate()
	if inventory_state != null:
		outcome.secured_items = _items_in(inventory_state.containers.get(&"core_storage"))
		outcome.carried_items = _items_in(inventory_state.containers.get(&"player_pack"))
	if combat_state != null:
		outcome.casualties = combat_state.defeated_entities.keys().duplicate()
	outcome.sealed = true
	return outcome

static func _items_in(container) -> Dictionary:
	var items: Dictionary = {}
	if container == null:
		return items
	for item_id in container.item_stacks.keys():
		var amount: int = int(container.item_stacks[item_id])
		if amount > 0:
			items[StringName(item_id)] = amount
	return items
