class_name CampaignState
extends RefCounted

const OperationStateClass = preload("res://game/operation/operation_state.gd")

var item_balances: Dictionary = {}
var permanent_resources: Dictionary = {}
var completed_operation_ids: Array = []
var failed_operation_ids: Array = []
var reward_choices: Dictionary = {}
var applied_outcome_keys: Dictionary = {}
var accessible_operation_ids: Array = [&"outpost"]
var unlocked_blueprint_ids: Array = [&"wall", &"gate", &"turret", &"storage"]
var content_revision: String = ""
var revision: int = 0

func commit(outcome, proposal) -> bool:
	if outcome == null or proposal == null or applied_outcome_keys.has(outcome.outcome_key):
		return false
	for item_id in proposal.preserved_items.keys():
		item_balances[item_id] = int(item_balances.get(item_id, 0)) + int(proposal.preserved_items[item_id])
	for resource_id in proposal.permanent_resources.keys():
		permanent_resources[resource_id] = int(permanent_resources.get(resource_id, 0)) + int(proposal.permanent_resources[resource_id])
	if outcome.end_reason == OperationStateClass.EndReason.COMPLETED:
		completed_operation_ids.append(outcome.operation_id)
	else:
		failed_operation_ids.append(outcome.operation_id)
	applied_outcome_keys[outcome.outcome_key] = true
	revision += 1
	return true
