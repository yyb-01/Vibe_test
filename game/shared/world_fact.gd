class_name WorldFact
extends RefCounted

var fact_id: StringName
var fact_type: StringName
var operation_id: StringName
var payload: Dictionary = {}

func _init(next_fact_id: StringName, next_fact_type: StringName, next_operation_id: StringName, next_payload: Dictionary = {}) -> void:
	fact_id = next_fact_id
	fact_type = next_fact_type
	operation_id = next_operation_id
	payload = next_payload.duplicate(true)
