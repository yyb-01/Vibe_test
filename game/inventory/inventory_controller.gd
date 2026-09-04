class_name InventoryController
extends Node

const ActionResultClass = preload("res://game/shared/action_result.gd")
const WorldFactClass = preload("res://game/shared/world_fact.gd")
const ContainerStateClass = preload("res://game/inventory/container_state.gd")
const PickupStateClass = preload("res://game/inventory/pickup_state.gd")
const InventoryStateClass = preload("res://game/inventory/inventory_state.gd")
const InventoryRulesClass = preload("res://game/inventory/inventory_rules.gd")

signal pickup_removed(pickup_id: StringName)
signal pickup_added(pickup_id: StringName)
signal facts_emitted(facts: Array)

var state
var operation_id: StringName
var catalog: ContentCatalog
var player_id: StringName = &"player"
var player_pack_id: StringName = &"player_pack"
var core_storage_id: StringName = &"core_storage"
var _processed_actions: Dictionary = {}
var _fact_sequence: int = 0

func setup(next_operation_id: StringName, next_catalog: ContentCatalog, next_player_id: StringName, player_capacity: int, core_capacity: int, pickup_id: StringName, pickup_item_id: StringName, pickup_amount: int, pickup_position: Vector2) -> bool:
	var pickup_definition = next_catalog.get_definition(pickup_item_id) as ItemDefinition if next_catalog != null else null
	if next_catalog == null or pickup_definition == null or pickup_amount > pickup_definition.max_stack or player_capacity <= 0 or core_capacity <= 0 or pickup_amount <= 0 or String(pickup_id).is_empty():
		return false
	operation_id = next_operation_id
	catalog = next_catalog
	player_id = next_player_id
	state = InventoryStateClass.new()
	_processed_actions.clear()
	_fact_sequence = 0
	state.containers[player_pack_id] = ContainerStateClass.new(player_pack_id, player_id, player_capacity)
	state.containers[core_storage_id] = ContainerStateClass.new(core_storage_id, &"core", core_capacity)
	return add_pickup(pickup_id, pickup_item_id, pickup_amount, pickup_position)

func add_pickup(pickup_id: StringName, pickup_item_id: StringName, pickup_amount: int, pickup_position: Vector2) -> bool:
	var pickup_definition = catalog.get_definition(pickup_item_id) as ItemDefinition if catalog != null else null
	if state == null or pickup_definition == null or pickup_amount <= 0 or pickup_amount > pickup_definition.max_stack or String(pickup_id).is_empty() or state.pickups.has(pickup_id):
		return false
	var world_cache_id := StringName("world_%s" % String(pickup_id))
	state.containers[world_cache_id] = ContainerStateClass.new(world_cache_id, &"world", pickup_amount)
	state.containers[world_cache_id].item_stacks[pickup_item_id] = pickup_amount
	state.pickups[pickup_id] = PickupStateClass.new(pickup_id, pickup_item_id, pickup_amount, pickup_position, world_cache_id)
	state.revision += 1
	pickup_added.emit(pickup_id)
	return true

func transfer(action_id: StringName, actor_id: StringName, source_id: StringName, target_id: StringName, item_id: StringName, amount: int, expected_source_revision: int = -1, expected_target_revision: int = -1):
	var previous = _previous(action_id)
	if previous != null:
		return previous
	if actor_id != player_id:
		return _reject(action_id, &"ACTOR_NOT_AVAILABLE")
	return _run_transfer(action_id, source_id, target_id, item_id, amount, &"NONE", expected_source_revision, expected_target_revision)

func pickup(action_id: StringName, pickup_id: StringName, actor_id: StringName):
	var previous = _previous(action_id)
	if previous != null:
		return previous
	if actor_id != player_id:
		return _reject(action_id, &"ACTOR_NOT_AVAILABLE")
	var pickup = state.pickups.get(pickup_id) if state != null else null
	if pickup == null:
		return _reject(action_id, &"TARGET_INVALID")
	if pickup.claimed:
		return _reject(action_id, &"ALREADY_CLAIMED")
	pickup.claimed = true
	var result = _run_transfer(action_id, pickup.container_id, player_pack_id, pickup.item_id, pickup.amount, &"WORLD_TO_CARRIED", -1, -1, false)
	if not result.accepted:
		pickup.claimed = false
		return result
	state.pickups.erase(pickup_id)
	state.containers.erase(pickup.container_id)
	facts_emitted.emit(result.facts)
	pickup_removed.emit(pickup_id)
	return result

func secure(action_id: StringName, actor_id: StringName, item_id: StringName = &""):
	var previous = _previous(action_id)
	if previous != null:
		return previous
	if actor_id != player_id:
		return _reject(action_id, &"ACTOR_NOT_AVAILABLE")
	var source = state.get_container(player_pack_id) if state != null else null
	if source == null:
		return _reject(action_id, &"TARGET_INVALID")
	var selected_item := item_id
	if String(selected_item).is_empty():
		for candidate in source.item_stacks.keys():
			if source.available_amount(StringName(candidate)) > 0:
				selected_item = StringName(candidate)
				break
	if String(selected_item).is_empty():
		return _reject(action_id, &"NOT_ENOUGH_RESOURCE")
	return _run_transfer(action_id, player_pack_id, core_storage_id, selected_item, source.get_amount(selected_item), &"CARRIED_TO_SECURED")

func reserve(action_id: StringName, actor_id: StringName, container_id: StringName, item_id: StringName, amount: int, reservation_id: StringName, expected_revision: int = -1):
	var previous = _previous(action_id)
	if previous != null:
		return previous
	if actor_id != player_id:
		return _reject(action_id, &"ACTOR_NOT_AVAILABLE")
	var container = state.get_container(container_id) if state != null else null
	if container == null:
		return _reject(action_id, &"TARGET_INVALID")
	if expected_revision >= 0 and container.revision != expected_revision:
		return _reject(action_id, &"STALE_PREVIEW")
	var plan: Dictionary = InventoryRulesClass.plan_reservation(container, item_id, amount, reservation_id)
	if not bool(plan.get("accepted", false)):
		return _reject(action_id, plan.get("reason", &"RESERVATION_INVALID"))
	container.reservations[reservation_id] = {"item_id": item_id, "amount": amount}
	container.revision += 1
	state.revision += 1
	var facts: Array = [_fact(&"ITEM_RESERVED", {"container_id": container_id, "item_id": item_id, "amount": amount, "reservation_id": reservation_id})]
	var result = ActionResultClass.accepted_result(action_id, state.revision, facts)
	_remember(action_id, result)
	facts_emitted.emit(facts)
	return result

func release_reservation(action_id: StringName, actor_id: StringName, container_id: StringName, reservation_id: StringName, expected_revision: int = -1):
	var previous = _previous(action_id)
	if previous != null:
		return previous
	if actor_id != player_id:
		return _reject(action_id, &"ACTOR_NOT_AVAILABLE")
	var container = state.get_container(container_id) if state != null else null
	if container == null or not container.reservations.has(reservation_id):
		return _reject(action_id, &"TARGET_INVALID")
	if expected_revision >= 0 and container.revision != expected_revision:
		return _reject(action_id, &"STALE_PREVIEW")
	var reservation: Dictionary = container.reservations[reservation_id]
	container.reservations.erase(reservation_id)
	container.revision += 1
	state.revision += 1
	var facts: Array = [_fact(&"ITEM_RESERVATION_RELEASED", {"container_id": container_id, "item_id": reservation.item_id, "amount": reservation.amount, "reservation_id": reservation_id})]
	var result = ActionResultClass.accepted_result(action_id, state.revision, facts)
	_remember(action_id, result)
	facts_emitted.emit(facts)
	return result

func commit_reservation(action_id: StringName, actor_id: StringName, container_id: StringName, reservation_id: StringName):
	var previous = _previous(action_id)
	if previous != null:
		return previous
	if actor_id != player_id:
		return _reject(action_id, &"ACTOR_NOT_AVAILABLE")
	var container = state.get_container(container_id) if state != null else null
	if container == null or not container.reservations.has(reservation_id):
		return _reject(action_id, &"TARGET_INVALID")
	var reservation: Dictionary = container.reservations[reservation_id]
	var item_id: StringName = reservation.item_id
	var amount := int(reservation.amount)
	if container.get_amount(item_id) < amount:
		return _reject(action_id, &"NOT_ENOUGH_RESOURCE")
	var remaining: int = container.get_amount(item_id) - amount
	if remaining > 0:
		container.item_stacks[item_id] = remaining
	else:
		container.item_stacks.erase(item_id)
	container.reservations.erase(reservation_id)
	container.revision += 1
	state.revision += 1
	var facts: Array = [_fact(&"ITEM_CONSUMED", {"container_id": container_id, "item_id": item_id, "amount": amount, "reservation_id": reservation_id})]
	var result = ActionResultClass.accepted_result(action_id, state.revision, facts)
	_remember(action_id, result)
	facts_emitted.emit(facts)
	return result

func find_pickup_near(position: Vector2, radius: float) -> StringName:
	if state == null:
		return &""
	var best_id: StringName = &""
	var best_distance := 1.0e20
	for pickup in state.pickups.values():
		if pickup.claimed:
			continue
		var distance := position.distance_to(pickup.position)
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best_id = pickup.pickup_id
	return best_id

func get_item_count(container_id: StringName, item_id: StringName) -> int:
	var container = state.get_container(container_id) if state != null else null
	return container.get_amount(item_id) if container != null else 0

func get_available_amount(container_id: StringName, item_id: StringName) -> int:
	var container = state.get_container(container_id) if state != null else null
	return container.available_amount(item_id) if container != null else 0

func get_container_revision(container_id: StringName) -> int:
	var container = state.get_container(container_id) if state != null else null
	return container.revision if container != null else -1

func has_reservation(container_id: StringName, reservation_id: StringName) -> bool:
	var container = state.get_container(container_id) if state != null else null
	return container != null and container.reservations.has(reservation_id)

func total_item_count(item_id: StringName) -> int:
	return state.total_item_count(item_id) if state != null else 0

func _run_transfer(action_id: StringName, source_id: StringName, target_id: StringName, item_id: StringName, amount: int, boundary: StringName, expected_source_revision: int = -1, expected_target_revision: int = -1, emit_facts: bool = true):
	var previous = _previous(action_id)
	if previous != null:
		return previous
	if state == null or catalog == null:
		return _reject(action_id, &"TARGET_INVALID")
	var source = state.get_container(source_id)
	var target = state.get_container(target_id)
	if source == null or target == null:
		return _reject(action_id, &"TARGET_INVALID")
	if expected_source_revision >= 0 and source.revision != expected_source_revision:
		return _reject(action_id, &"STALE_PREVIEW")
	if expected_target_revision >= 0 and target.revision != expected_target_revision:
		return _reject(action_id, &"STALE_PREVIEW")
	var item_definition = catalog.get_definition(item_id) as ItemDefinition
	if item_definition == null:
		return _reject(action_id, &"UNKNOWN_DEFINITION")
	var plan: Dictionary = InventoryRulesClass.plan_transfer(source, target, item_id, amount, item_definition.max_stack)
	if not bool(plan.get("accepted", false)):
		return _reject(action_id, plan.get("reason", &"TARGET_INVALID"))
	var source_amount: int = source.get_amount(item_id) - amount
	if source_amount > 0:
		source.item_stacks[item_id] = source_amount
	else:
		source.item_stacks.erase(item_id)
	target.item_stacks[item_id] = target.get_amount(item_id) + amount
	source.revision += 1
	target.revision += 1
	state.revision += 1
	var facts: Array = [_fact(&"ITEM_TRANSFERRED", {"source_id": source_id, "target_id": target_id, "item_id": item_id, "amount": amount})]
	if boundary == &"WORLD_TO_CARRIED":
		facts.append(_fact(&"ITEM_ACQUIRED", {"container_id": target_id, "item_id": item_id, "amount": amount}))
	elif boundary == &"CARRIED_TO_SECURED":
		facts.append(_fact(&"ITEM_SECURED", {"container_id": target_id, "item_id": item_id, "amount": amount}))
	var result = ActionResultClass.accepted_result(action_id, state.revision, facts)
	_remember(action_id, result)
	if emit_facts:
		facts_emitted.emit(facts)
	return result

func _fact(fact_type: StringName, payload: Dictionary):
	_fact_sequence += 1
	var fact_id := StringName("%s_%d" % [String(operation_id), _fact_sequence])
	return WorldFactClass.new(fact_id, fact_type, operation_id, payload)

func _previous(action_id: StringName):
	return _processed_actions.get(action_id) if _processed_actions.has(action_id) else null

func _reject(action_id: StringName, reason: StringName):
	var result = ActionResultClass.rejected(action_id, reason, state.revision if state != null else 0)
	_remember(action_id, result)
	return result

func _remember(action_id: StringName, result) -> void:
	if not String(action_id).is_empty():
		_processed_actions[action_id] = result
