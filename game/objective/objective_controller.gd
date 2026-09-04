class_name ObjectiveController
extends Node

const ObjectiveStateClass = preload("res://game/objective/objective_state.gd")

signal objective_completed(objective_id: StringName)
signal extraction_eligibility_opened(objective_id: StringName)

var state
var operation_id: StringName
var enabled: bool = false

func setup(next_operation_id: StringName, objective_id: StringName, fact_type: StringName, item_id: StringName, amount: int, activated_tick: int = 0) -> bool:
	if String(next_operation_id).is_empty() or String(objective_id).is_empty() or fact_type != &"ITEM_SECURED" or amount <= 0:
		return false
	operation_id = next_operation_id
	state = ObjectiveStateClass.new()
	state.active_objective_id = objective_id
	state.objectives[objective_id] = {
		"objective_id": objective_id,
		"state": ObjectiveStateClass.Lifecycle.ACTIVE,
		"required_fact_type": fact_type,
		"item_id": item_id,
		"target_amount": amount,
		"progress": 0,
		"activated_tick": activated_tick,
		"resolved_tick": -1,
	}
	enabled = false
	return true

func set_enabled(next_enabled: bool) -> void:
	enabled = next_enabled

func accept_facts(facts: Array, current_tick: int = 0) -> void:
	if not enabled or state == null or String(state.active_objective_id).is_empty():
		return
	var objective: Dictionary = state.objectives.get(state.active_objective_id, {})
	if objective.is_empty() or objective.get("state", -1) != ObjectiveStateClass.Lifecycle.ACTIVE:
		return
	for fact in facts:
		if fact == null or fact.operation_id != operation_id or fact.fact_type != objective.get("required_fact_type", &""):
			continue
		var expected_item_id: StringName = objective.get("item_id", &"")
		if not String(expected_item_id).is_empty() and StringName(fact.payload.get("item_id", &"")) != expected_item_id:
			continue
		var fact_amount: int = int(fact.payload.get("amount", 1))
		if fact_amount <= 0:
			continue
		objective["progress"] = mini(int(objective.get("target_amount", 1)), int(objective.get("progress", 0)) + fact_amount)
		state.revision += 1
		if int(objective["progress"]) >= int(objective["target_amount"]):
			objective["state"] = ObjectiveStateClass.Lifecycle.COMPLETED
			objective["resolved_tick"] = current_tick
			state.completed_objective_ids.append(objective.get("objective_id", &""))
			state.active_objective_id = &""
			objective_completed.emit(objective.get("objective_id", &""))
			extraction_eligibility_opened.emit(objective.get("objective_id", &""))
		return
