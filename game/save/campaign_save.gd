class_name CampaignSave
extends RefCounted

const RewardChoiceClass = preload("res://game/settlement/reward_choice.gd")

static func capture(state) -> Dictionary:
	var choices: Array = []
	for choice in state.reward_choices.values():
		choices.append({
			"choice_id": String(choice.choice_id),
			"candidate_definition_ids": _strings(choice.candidate_definition_ids),
			"state": int(choice.state),
			"selected_definition_id": String(choice.selected_definition_id),
			"source_ledger_entry_id": String(choice.source_ledger_entry_id),
		})
	return {
		"item_balances": _int_dict(state.item_balances),
		"permanent_resources": _int_dict(state.permanent_resources),
		"completed_operation_ids": _strings(state.completed_operation_ids),
		"failed_operation_ids": _strings(state.failed_operation_ids),
		"accessible_operation_ids": _strings(state.accessible_operation_ids),
		"unlocked_blueprint_ids": _strings(state.unlocked_blueprint_ids),
		"applied_outcome_keys": _strings(state.applied_outcome_keys.keys()),
		"reward_choices": choices,
		"content_revision": state.content_revision,
		"revision": state.revision,
	}

static func restore(state, payload: Dictionary) -> bool:
	if state == null or not payload.has("item_balances") or not payload.has("applied_outcome_keys"):
		return false
	state.item_balances = _int_dict_from(payload.get("item_balances", {}))
	state.permanent_resources = _int_dict_from(payload.get("permanent_resources", {}))
	state.completed_operation_ids = _string_names(payload.get("completed_operation_ids", []))
	state.failed_operation_ids = _string_names(payload.get("failed_operation_ids", []))
	state.accessible_operation_ids = _string_names(payload.get("accessible_operation_ids", [&"outpost"]))
	state.unlocked_blueprint_ids = _string_names(payload.get("unlocked_blueprint_ids", [&"wall"]))
	state.applied_outcome_keys.clear()
	for key in payload.get("applied_outcome_keys", []):
		state.applied_outcome_keys[StringName(key)] = true
	state.reward_choices.clear()
	for value in payload.get("reward_choices", []):
		if typeof(value) != TYPE_DICTIONARY or String(value.get("choice_id", "")).is_empty():
			return false
		var choice = RewardChoiceClass.new(StringName(value.choice_id), _string_names(value.get("candidate_definition_ids", [])), StringName(value.get("source_ledger_entry_id", "")))
		choice.state = int(value.get("state", RewardChoiceClass.Lifecycle.OPEN))
		choice.selected_definition_id = StringName(value.get("selected_definition_id", ""))
		state.reward_choices[choice.choice_id] = choice
	state.content_revision = String(payload.get("content_revision", ""))
	state.revision = int(payload.get("revision", 0))
	return true

static func _int_dict(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		result[String(key)] = int(source[key])
	return result

static func _int_dict_from(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		result[StringName(key)] = int(source[key])
	return result

static func _strings(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(String(value))
	return result

static func _string_names(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(StringName(value))
	return result
