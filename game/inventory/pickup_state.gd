class_name PickupState
extends RefCounted

var pickup_id: StringName
var item_id: StringName
var amount: int
var position: Vector2
var claimed: bool = false
var container_id: StringName

func _init(next_id: StringName, next_item_id: StringName, next_amount: int, next_position: Vector2, next_container_id: StringName) -> void:
	pickup_id = next_id
	item_id = next_item_id
	amount = next_amount
	position = next_position
	container_id = next_container_id
