class_name OperationSnapshot
extends RefCounted

const AttackStateClass = preload("res://game/combat/attack_state.gd")
const BuildSiteStateClass = preload("res://game/build/build_site_state.gd")
const ContainerStateClass = preload("res://game/inventory/container_state.gd")
const EnemyStateClass = preload("res://game/combat/enemy_state.gd")
const EnemyDefinitionClass = preload("res://game/content/definitions/enemy_definition.gd")
const TerrainDefinitionClass = preload("res://game/content/definitions/terrain_definition.gd")
const InventoryStateClass = preload("res://game/inventory/inventory_state.gd")
const ObjectiveStateClass = preload("res://game/objective/objective_state.gd")
const PickupStateClass = preload("res://game/inventory/pickup_state.gd")
const PressureEventClass = preload("res://game/threat/pressure_event.gd")
const SpawnTicketClass = preload("res://game/threat/spawn_ticket.gd")
const StructureStateClass = preload("res://game/build/structure_state.gd")
const ThreatStateClass = preload("res://game/threat/threat_state.gd")

static func capture(controller) -> Dictionary:
	var state = controller.state
	return {
		"operation": {
			"operation_id": String(state.operation_id),
			"definition_id": String(state.definition_id),
			"lifecycle": int(state.lifecycle_state),
			"logical_tick": state.logical_tick,
			"seed": state.seed,
			"end_reason": int(state.end_reason),
			"revision": state.revision,
			"extraction_eligible": state.extraction_eligible,
			"terrain_id": String(controller.terrain_id),
			"blueprint_ids": _string_names(controller.available_blueprint_ids),
			"selected_blueprint_id": String(controller.build.selected_definition_id),
		},
		"clock_tick": controller.clock.logical_tick,
		"player": {"position": _vector(controller.player.position), "velocity": _vector(controller.player.velocity)},
		"core": {"position": _vector(controller.core.position), "health": int(controller.combat.state.health_by_entity.get(&"core", {}).get("current", controller.core.health))},
		"inventory": _capture_inventory(controller.inventory.state),
		"build": _capture_build(controller.build.state),
		"combat": _capture_combat(controller.combat.state),
		"objective": _capture_objective(controller.objective.state),
		"threat": _capture_threat(controller.threat.state),
		"sequences": {
			"operation_action": controller._action_sequence,
			"operation_fact": controller._fact_sequence,
			"inventory_fact": controller.inventory._fact_sequence,
			"build_sequence": controller.build._sequence,
			"build_fact": controller.build._fact_sequence,
			"combat_fact": controller.combat._fact_sequence,
			"combat_attack": controller.combat._attack_sequence,
			"threat_sequence": controller.threat._sequence,
		},
	}

static func restore(controller, payload: Dictionary) -> bool:
	if controller == null or not payload.has_all(["operation", "player", "core", "inventory", "build", "combat", "objective", "threat"]):
		return false
	var operation_data: Dictionary = payload.get("operation", {})
	if String(operation_data.get("operation_id", "")).is_empty() or String(operation_data.get("definition_id", "")).is_empty():
		return false
	var lifecycle: int = int(operation_data.get("lifecycle", -1))
	if lifecycle < 0 or lifecycle > 5:
		return false
	var state = controller.state
	if state == null:
		return false
	var terrain_id := StringName(operation_data.get("terrain_id", controller.terrain_id))
	var terrain = controller.build.catalog.get_definition(terrain_id) if controller.build.catalog != null else null
	if terrain == null or terrain.get_script() != TerrainDefinitionClass or not controller.world.supports_terrain(terrain_id):
		return false
	controller.terrain_id = terrain_id
	controller.world.configure(controller.world.map_size, terrain_id)
	state.operation_id = StringName(operation_data.operation_id)
	state.definition_id = StringName(operation_data.definition_id)
	state.lifecycle_state = lifecycle
	state.logical_tick = int(operation_data.get("logical_tick", 0))
	state.seed = int(operation_data.get("seed", 0))
	state.end_reason = int(operation_data.get("end_reason", 0))
	state.revision = int(operation_data.get("revision", 0))
	state.extraction_eligible = bool(operation_data.get("extraction_eligible", false))
	controller.clock.logical_tick = int(payload.get("clock_tick", state.logical_tick))
	controller.player.position = _to_vector(payload.player.get("position", []))
	controller.player.velocity = _to_vector(payload.player.get("velocity", []))
	controller.core.position = _to_vector(payload.core.get("position", []))
	if not _restore_inventory(controller.inventory, payload.inventory, state.operation_id):
		return false
	controller.refresh_pickup_views()
	if not _restore_build(controller.build, payload.build, state.operation_id):
		return false
	controller.available_blueprint_ids = _string_names(operation_data.get("blueprint_ids", [&"wall"]))
	if controller.available_blueprint_ids.is_empty():
		controller.available_blueprint_ids = [&"wall"]
	var selected_blueprint_id := StringName(operation_data.get("selected_blueprint_id", controller.available_blueprint_ids[0]))
	if not controller.available_blueprint_ids.has(selected_blueprint_id) or not controller.build.select_definition(selected_blueprint_id):
		if not controller.build.select_definition(controller.available_blueprint_ids[0]):
			return false
	if not _restore_combat(controller.combat, payload.combat, state.operation_id):
		return false
	if not _restore_objective(controller.objective, payload.objective, state.operation_id):
		return false
	if not _restore_threat(controller.threat, payload.threat, state.operation_id, state.logical_tick):
		return false
	state.inventory_state = controller.inventory.state
	state.build_state = controller.build.state
	state.combat_state = controller.combat.state
	state.objective_state = controller.objective.state
	state.threat_state = controller.threat.state
	controller._action_sequence = int(payload.sequences.get("operation_action", 0))
	controller._fact_sequence = int(payload.sequences.get("operation_fact", 0))
	controller.inventory._fact_sequence = int(payload.sequences.get("inventory_fact", 0))
	controller.build._sequence = int(payload.sequences.get("build_sequence", 0))
	controller.build._fact_sequence = int(payload.sequences.get("build_fact", 0))
	controller.combat._fact_sequence = int(payload.sequences.get("combat_fact", 0))
	controller.combat._attack_sequence = int(payload.sequences.get("combat_attack", 0))
	controller.threat._sequence = int(payload.sequences.get("threat_sequence", 0))
	controller._processed_actions.clear()
	controller.outcome = null
	var active := lifecycle == 2 or lifecycle == 3
	controller.player.set_enabled(active)
	controller.build.set_enabled(active)
	controller.combat.set_enabled(active)
	controller.objective.set_enabled(active)
	controller.threat.set_enabled(active)
	var core_health: int = int(payload.core.get("health", controller.core.max_health))
	controller.core.set_health(core_health)
	return true

static func _capture_inventory(state) -> Dictionary:
	var containers: Array = []
	for container in state.containers.values():
		var reservations: Array = []
		for reservation_id in container.reservations.keys():
			var reservation: Dictionary = container.reservations[reservation_id]
			reservations.append({"id": String(reservation_id), "item_id": String(reservation.get("item_id", &"")), "amount": int(reservation.get("amount", 0))})
		containers.append({"id": String(container.container_id), "owner_id": String(container.owner_id), "capacity": container.capacity, "items": _string_int_dict(container.item_stacks), "reservations": reservations, "revision": container.revision})
	var pickups: Array = []
	for pickup in state.pickups.values():
		pickups.append({"id": String(pickup.pickup_id), "item_id": String(pickup.item_id), "amount": pickup.amount, "position": _vector(pickup.position), "claimed": pickup.claimed, "container_id": String(pickup.container_id)})
	return {"containers": containers, "pickups": pickups, "revision": state.revision}

static func _capture_build(state) -> Dictionary:
	var grid = state.grid
	var cells: Array = []
	for cell_id in grid.cells.keys():
		var cell: Dictionary = grid.cells[cell_id]
		cells.append({
			"cell": _cell(cell_id),
			"occupants": _string_pairs(cell.get("occupants_by_channel", {})),
			"connection_groups": _string_pairs(cell.get("connection_groups", {})),
			"compatible_groups": _string_array_pairs(cell.get("compatible_groups", {})),
			"reservation_id": String(cell.get("reservation_id", &"")),
			"blocked_for_player": bool(cell.get("blocked_for_player", false)),
			"blocked_for_enemy": bool(cell.get("blocked_for_enemy", false)),
		})
	var sites: Array = []
	for site in state.build_sites.values():
		sites.append({"id": String(site.build_site_id), "entity_id": String(site.entity_id), "definition_id": String(site.definition_id), "owner_id": String(site.owner_id), "anchor": _cell(site.anchor_cell), "rotation": site.rotation, "footprint": _cells(site.footprint_cells), "reserved_items": _string_int_dict(site.reserved_items), "committed_items": _string_int_dict(site.committed_items), "work_progress": site.work_progress, "lifecycle": int(site.lifecycle)})
	var structures: Array = []
	for structure in state.structures.values():
		structures.append({"id": String(structure.structure_id), "definition_id": String(structure.definition_id), "owner_id": String(structure.owner_id), "anchor": _cell(structure.anchor_cell), "rotation": structure.rotation, "footprint": _cells(structure.footprint_cells), "lifecycle": int(structure.lifecycle)})
	return {"map_size": _vector(grid.map_size), "revision": state.revision, "grid_revision": grid.revision, "navigation_revision": grid.navigation_revision, "cells": cells, "build_sites": sites, "structures": structures, "dirty_cells": _cells(state.dirty_cells)}

static func _capture_combat(state) -> Dictionary:
	var health: Array = []
	for entity_id in state.health_by_entity.keys():
		var value: Dictionary = state.health_by_entity[entity_id]
		health.append({"id": String(entity_id), "current": int(value.get("current", 0)), "maximum": int(value.get("maximum", 0))})
	var enemies: Array = []
	for enemy in state.enemies.values():
		enemies.append({"id": String(enemy.enemy_id), "definition_id": String(enemy.definition_id), "cell": _cell(enemy.cell), "path_index": enemy.path_index, "attack_cooldown": enemy.attack_cooldown, "lifecycle": int(enemy.lifecycle)})
	var attacks: Array = []
	for attack in state.attacks.values():
		attacks.append({"id": String(attack.attack_id), "actor_id": String(attack.actor_id), "target_id": String(attack.target_id), "damage": attack.damage, "issued_tick": attack.issued_tick, "lifecycle": int(attack.lifecycle)})
	return {"health": health, "enemies": enemies, "attacks": attacks, "defeated": _strings(state.defeated_entities.keys()), "core_cell": _cell(state.core_cell), "protected_target_cell": _cell(state.protected_target_cell), "navigation_revision": state.navigation_revision, "revision": state.revision}

static func _capture_objective(state) -> Dictionary:
	var objectives: Array = []
	for objective_id in state.objectives.keys():
		var value: Dictionary = state.objectives[objective_id]
		objectives.append({"id": String(objective_id), "state": int(value.get("state", 0)), "required_fact_type": String(value.get("required_fact_type", &"")), "item_id": String(value.get("item_id", &"")), "target_amount": int(value.get("target_amount", 0)), "progress": int(value.get("progress", 0)), "activated_tick": int(value.get("activated_tick", 0)), "resolved_tick": int(value.get("resolved_tick", -1))})
	return {"active_objective_id": String(state.active_objective_id), "completed_objective_ids": _strings(state.completed_objective_ids), "revision": state.revision, "objectives": objectives}

static func _capture_threat(state) -> Dictionary:
	var events: Array = []
	for event in state.events.values():
		events.append({"id": String(event.event_id), "source_fact_type": String(event.source_fact_type), "started_tick": event.started_tick, "expiry_tick": event.expiry_tick, "severity": event.severity, "spawn_ticket_ids": _strings(event.spawn_ticket_ids), "lifecycle": int(event.lifecycle)})
	var spawn_tickets: Array = []
	for ticket in state.spawn_tickets.values():
		spawn_tickets.append({"id": String(ticket.ticket_id), "pressure_event_id": String(ticket.pressure_event_id), "enemy_pool_id": String(ticket.enemy_pool_id), "spawn_region": String(ticket.spawn_region), "target_policy_id": String(ticket.target_policy_id), "rng_state_reference": String(ticket.rng_state_reference), "spawn_entries": _capture_spawn_entries(ticket.spawn_entries), "enemy_ids": _strings(ticket.enemy_ids), "defeated_enemy_ids": _strings(ticket.defeated_enemy_ids), "lifecycle": int(ticket.lifecycle)})
	return {"pressure": state.pressure, "pressure_tier": state.pressure_tier, "active_event_id": String(state.active_event_id), "recovery_until_tick": state.recovery_until_tick, "extraction_pressure": state.extraction_pressure, "next_spawn_wave_index": state.next_spawn_wave_index, "revision": state.revision, "events": events, "spawn_tickets": spawn_tickets}

static func _capture_spawn_entries(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var entry: Dictionary = value
		result.append({"id": String(entry.get("id", "")), "definition_id": String(entry.get("definition_id", "")), "spawn_cell": _cell(entry.get("spawn_cell", Vector2i.ZERO))})
	return result

static func _restore_inventory(controller, data: Dictionary, operation_id: StringName) -> bool:
	var state = InventoryStateClass.new()
	for value in data.get("containers", []):
		if typeof(value) != TYPE_DICTIONARY or String(value.get("id", "")).is_empty():
			return false
		var container = ContainerStateClass.new(StringName(value.id), StringName(value.get("owner_id", "")), int(value.get("capacity", 0)))
		container.item_stacks = _int_dict_from(value.get("items", {}))
		for reservation in value.get("reservations", []):
			container.reservations[StringName(reservation.get("id", ""))] = {"item_id": StringName(reservation.get("item_id", "")), "amount": int(reservation.get("amount", 0))}
		container.revision = int(value.get("revision", 0))
		state.containers[container.container_id] = container
	for value in data.get("pickups", []):
		var pickup = PickupStateClass.new(StringName(value.get("id", "")), StringName(value.get("item_id", "")), int(value.get("amount", 0)), _to_vector(value.get("position", [])), StringName(value.get("container_id", "")))
		pickup.claimed = bool(value.get("claimed", false))
		state.pickups[pickup.pickup_id] = pickup
	state.revision = int(data.get("revision", 0))
	controller.state = state
	controller.operation_id = operation_id
	controller._processed_actions.clear()
	return true

static func _restore_build(controller, data: Dictionary, operation_id: StringName) -> bool:
	var state = controller.state
	var grid = state.grid
	grid.configure(_to_vector(data.get("map_size", [])))
	for value in data.get("cells", []):
		var cell_id: Vector2i = _to_cell(value.get("cell", []))
		grid.cells[cell_id] = {"occupants_by_channel": _name_pairs(value.get("occupants", [])), "connection_groups": _name_pairs(value.get("connection_groups", [])), "compatible_groups": _name_array_pairs(value.get("compatible_groups", [])), "reservation_id": StringName(value.get("reservation_id", "")), "blocked_for_player": bool(value.get("blocked_for_player", false)), "blocked_for_enemy": bool(value.get("blocked_for_enemy", false))}
	grid.revision = int(data.get("grid_revision", 0))
	grid.navigation_revision = int(data.get("navigation_revision", 0))
	grid.rebuild_navigation()
	state.build_sites.clear()
	for value in data.get("build_sites", []):
		var site = BuildSiteStateClass.new(StringName(value.get("id", "")), StringName(value.get("entity_id", "")), StringName(value.get("definition_id", "")), StringName(value.get("owner_id", "")), _to_cell(value.get("anchor", [])), int(value.get("rotation", 0)), _to_cells(value.get("footprint", [])))
		site.reserved_items = _int_dict_from(value.get("reserved_items", {}))
		site.committed_items = _int_dict_from(value.get("committed_items", {}))
		site.work_progress = int(value.get("work_progress", 0))
		site.lifecycle = int(value.get("lifecycle", BuildSiteStateClass.Lifecycle.RESERVED))
		state.build_sites[site.build_site_id] = site
	state.structures.clear()
	for value in data.get("structures", []):
		var structure = StructureStateClass.new(StringName(value.get("id", "")), StringName(value.get("definition_id", "")), StringName(value.get("owner_id", "")), _to_cell(value.get("anchor", [])), int(value.get("rotation", 0)), _to_cells(value.get("footprint", [])))
		structure.lifecycle = int(value.get("lifecycle", StructureStateClass.Lifecycle.ACTIVE))
		state.structures[structure.structure_id] = structure
	state.dirty_cells = _to_cells(data.get("dirty_cells", []))
	state.revision = int(data.get("revision", 0))
	controller.operation_id = operation_id
	controller.preview.clear()
	for view in controller._views.values():
		view.clear()
	controller._views.clear()
	for structure_id in state.structures.keys():
		var structure = state.structures[structure_id]
		var view = preload("res://game/build/structure_view.gd").new()
		controller._views[structure_id] = view
		controller.structure_root.add_child(view)
	controller._refresh_views()
	return true

static func _restore_combat(controller, data: Dictionary, operation_id: StringName) -> bool:
	var state = controller.state
	state.health_by_entity.clear()
	for value in data.get("health", []):
		state.health_by_entity[StringName(value.get("id", ""))] = {"current": int(value.get("current", 0)), "maximum": int(value.get("maximum", 0))}
	state.enemies.clear()
	for value in data.get("enemies", []):
		var definition_id := StringName(value.get("definition_id", controller.enemy_definition_id))
		var definition := controller.catalog.get_definition(definition_id) as EnemyDefinition
		if definition == null or definition.get_script() != EnemyDefinitionClass:
			return false
		var enemy = EnemyStateClass.new(StringName(value.get("id", "")), _to_cell(value.get("cell", [])), definition_id)
		enemy.attack_damage = int(definition.attack_damage)
		enemy.attack_cooldown_ticks = int(definition.attack_cooldown_ticks)
		enemy.path_index = int(value.get("path_index", 0))
		enemy.attack_cooldown = int(value.get("attack_cooldown", 0))
		enemy.lifecycle = int(value.get("lifecycle", EnemyStateClass.Lifecycle.SPAWNING))
		state.enemies[enemy.enemy_id] = enemy
	state.attacks.clear()
	for value in data.get("attacks", []):
		var attack = AttackStateClass.new(StringName(value.get("id", "")), StringName(value.get("actor_id", "")), StringName(value.get("target_id", "")), int(value.get("damage", 0)), int(value.get("issued_tick", 0)))
		attack.lifecycle = int(value.get("lifecycle", AttackStateClass.Lifecycle.REQUESTED))
		state.attacks[attack.attack_id] = attack
	state.defeated_entities.clear()
	for entity_id in data.get("defeated", []):
		state.defeated_entities[StringName(entity_id)] = true
	state.core_cell = _to_cell(data.get("core_cell", []))
	state.protected_target_cell = _to_cell(data.get("protected_target_cell", []))
	state.navigation_revision = int(data.get("navigation_revision", -1))
	state.revision = int(data.get("revision", 0))
	controller.operation_id = operation_id
	controller.target_cell = state.protected_target_cell
	for enemy in state.enemies.values():
		controller._repath(enemy)
	controller.refresh_enemy_views()
	controller.core_view.set_health(int(state.health_by_entity.get(&"core", {}).get("current", controller.core_view.health)))
	return true

static func _restore_objective(controller, data: Dictionary, operation_id: StringName) -> bool:
	var state = ObjectiveStateClass.new()
	state.active_objective_id = StringName(data.get("active_objective_id", ""))
	state.completed_objective_ids = _string_names(data.get("completed_objective_ids", []))
	state.revision = int(data.get("revision", 0))
	for value in data.get("objectives", []):
		var objective_id := StringName(value.get("id", ""))
		if String(objective_id).is_empty():
			return false
		state.objectives[objective_id] = {"objective_id": objective_id, "state": int(value.get("state", ObjectiveStateClass.Lifecycle.LOCKED)), "required_fact_type": StringName(value.get("required_fact_type", "")), "item_id": StringName(value.get("item_id", "")), "target_amount": int(value.get("target_amount", 0)), "progress": int(value.get("progress", 0)), "activated_tick": int(value.get("activated_tick", 0)), "resolved_tick": int(value.get("resolved_tick", -1))}
	controller.state = state
	controller.operation_id = operation_id
	return true

static func _restore_threat(controller, data: Dictionary, operation_id: StringName, current_tick: int) -> bool:
	var state = ThreatStateClass.new()
	state.pressure = int(data.get("pressure", 0))
	state.pressure_tier = int(data.get("pressure_tier", 0))
	state.active_event_id = StringName(data.get("active_event_id", ""))
	state.recovery_until_tick = int(data.get("recovery_until_tick", -1))
	state.extraction_pressure = int(data.get("extraction_pressure", 0))
	state.next_spawn_wave_index = maxi(0, int(data.get("next_spawn_wave_index", 0)))
	state.revision = int(data.get("revision", 0))
	for value in data.get("events", []):
		var event = PressureEventClass.new(StringName(value.get("id", "")), StringName(value.get("source_fact_type", "")), int(value.get("started_tick", 0)), maxi(1, int(value.get("expiry_tick", 1)) - int(value.get("started_tick", 0))), int(value.get("severity", 1)))
		event.expiry_tick = int(value.get("expiry_tick", event.expiry_tick))
		event.spawn_ticket_ids = _string_names(value.get("spawn_ticket_ids", []))
		event.lifecycle = int(value.get("lifecycle", PressureEventClass.Lifecycle.PLANNED))
		state.events[event.event_id] = event
	for value in data.get("spawn_tickets", []):
		if typeof(value) != TYPE_DICTIONARY or String(value.get("id", "")).is_empty():
			return false
		var raw_entries = value.get("spawn_entries", [])
		if typeof(raw_entries) != TYPE_ARRAY:
			return false
		var spawn_entries := _restore_spawn_entries(raw_entries)
		if spawn_entries.size() != raw_entries.size():
			return false
		var ticket = SpawnTicketClass.new(StringName(value.get("id", "")), StringName(value.get("pressure_event_id", "")), StringName(value.get("enemy_pool_id", "")), spawn_entries)
		ticket.spawn_region = StringName(value.get("spawn_region", "outer_ring"))
		ticket.target_policy_id = StringName(value.get("target_policy_id", "protected_core"))
		ticket.rng_state_reference = StringName(value.get("rng_state_reference", ticket.ticket_id))
		ticket.enemy_ids = _string_names(value.get("enemy_ids", []))
		ticket.defeated_enemy_ids = _string_names(value.get("defeated_enemy_ids", []))
		ticket.lifecycle = int(value.get("lifecycle", SpawnTicketClass.Lifecycle.PLANNED))
		state.spawn_tickets[ticket.ticket_id] = ticket
	controller.state = state
	controller.operation_id = operation_id
	controller._current_tick = current_tick
	controller.telegraph.clear()
	var active_event = state.events.get(state.active_event_id)
	if active_event != null:
		controller.telegraph.configure(active_event.event_id, active_event.started_tick, maxi(1, active_event.expiry_tick - active_event.started_tick), active_event.severity)
		controller.telegraph.update_progress(current_tick, active_event.expiry_tick)
	return true

static func _restore_spawn_entries(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			return []
		var cell_value = value.get("spawn_cell", [])
		if typeof(cell_value) != TYPE_ARRAY or cell_value.size() < 2:
			return []
		result.append({"id": StringName(value.get("id", "")), "definition_id": StringName(value.get("definition_id", "")), "spawn_cell": _to_cell(cell_value)})
	return result

static func _vector(value: Vector2) -> Array:
	return [value.x, value.y]

static func _cell(value: Vector2i) -> Array:
	return [value.x, value.y]

static func _cells(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(_cell(value))
	return result

static func _to_vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value.size() >= 2 else Vector2.ZERO

static func _to_cell(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1])) if value.size() >= 2 else Vector2i.ZERO

static func _to_cells(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(_to_cell(value))
	return result

static func _string_int_dict(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		result[String(key)] = int(source[key])
	return result

static func _int_dict_from(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		result[StringName(key)] = int(source[key])
	return result

static func _string_pairs(source: Dictionary) -> Array:
	var result: Array = []
	for key in source.keys():
		result.append({"key": String(key), "value": String(source[key])})
	return result

static func _name_pairs(source: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in source:
		result[StringName(value.get("key", ""))] = StringName(value.get("value", ""))
	return result

static func _string_array_pairs(source: Dictionary) -> Array:
	var result: Array = []
	for key in source.keys():
		result.append({"key": String(key), "values": _strings(source[key])})
	return result

static func _name_array_pairs(source: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in source:
		result[StringName(value.get("key", ""))] = _string_names(value.get("values", []))
	return result

static func _strings(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(String(value))
	return result

static func _string_names(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(StringName(value))
	return result
