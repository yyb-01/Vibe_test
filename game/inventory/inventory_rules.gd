class_name InventoryRules
extends RefCounted

const ACCEPTED: StringName = &"ACCEPTED"
const TARGET_INVALID: StringName = &"TARGET_INVALID"
const AMOUNT_INVALID: StringName = &"AMOUNT_INVALID"
const NOT_ENOUGH_RESOURCE: StringName = &"NOT_ENOUGH_RESOURCE"
const INVENTORY_FULL: StringName = &"INVENTORY_FULL"
const STACK_LIMIT: StringName = &"STACK_LIMIT"
const RESERVATION_INVALID: StringName = &"RESERVATION_INVALID"

static func plan_transfer(source, target, item_id: StringName, amount: int, max_stack: int) -> Dictionary:
	if source == null or target == null or source == target:
		return {"accepted": false, "reason": TARGET_INVALID}
	if String(item_id).is_empty() or amount <= 0:
		return {"accepted": false, "reason": AMOUNT_INVALID}
	if source.available_amount(item_id) < amount:
		return {"accepted": false, "reason": NOT_ENOUGH_RESOURCE}
	if target.total_items() + amount > target.capacity:
		return {"accepted": false, "reason": INVENTORY_FULL}
	if target.get_amount(item_id) + amount > max_stack:
		return {"accepted": false, "reason": STACK_LIMIT}
	return {"accepted": true, "reason": ACCEPTED}

static func plan_reservation(container, item_id: StringName, amount: int, reservation_id: StringName) -> Dictionary:
	if container == null or String(item_id).is_empty() or String(reservation_id).is_empty() or amount <= 0:
		return {"accepted": false, "reason": RESERVATION_INVALID}
	if container.reservations.has(reservation_id) or container.available_amount(item_id) < amount:
		return {"accepted": false, "reason": NOT_ENOUGH_RESOURCE}
	return {"accepted": true, "reason": ACCEPTED}
