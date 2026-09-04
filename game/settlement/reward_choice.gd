class_name RewardChoice
extends RefCounted

enum Lifecycle { OPEN, SELECTED }

var choice_id: StringName
var candidate_definition_ids: Array = []
var state: Lifecycle = Lifecycle.OPEN
var selected_definition_id: StringName = &""
var source_ledger_entry_id: StringName = &""

func _init(next_choice_id: StringName, next_candidates: Array, next_source_ledger_entry_id: StringName) -> void:
	choice_id = next_choice_id
	candidate_definition_ids = next_candidates.duplicate()
	source_ledger_entry_id = next_source_ledger_entry_id

func select(definition_id: StringName) -> bool:
	if state != Lifecycle.OPEN or not candidate_definition_ids.has(definition_id):
		return false
	selected_definition_id = definition_id
	state = Lifecycle.SELECTED
	return true
