class_name RewardLedger
extends RefCounted

enum EntryState { PENDING, APPLIED, CHOSEN, REVOKED }

var entries: Dictionary = {}
var entries_by_outcome: Dictionary = {}
var revision: int = 0

func has_outcome(outcome_key: StringName) -> bool:
	return entries_by_outcome.has(outcome_key)

func create_entries(outcome, proposal) -> Array:
	if outcome == null or proposal == null or has_outcome(outcome.outcome_key):
		return []
	var entry_ids: Array = []
	for definition_id in proposal.preserved_items.keys():
		_add_entry(entry_ids, outcome, &"ITEM", StringName(definition_id), int(proposal.preserved_items[definition_id]), proposal.policy_revision)
	for resource_id in proposal.permanent_resources.keys():
		_add_entry(entry_ids, outcome, &"RESOURCE", StringName(resource_id), int(proposal.permanent_resources[resource_id]), proposal.policy_revision)
	if entry_ids.is_empty():
		_add_entry(entry_ids, outcome, &"OPERATION_RESULT", &"", 1, proposal.policy_revision)
	entries_by_outcome[outcome.outcome_key] = entry_ids
	revision += 1
	return entry_ids

func mark_applied(outcome_key: StringName) -> bool:
	var entry_ids: Array = entries_by_outcome.get(outcome_key, [])
	if entry_ids.is_empty():
		return false
	for entry_id in entry_ids:
		var entry: Dictionary = entries.get(entry_id, {})
		if entry.is_empty():
			return false
		if entry.get("state") == EntryState.PENDING:
			entry["state"] = EntryState.APPLIED
	revision += 1
	return true

func mark_chosen(entry_id: StringName) -> bool:
	var entry: Dictionary = entries.get(entry_id, {})
	if entry.is_empty() or entry.get("state") != EntryState.APPLIED:
		return false
	entry["state"] = EntryState.CHOSEN
	revision += 1
	return true

func get_entries(outcome_key: StringName) -> Array:
	return entries_by_outcome.get(outcome_key, []).duplicate()

func _add_entry(entry_ids: Array, outcome, reward_type: StringName, definition_id: StringName, value: int, policy_revision: int) -> void:
	if value <= 0:
		return
	var entry_id := StringName("%s:%s:%s:%s" % [String(outcome.operation_id), String(outcome.outcome_key), String(reward_type), String(definition_id)])
	entries[entry_id] = {
		"ledger_entry_id": entry_id,
		"operation_id": outcome.operation_id,
		"source_outcome_key": outcome.outcome_key,
		"reward_type": reward_type,
		"definition_id": definition_id,
		"value": value,
		"policy_revision": policy_revision,
		"state": EntryState.PENDING,
	}
	entry_ids.append(entry_id)
