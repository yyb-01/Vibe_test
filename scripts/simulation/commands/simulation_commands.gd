class_name SimulationCommands
extends RefCounted

# res://scripts/simulation/commands/simulation_commands.gd
# Factory methods and validation helpers for simulation command payloads.

const ProtocolConstantsClass = preload("res://scripts/application/protocol/protocol_constants.gd")
const CommandEnvelopeClass = preload("res://scripts/application/protocol/command_envelope.gd")

static func create_move_intent(player_id: int, entity_id: int, axis: Vector2, seq: int, tick: int) -> CommandEnvelopeClass:
	var payload := {
		"axis_x": clampf(axis.x, -1.0, 1.0),
		"axis_y": clampf(axis.y, -1.0, 1.0)
	}
	return CommandEnvelopeClass.new(
		ProtocolConstantsClass.CommandType.MOVE_INTENT,
		payload,
		player_id,
		entity_id,
		seq,
		tick
	)

static func create_aim_intent(player_id: int, entity_id: int, angle: float, seq: int, tick: int) -> CommandEnvelopeClass:
	var payload := {
		"angle": angle
	}
	return CommandEnvelopeClass.new(
		ProtocolConstantsClass.CommandType.AIM_INTENT,
		payload,
		player_id,
		entity_id,
		seq,
		tick
	)

static func create_ability_command(
	player_id: int,
	entity_id: int,
	ability_id: StringName,
	pressed: bool,
	target_hint: Vector2,
	seq: int,
	tick: int
) -> CommandEnvelopeClass:
	var payload := {
		"ability_id": str(ability_id),
		"pressed": pressed,
		"target_hint": [target_hint.x, target_hint.y]
	}
	return CommandEnvelopeClass.new(
		ProtocolConstantsClass.CommandType.ABILITY_COMMAND,
		payload,
		player_id,
		entity_id,
		seq,
		tick
	)

static func create_build_command(
	player_id: int,
	builder_entity_id: int,
	structure_id: StringName,
	anchor_cell: Vector2i,
	rotation_quarters: int,
	expected_grid_revision: int,
	seq: int,
	tick: int
) -> CommandEnvelopeClass:
	var payload := {
		"structure_id": str(structure_id),
		"anchor_cell": [anchor_cell.x, anchor_cell.y],
		"rotation_quarters": rotation_quarters,
		"expected_grid_revision": expected_grid_revision
	}
	return CommandEnvelopeClass.new(
		ProtocolConstantsClass.CommandType.BUILD_COMMAND,
		payload,
		player_id,
		builder_entity_id,
		seq,
		tick
	)

static func create_remove_build_command(
	player_id: int,
	builder_entity_id: int,
	structure_entity_id: int,
	expected_grid_revision: int,
	seq: int,
	tick: int
) -> CommandEnvelopeClass:
	var payload := {
		"structure_entity_id": structure_entity_id,
		"expected_grid_revision": expected_grid_revision
	}
	return CommandEnvelopeClass.new(
		ProtocolConstantsClass.CommandType.REMOVE_BUILD_COMMAND,
		payload,
		player_id,
		builder_entity_id,
		seq,
		tick
	)

static func create_phase_command(
	player_id: int,
	action_id: StringName,
	expected_phase_revision: int,
	extra_payload: Dictionary,
	seq: int,
	tick: int
) -> CommandEnvelopeClass:
	var payload := {
		"action_id": str(action_id),
		"expected_phase_revision": expected_phase_revision
	}
	for k in extra_payload:
		payload[k] = extra_payload[k]
	return CommandEnvelopeClass.new(
		ProtocolConstantsClass.CommandType.PHASE_COMMAND,
		payload,
		player_id,
		0,
		seq,
		tick
	)

static func create_inventory_command(
	player_id: int,
	action_id: StringName,
	item_id: StringName,
	amount: int,
	container: StringName,
	expected_revision: int,
	seq: int,
	tick: int
) -> CommandEnvelopeClass:
	var payload := {
		"action_id": str(action_id),
		"item_id": str(item_id),
		"amount": amount,
		"container": str(container),
		"expected_revision": expected_revision
	}
	return CommandEnvelopeClass.new(
		ProtocolConstantsClass.CommandType.INVENTORY_COMMAND,
		payload,
		player_id,
		0,
		seq,
		tick
	)
