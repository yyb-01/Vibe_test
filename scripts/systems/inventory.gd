class_name Inventory
extends RefCounted

# res://scripts/systems/inventory.gd
# Slot-based inventory with stack limits per Section D.4 and Phase 2 requirements

signal contents_changed()

var max_slots: int = 8
var slots: Array[Dictionary] = [] # Elements: {"item_id": StringName, "amount": int}

func _init(p_max_slots: int = 8) -> void:
	max_slots = p_max_slots
	slots = []

func get_slot_count() -> int:
	return slots.size()

func is_full() -> bool:
	return slots.size() >= max_slots

func get_item_count(item_id: StringName) -> int:
	var total: int = 0
	for slot in slots:
		if slot.get("item_id", &"") == item_id:
			total += int(slot.get("amount", 0))
	return total

func can_add(item_id: StringName, amount: int, max_stack: int = 50) -> bool:
	if amount <= 0:
		return true
	var remaining: int = amount
	# Check existing slots
	for slot in slots:
		if slot.get("item_id", &"") == item_id:
			var space: int = max_stack - int(slot.get("amount", 0))
			if space > 0:
				remaining -= space
				if remaining <= 0:
					return true
	# Check free slot capacity
	var empty_slots_available: int = max_slots - slots.size()
	var needed_slots: int = int(ceil(float(remaining) / float(max_stack)))
	return needed_slots <= empty_slots_available

func add_item(item_id: StringName, amount: int, max_stack: int = 50) -> int:
	if amount <= 0:
		return 0
	var remaining: int = amount
	
	# 1. Fill existing matching slots
	for slot in slots:
		if slot.get("item_id", &"") == item_id:
			var current: int = int(slot.get("amount", 0))
			var space: int = max_stack - current
			if space > 0:
				var to_add: int = mini(space, remaining)
				slot["amount"] = current + to_add
				remaining -= to_add
				if remaining == 0:
					contents_changed.emit()
					return amount
					
	# 2. Add into new slots if available
	while remaining > 0 and slots.size() < max_slots:
		var to_add: int = mini(max_stack, remaining)
		slots.append({
			"item_id": item_id,
			"amount": to_add
		})
		remaining -= to_add
		
	var added: int = amount - remaining
	if added > 0:
		contents_changed.emit()
	return added

func remove_item(item_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	if get_item_count(item_id) < amount:
		return false
		
	var remaining_to_remove: int = amount
	var i: int = slots.size() - 1
	while i >= 0 and remaining_to_remove > 0:
		var slot: Dictionary = slots[i]
		if slot.get("item_id", &"") == item_id:
			var count: int = int(slot.get("amount", 0))
			if count <= remaining_to_remove:
				remaining_to_remove -= count
				slots.remove_at(i)
			else:
				slot["amount"] = count - remaining_to_remove
				remaining_to_remove = 0
		i -= 1
		
	contents_changed.emit()
	return true

func clear() -> void:
	slots.clear()
	contents_changed.emit()

func get_slots() -> Array[Dictionary]:
	return slots.duplicate(true)

func to_dict() -> Array:
	var result: Array = []
	for slot in slots:
		result.append({
			"item_id": String(slot.get("item_id", "")),
			"amount": int(slot.get("amount", 0))
		})
	return result

func from_dict(arr: Array) -> void:
	slots.clear()
	for item in arr:
		if item is Dictionary and item.has("item_id") and item.has("amount"):
			slots.append({
				"item_id": StringName(item["item_id"]),
				"amount": int(item["amount"])
			})
	contents_changed.emit()
