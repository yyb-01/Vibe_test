class_name SettlementService
extends RefCounted

const RewardChoiceClass = preload("res://game/settlement/reward_choice.gd")
const RewardLedgerClass = preload("res://game/settlement/reward_ledger.gd")
const RewardPolicyClass = preload("res://game/settlement/reward_policy.gd")

var campaign_state
var policy
var ledger
var proposals: Dictionary = {}

func setup(next_campaign_state, content_revision: String) -> bool:
	if next_campaign_state == null or String(content_revision).is_empty():
		return false
	campaign_state = next_campaign_state
	campaign_state.content_revision = content_revision
	policy = RewardPolicyClass.new()
	ledger = RewardLedgerClass.new()
	proposals.clear()
	return true

func settle(outcome) -> Dictionary:
	if outcome == null or campaign_state == null or policy == null or ledger == null:
		return {"accepted": false, "reason": &"SETTLEMENT_NOT_READY"}
	if ledger.has_outcome(outcome.outcome_key):
		return {"accepted": true, "duplicate": true, "outcome_key": outcome.outcome_key, "entry_ids": ledger.get_entries(outcome.outcome_key), "proposal": proposals.get(outcome.outcome_key)}
	var proposal = policy.build(outcome)
	if proposal == null:
		return {"accepted": false, "reason": &"OUTCOME_INVALID"}
	var entry_ids: Array = ledger.create_entries(outcome, proposal)
	if not campaign_state.commit(outcome, proposal) or not ledger.mark_applied(outcome.outcome_key):
		return {"accepted": false, "reason": &"SETTLEMENT_COMMIT_FAILED"}
	proposals[outcome.outcome_key] = proposal
	if not proposal.candidate_definition_ids.is_empty():
		var choice_id := StringName("choice_%s" % String(outcome.outcome_key))
		campaign_state.reward_choices[choice_id] = RewardChoiceClass.new(choice_id, proposal.candidate_definition_ids, StringName(entry_ids[0]))
	return {"accepted": true, "duplicate": false, "outcome_key": outcome.outcome_key, "entry_ids": entry_ids, "proposal": proposal}

func select_reward(choice_id: StringName, definition_id: StringName) -> bool:
	var choice = campaign_state.reward_choices.get(choice_id) if campaign_state != null else null
	if choice == null or not choice.select(definition_id):
		return false
	return ledger.mark_chosen(choice.source_ledger_entry_id)
