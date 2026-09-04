class_name InventoryState
extends RefCounted

var containers: Dictionary = {}
var pickups: Dictionary = {}
var revision: int = 0

func get_container(container_id: StringName):
	return containers.get(container_id)

func total_item_count(item_id: StringName) -> int:
	var total := 0
	for container in containers.values():
		total += container.get_amount(item_id)
	return total
