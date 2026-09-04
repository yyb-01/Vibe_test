class_name RewardPolicy
extends RefCounted

const OperationStateClass = preload("res://game/operation/operation_state.gd")
const RewardProposalClass = preload("res://game/settlement/reward_proposal.gd")

func build(outcome):
	if outcome == null or not outcome.sealed:
		return null
	var success: bool = outcome.end_reason == OperationStateClass.EndReason.COMPLETED
	var preserved: Dictionary = {}
	var lost: Dictionary = {}
	_merge_items(outcome.secured_items, preserved)
	if success:
		_merge_items(outcome.carried_items, preserved)
	else:
		_merge_items(outcome.carried_items, lost)
	var permanent_resources: Dictionary = {}
	permanent_resources[&"operations_completed" if success else &"operations_failed"] = 1
	return RewardProposalClass.new(outcome.outcome_key, success, preserved, lost, permanent_resources, [])

func _merge_items(source: Dictionary, target: Dictionary) -> void:
	for item_id in source.keys():
		target[item_id] = int(target.get(item_id, 0)) + int(source[item_id])
