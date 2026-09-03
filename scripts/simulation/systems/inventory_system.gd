class_name InventorySystem
extends RefCounted

# res://scripts/simulation/systems/inventory_system.gd
# Authoritative inventory transactions for bags, storage, transfers, and material deductions.

const SimulationWorldClass = preload("res://scripts/simulation/model/simulation_world.gd")
const ProtocolConstantsClass = preload("res://scripts/application/protocol/protocol_constants.gd")
const DomainEventsClass = preload("res://scripts/simulation/events/domain_events.gd")

var world: SimulationWorldClass

const DEFAULT_MAX_STACK: int = 50

func _init(p_world: SimulationWorldClass) -> void:
	world = p_world

func handle_inventory_command(payload: Dictionary, player_id: int) -> Dictionary:
	var action_id: String = payload.get("action_id", "")
	var item_id_str: String = payload.get("item_id", "")
	var item_id := StringName(item_id_str)
	var amount: int = int(payload.get("amount", 0))
	var container: String = payload.get("container", "storage")

	var events: Array[Dictionary] = []
	var p_state = world.players.get(player_id, null)

	match action_id:
		"add":
			if amount <= 0 or item_id == &"":
				return {"accepted": false, "reason": ProtocolConstantsClass.ReasonCode.INVALID_STATE, "events": []}
			if container == "storage":
				world.session_state.shared_storage[item_id] = int(world.session_state.shared_storage.get(item_id, 0)) + amount
				_emit_transaction(player_id, "storage", item_id, amount, world.session_state.shared_storage[item_id], events)
			elif container == "bag" and p_state != null:
				var added := _add_to_bag(p_state, item_id, amount)
				if added == 0:
					return {"accepted": false, "reason": ProtocolConstantsClass.ReasonCode.INSUFFICIENT_RESOURCE, "events": []}
				_emit_transaction(player_id, "bag", item_id, added, _get_bag_item_count(p_state, item_id), events)
			return {"accepted": true, "reason": ProtocolConstantsClass.ReasonCode.ACCEPTED, "events": events}

		"remove":
			if amount <= 0 or item_id == &"":
				return {"accepted": false, "reason": ProtocolConstantsClass.ReasonCode.INVALID_STATE, "events": []}
			if container == "storage":
				var current: int = int(world.session_state.shared_storage.get(item_id, 0))
				if current < amount:
					return {"accepted": false, "reason": ProtocolConstantsClass.ReasonCode.INSUFFICIENT_RESOURCE, "events": []}
				world.session_state.shared_storage[item_id] = current - amount
				if world.session_state.shared_storage[item_id] <= 0:
					world.session_state.shared_storage.erase(item_id)
				_emit_transaction(player_id, "storage", item_id, -amount, world.session_state.shared_storage.get(item_id, 0), events)
			elif container == "bag" and p_state != null:
				if not _remove_from_bag(p_state, item_id, amount):
					return {"accepted": false, "reason": ProtocolConstantsClass.ReasonCode.INSUFFICIENT_RESOURCE, "events": []}
				_emit_transaction(player_id, "bag", item_id, -amount, _get_bag_item_count(p_state, item_id), events)
			return {"accepted": true, "reason": ProtocolConstantsClass.ReasonCode.ACCEPTED, "events": events}

		"clear_bag":
			if p_state != null:
				for slot in p_state.expedition_bag_slots:
					slot["item_id"] = &""
					slot["amount"] = 0
				_emit_transaction(player_id, "bag", &"", 0, 0, events)
			return {"accepted": true, "reason": ProtocolConstantsClass.ReasonCode.ACCEPTED, "events": events}

	return {"accepted": false, "reason": ProtocolConstantsClass.ReasonCode.INVALID_STATE, "events": []}

func _add_to_bag(p_state, item_id: StringName, amount: int) -> int:
	var remaining: int = amount
	var max_stack: int = DEFAULT_MAX_STACK

	# First fill existing stacks
	for slot in p_state.expedition_bag_slots:
		if slot.get("item_id", &"") == item_id:
			var cur: int = int(slot.get("amount", 0))
			var space: int = max_stack - cur
			if space > 0:
				var to_add: int = mini(space, remaining)
				slot["amount"] = cur + to_add
				remaining -= to_add
				if remaining <= 0:
					return amount

	# Next fill empty slots
	for slot in p_state.expedition_bag_slots:
		if slot.get("item_id", &"") == &"" or int(slot.get("amount", 0)) == 0:
			var to_add: int = mini(max_stack, remaining)
			slot["item_id"] = item_id
			slot["amount"] = to_add
			remaining -= to_add
			if remaining <= 0:
				return amount

	return amount - remaining

func _remove_from_bag(p_state, item_id: StringName, amount: int) -> bool:
	if _get_bag_item_count(p_state, item_id) < amount:
		return false

	var remaining: int = amount
	for slot in p_state.expedition_bag_slots:
		if slot.get("item_id", &"") == item_id:
			var cur: int = int(slot.get("amount", 0))
			if cur <= remaining:
				remaining -= cur
				slot["item_id"] = &""
				slot["amount"] = 0
			else:
				slot["amount"] = cur - remaining
				remaining = 0
				break
	return true

func _get_bag_item_count(p_state, item_id: StringName) -> int:
	var total: int = 0
	for slot in p_state.expedition_bag_slots:
		if slot.get("item_id", &"") == item_id:
			total += int(slot.get("amount", 0))
	return total

func _emit_transaction(player_id: int, container: String, item_id: StringName, delta: int, result: int, events: Array[Dictionary]) -> void:
	var ev_id = world.id_generator.generate_event_id()
	events.append(DomainEventsClass.create_event(
		ev_id,
		world.server_tick,
		DomainEventsClass.EventType.INVENTORY_COMMITTED,
		{
			"player_id": player_id,
			"container": container,
			"item_id": str(item_id),
			"delta_amount": delta,
			"resulting_amount": result
		}
	))
