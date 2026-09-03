class_name SimulationHost
extends RefCounted

# res://scripts/simulation/simulation_host.gd
# Authoritative ISimulationHost implementation executing 60Hz deterministic tick order.

const SimulationWorldClass = preload("res://scripts/simulation/model/simulation_world.gd")
const ProtocolConstantsClass = preload("res://scripts/application/protocol/protocol_constants.gd")
const CommandEnvelopeClass = preload("res://scripts/application/protocol/command_envelope.gd")
const CommandReceiptClass = preload("res://scripts/application/protocol/command_receipt.gd")
const EntityStateClass = preload("res://scripts/simulation/model/entity_state.gd")

const SessionSystemClass = preload("res://scripts/simulation/systems/session_system.gd")
const MovementSystemClass = preload("res://scripts/simulation/systems/movement_system.gd")
const CombatSystemClass = preload("res://scripts/simulation/systems/combat_system.gd")
const BuildingSystemClass = preload("res://scripts/simulation/systems/building_system.gd")
const InventorySystemClass = preload("res://scripts/simulation/systems/inventory_system.gd")
const WaveAISystemClass = preload("res://scripts/simulation/systems/wave_ai_system.gd")

var world: SimulationWorldClass

var session_system: SessionSystemClass
var movement_system: MovementSystemClass
var combat_system: CombatSystemClass
var building_system: BuildingSystemClass
var inventory_system: InventorySystemClass
var wave_ai_system: WaveAISystemClass

var _command_inbox: Array[CommandEnvelopeClass] = []
var _processed_sequences: Dictionary = {} # player_id: int -> last_seq: int

func _init(seed_val: int = 12345) -> void:
	world = SimulationWorldClass.new(seed_val)
	session_system = SessionSystemClass.new(world)
	movement_system = MovementSystemClass.new(world)
	combat_system = CombatSystemClass.new(world)
	building_system = BuildingSystemClass.new(world)
	inventory_system = InventorySystemClass.new(world)
	wave_ai_system = WaveAISystemClass.new(world)

func get_current_tick() -> int:
	return world.server_tick

func enqueue_command(command: CommandEnvelopeClass) -> void:
	if command != null:
		_command_inbox.append(command)

func step_one_tick() -> Dictionary:
	world.server_tick += 1

	# Step 1: Inbox seal
	var sealed_commands := _command_inbox.duplicate()
	_command_inbox.clear()

	var receipts: Array[Dictionary] = []
	var events: Array[Dictionary] = []

	# Sort commands: server_tick -> player_id -> sequence
	sealed_commands.sort_custom(func(a, b):
		if a.player_id != b.player_id:
			return a.player_id < b.player_id
		return a.sequence < b.sequence
	)

	# Steps 2-10: Process commands by category
	for cmd in sealed_commands:
		var p_id: int = cmd.player_id
		var seq: int = cmd.sequence

		# Deduplication check
		var last_seq: int = int(_processed_sequences.get(p_id, 0))
		if seq != 0 and seq <= last_seq:
			receipts.append(CommandReceiptClass.new(
				p_id, seq, false, ProtocolConstantsClass.ReasonCode.RATE_LIMITED, world.server_tick, 0
			).to_dict())
			continue

		if seq != 0:
			_processed_sequences[p_id] = seq

		match cmd.command_type:
			ProtocolConstantsClass.CommandType.MOVE_INTENT:
				var axis = Vector2(float(cmd.payload.get("axis_x", 0.0)), float(cmd.payload.get("axis_y", 0.0)))
				movement_system.handle_move_intent(cmd.controlled_entity_id, axis)
				receipts.append(CommandReceiptClass.new(
					p_id, seq, true, ProtocolConstantsClass.ReasonCode.ACCEPTED, world.server_tick, 0
				).to_dict())

			ProtocolConstantsClass.CommandType.AIM_INTENT:
				var ent = world.get_entity(cmd.controlled_entity_id)
				if ent != null:
					ent.custom_data["aim_angle"] = float(cmd.payload.get("angle", 0.0))
				receipts.append(CommandReceiptClass.new(
					p_id, seq, true, ProtocolConstantsClass.ReasonCode.ACCEPTED, world.server_tick, 0
				).to_dict())

			ProtocolConstantsClass.CommandType.ABILITY_COMMAND:
				var ability: String = cmd.payload.get("ability_id", "")
				var raw_hint = cmd.payload.get("target_hint", [1.0, 0.0])
				var hint := Vector2(float(raw_hint[0]), float(raw_hint[1]))
				var accepted: bool = false
				match ability:
					"shoot":
						accepted = combat_system.handle_shoot(cmd.controlled_entity_id, hint, events)
					"melee":
						accepted = combat_system.handle_melee(cmd.controlled_entity_id, hint, events) > 0
					"dash":
						accepted = movement_system.handle_dash(cmd.controlled_entity_id, hint, events)

				receipts.append(CommandReceiptClass.new(
					p_id, seq, accepted,
					ProtocolConstantsClass.ReasonCode.ACCEPTED if accepted else ProtocolConstantsClass.ReasonCode.COOLDOWN,
					world.server_tick, 0
				).to_dict())

			ProtocolConstantsClass.CommandType.BUILD_COMMAND:
				var res = building_system.handle_build(cmd.payload, p_id)
				for ev in res.get("events", []):
					events.append(ev)
				receipts.append(CommandReceiptClass.new(
					p_id, seq, res["accepted"], res["reason"], world.server_tick, res.get("resulting_revision", 0)
				).to_dict())

			ProtocolConstantsClass.CommandType.REMOVE_BUILD_COMMAND:
				var res = building_system.handle_remove_build(cmd.payload, p_id)
				for ev in res.get("events", []):
					events.append(ev)
				receipts.append(CommandReceiptClass.new(
					p_id, seq, res["accepted"], res["reason"], world.server_tick, res.get("resulting_revision", 0)
				).to_dict())

			ProtocolConstantsClass.CommandType.PHASE_COMMAND:
				var res = session_system.handle_phase_command(cmd.payload, p_id)
				for ev in res.get("events", []):
					events.append(ev)
				receipts.append(CommandReceiptClass.new(
					p_id, seq, res["accepted"], res["reason"], world.server_tick, world.session_state.phase_revision
				).to_dict())

			ProtocolConstantsClass.CommandType.INVENTORY_COMMAND:
				var res = inventory_system.handle_inventory_command(cmd.payload, p_id)
				for ev in res.get("events", []):
					events.append(ev)
				receipts.append(CommandReceiptClass.new(
					p_id, seq, res["accepted"], res["reason"], world.server_tick, 0
				).to_dict())

	# Step 5: Advance movement physics
	movement_system.step_tick()

	# Step 9: Wave & AI logic
	wave_ai_system.step_tick(events)

	# Step 11: Lifecycle commit (remove despawned entities)
	var to_remove: Array[int] = []
	for e_id in world.entities:
		var e: EntityStateClass = world.entities[e_id]
		if e.lifecycle == EntityStateClass.Lifecycle.DESPAWNING:
			to_remove.append(e_id)
	for e_id in to_remove:
		world.remove_entity(e_id)

	# Step 12: Build StateDelta
	var delta := _build_state_delta()

	# Step 13: Rule Checksum
	var checksum := world.calculate_checksum()

	return {
		"server_tick": world.server_tick,
		"receipts": receipts,
		"events": events,
		"delta": delta,
		"checksum": checksum
	}

func _build_state_delta() -> Dictionary:
	var entity_deltas: Array[Dictionary] = []
	for e_id in world.entities:
		var e: EntityStateClass = world.entities[e_id]
		entity_deltas.append({
			"entity_id": e.entity_id,
			"position": [e.position.x, e.position.y],
			"velocity": [e.velocity.x, e.velocity.y],
			"health": e.health,
			"custom_data": e.custom_data.duplicate(true)
		})
	return {
		"server_tick": world.server_tick,
		"phase": world.session_state.phase,
		"phase_revision": world.session_state.phase_revision,
		"day": world.session_state.day,
		"grid_revision": world.build_grid.grid_revision,
		"entities": entity_deltas
	}

func capture_snapshot() -> Dictionary:
	return world.capture_snapshot()

func restore_snapshot(snap: Dictionary) -> void:
	world.restore_snapshot(snap)
	_processed_sequences.clear()
