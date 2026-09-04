class_name ActionResult
extends RefCounted

var accepted: bool = false
var action_id: StringName
var reason_code: StringName
var changed_revision: int = 0
var facts: Array = []

static func accepted_result(next_action_id: StringName, revision: int, next_facts: Array = []):
	var result = ActionResult.new()
	result.accepted = true
	result.action_id = next_action_id
	result.reason_code = &"ACCEPTED"
	result.changed_revision = revision
	result.facts = next_facts.duplicate()
	return result

static func rejected(next_action_id: StringName, code: StringName, revision: int):
	var result = ActionResult.new()
	result.action_id = next_action_id
	result.reason_code = code
	result.changed_revision = revision
	return result
