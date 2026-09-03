class_name BuildingSystem
extends RefCounted

# res://scripts/simulation/systems/building_system.gd
# Authoritative isometric building placement, removal, occupancy, and cost verification.

const SimulationWorldClass = preload("res://scripts/simulation/model/simulation_world.gd")
const EntityStateClass = preload("res://scripts/simulation/model/entity_state.gd")
const ProtocolConstantsClass = preload("res://scripts/application/protocol/protocol_constants.gd")
const DomainEventsClass = preload("res://scripts/simulation/events/domain_events.gd")

var world: SimulationWorldClass

const STRUCTURE_COSTS: Dictionary = {
	"barricade_wood": {"wood": 4},
	"barricade_metal": {"scrap_metal": 6},
	"turret_basic": {"scrap_metal": 10, "electronics": 4}
}

const STRUCTURE_SIZES: Dictionary = {
	"barricade_wood": Vector2i(1, 1),
	"barricade_metal": Vector2i(1, 1),
	"turret_basic": Vector2i(1, 1),
	"base_core": Vector2i(2, 2)
}

const STRUCTURE_HEALTH: Dictionary = {
	"barricade_wood": 100.0,
	"barricade_metal": 250.0,
	"turret_basic": 150.0,
	"base_core": 1000.0
}

func _init(p_world: SimulationWorldClass) -> void:
	world = p_world

func get_footprint_cells(anchor: Vector2i, size: Vector2i, rot_quarters: int) -> Array[Vector2i]:
	var effective_size := size
	if rot_quarters % 2 != 0:
		effective_size = Vector2i(size.y, size.x)

	var cells: Array[Vector2i] = []
	for x in range(effective_size.x):
		for y in range(effective_size.y):
			cells.append(anchor + Vector2i(x, y))
	return cells

func handle_build(payload: Dictionary, player_id: int) -> Dictionary:
	var structure_id_str: String = payload.get("structure_id", "")
	var structure_id := StringName(structure_id_str)
	var anchor_arr = payload.get("anchor_cell", [0, 0])
	var anchor := Vector2i(int(anchor_arr[0]), int(anchor_arr[1]))
	var rot: int = int(payload.get("rotation_quarters", 0))
	var exp_rev: int = int(payload.get("expected_grid_revision", -1))

	if exp_rev != -1 and exp_rev != world.build_grid.grid_revision:
		return {
			"accepted": false,
			"reason": ProtocolConstantsClass.ReasonCode.STALE_REVISION,
			"events": []
		}

	if not STRUCTURE_SIZES.has(structure_id_str):
		return {
			"accepted": false,
			"reason": ProtocolConstantsClass.ReasonCode.UNKNOWN_DEFINITION,
			"events": []
		}

	var size: Vector2i = STRUCTURE_SIZES[structure_id_str]
	var cells := get_footprint_cells(anchor, size, rot)

	if not world.build_grid.can_place_footprint(cells):
		return {
			"accepted": false,
			"reason": ProtocolConstantsClass.ReasonCode.OCCUPIED,
			"events": []
		}

	# Check materials in shared storage
	var costs: Dictionary = STRUCTURE_COSTS.get(structure_id_str, {})
	for mat in costs:
		var req: int = int(costs[mat])
		if int(world.session_state.shared_storage.get(StringName(mat), 0)) < req:
			return {
				"accepted": false,
				"reason": ProtocolConstantsClass.ReasonCode.INSUFFICIENT_RESOURCE,
				"events": []
			}

	# Deduct materials atomically
	for mat in costs:
		var req: int = int(costs[mat])
		var id := StringName(mat)
		world.session_state.shared_storage[id] = int(world.session_state.shared_storage.get(id, 0)) - req
		if world.session_state.shared_storage[id] <= 0:
			world.session_state.shared_storage.erase(id)

	# Allocate EntityId and state
	var entity_id: int = world.id_generator.generate_entity_id()
	var max_hp: float = STRUCTURE_HEALTH.get(structure_id_str, 100.0)
	var e_state := EntityStateClass.new(entity_id, structure_id, player_id)
	e_state.health = max_hp
	e_state.max_health = max_hp
	e_state.custom_data["anchor_cell"] = [anchor.x, anchor.y]
	e_state.custom_data["rotation_quarters"] = rot
	world.add_entity(e_state)

	# Register in build grid
	world.build_grid.occupy(entity_id, structure_id, anchor, rot, cells)

	var ev_id = world.id_generator.generate_event_id()
	var cells_data: Array = []
	for c in cells:
		cells_data.append([c.x, c.y])

	var events: Array[Dictionary] = [
		DomainEventsClass.create_event(
			ev_id,
			world.server_tick,
			DomainEventsClass.EventType.STRUCTURE_PLACED,
			{
				"entity_id": entity_id,
				"structure_id": structure_id_str,
				"anchor_cell": [anchor.x, anchor.y],
				"rotation_quarters": rot,
				"cells": cells_data,
				"grid_revision": world.build_grid.grid_revision
			}
		)
	]

	return {
		"accepted": true,
		"reason": ProtocolConstantsClass.ReasonCode.ACCEPTED,
		"resulting_revision": world.build_grid.grid_revision,
		"events": events
	}

func handle_remove_build(payload: Dictionary, _player_id: int) -> Dictionary:
	var structure_entity_id: int = int(payload.get("structure_entity_id", 0))
	var exp_rev: int = int(payload.get("expected_grid_revision", -1))

	if exp_rev != -1 and exp_rev != world.build_grid.grid_revision:
		return {
			"accepted": false,
			"reason": ProtocolConstantsClass.ReasonCode.STALE_REVISION,
			"events": []
		}

	var entity = world.get_entity(structure_entity_id)
	if entity == null:
		return {
			"accepted": false,
			"reason": ProtocolConstantsClass.ReasonCode.INVALID_STATE,
			"events": []
		}

	# Refund materials
	var def_str = str(entity.definition_id)
	var costs: Dictionary = STRUCTURE_COSTS.get(def_str, {})
	for mat in costs:
		var amt: int = int(costs[mat])
		var id := StringName(mat)
		world.session_state.shared_storage[id] = int(world.session_state.shared_storage.get(id, 0)) + amt

	var vacated := world.build_grid.vacate(structure_entity_id)
	world.remove_entity(structure_entity_id)

	var vacated_arr: Array = []
	for c in vacated:
		vacated_arr.append([c.x, c.y])

	var ev_id = world.id_generator.generate_event_id()
	var events: Array[Dictionary] = [
		DomainEventsClass.create_event(
			ev_id,
			world.server_tick,
			DomainEventsClass.EventType.STRUCTURE_REMOVED,
			{
				"entity_id": structure_entity_id,
				"cells": vacated_arr,
				"grid_revision": world.build_grid.grid_revision
			}
		)
	]

	return {
		"accepted": true,
		"reason": ProtocolConstantsClass.ReasonCode.ACCEPTED,
		"resulting_revision": world.build_grid.grid_revision,
		"events": events
	}
