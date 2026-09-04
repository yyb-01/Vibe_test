class_name ContainerState
extends RefCounted

var container_id: StringName
var owner_id: StringName
var capacity: int
var item_stacks: Dictionary = {}
var reservations: Dictionary = {}
var revision: int = 0

func _init(next_id: StringName, next_owner_id: StringName, next_capacity: int) -> void:
	container_id = next_id
	owner_id = next_owner_id
	capacity = next_capacity

func total_items() -> int:
	var total := 0
	for amount in item_stacks.values():
		total += int(amount)
	return total

func get_amount(item_id: StringName) -> int:
	return int(item_stacks.get(item_id, 0))

func reserved_amount(item_id: StringName) -> int:
	var total := 0
	for reservation in reservations.values():
		if StringName(reservation.get("item_id", &"")) == item_id:
			total += int(reservation.get("amount", 0))
	return total

func available_amount(item_id: StringName) -> int:
	return maxi(0, get_amount(item_id) - reserved_amount(item_id))
