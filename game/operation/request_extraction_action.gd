class_name RequestExtractionAction
extends RefCounted

var action_id: StringName

func _init(next_action_id: StringName) -> void:
	action_id = next_action_id
