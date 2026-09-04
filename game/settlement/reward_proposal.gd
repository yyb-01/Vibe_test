class_name RewardProposal
extends RefCounted

var outcome_key: StringName
var success: bool
var preserved_items: Dictionary = {}
var lost_items: Dictionary = {}
var permanent_resources: Dictionary = {}
var candidate_definition_ids: Array = []
var policy_revision: int = 1

func _init(next_outcome_key: StringName, next_success: bool, next_preserved_items: Dictionary, next_lost_items: Dictionary, next_permanent_resources: Dictionary, next_candidates: Array) -> void:
	outcome_key = next_outcome_key
	success = next_success
	preserved_items = next_preserved_items.duplicate()
	lost_items = next_lost_items.duplicate()
	permanent_resources = next_permanent_resources.duplicate()
	candidate_definition_ids = next_candidates.duplicate()
