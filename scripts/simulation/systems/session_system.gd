class_name SessionSystem
extends RefCounted

# res://scripts/simulation/systems/session_system.gd
# Authoritatively executes session state machine, day rollover, defeat rollback, and failure settlements.

const GameStateMachineClass = preload("res://scripts/core/game_state_machine.gd")
const ProtocolConstantsClass = preload("res://scripts/application/protocol/protocol_constants.gd")
const DomainEventsClass = preload("res://scripts/simulation/events/domain_events.gd")
const SimulationWorldClass = preload("res://scripts/simulation/model/simulation_world.gd")

var world: SimulationWorldClass

func _init(p_world: SimulationWorldClass) -> void:
	world = p_world

func handle_phase_command(payload: Dictionary, player_id: int) -> Dictionary:
	var action_id: String = payload.get("action_id", "")
	var exp_rev: int = int(payload.get("expected_phase_revision", -1))
	var s_state = world.session_state

	if exp_rev != -1 and exp_rev != s_state.phase_revision:
		return {
			"accepted": false,
			"reason": ProtocolConstantsClass.ReasonCode.STALE_REVISION,
			"events": []
		}

	var events: Array[Dictionary] = []

	match action_id:
		"select_map", "request_expedition":
			if s_state.phase != GameStateMachineClass.State.HUB:
				return {"accepted": false, "reason": ProtocolConstantsClass.ReasonCode.INVALID_STATE, "events": []}
			s_state.day_stats["items_harvested"].clear()
			_transition_to(GameStateMachineClass.State.EXPEDITION, events)
			return {"accepted": true, "reason": ProtocolConstantsClass.ReasonCode.ACCEPTED, "events": events}

		"complete_expedition":
			if s_state.phase != GameStateMachineClass.State.EXPEDITION:
				return {"accepted": false, "reason": ProtocolConstantsClass.ReasonCode.INVALID_STATE, "events": []}
			var success: bool = bool(payload.get("success", true))
			var p_state = world.players.get(player_id, null)
			if success:
				# Transfer bag to shared storage
				if p_state != null:
					for slot in p_state.expedition_bag_slots:
						var item_id: StringName = slot.get("item_id", &"")
						var amount: int = int(slot.get("amount", 0))
						if item_id != &"" and amount > 0:
							s_state.shared_storage[item_id] = int(s_state.shared_storage.get(item_id, 0)) + amount
							s_state.day_stats["items_harvested"][str(item_id)] = int(s_state.day_stats["items_harvested"].get(str(item_id), 0)) + amount
						slot["item_id"] = &""
						slot["amount"] = 0
				_transition_to(GameStateMachineClass.State.EVENING_PREP, events)
			else:
				# Failure settlement (10% legacy scrap)
				var lost_count: int = 0
				if p_state != null:
					for slot in p_state.expedition_bag_slots:
						lost_count += int(slot.get("amount", 0))
						slot["item_id"] = &""
						slot["amount"] = 0
				var scrap_gain: int = maxi(1, int(ceil(lost_count * 0.1)))
				s_state.legacy_scrap += scrap_gain
				s_state.last_day_result = {
					"day": s_state.day,
					"survived": false,
					"reason": "expedition_failed",
					"legacy_scrap_earned": scrap_gain,
					"stats": s_state.day_stats.duplicate(true)
				}
				_transition_to(GameStateMachineClass.State.DAY_SUMMARY, events)
			return {"accepted": true, "reason": ProtocolConstantsClass.ReasonCode.ACCEPTED, "events": events}

		"start_night":
			if s_state.phase != GameStateMachineClass.State.EVENING_PREP:
				return {"accepted": false, "reason": ProtocolConstantsClass.ReasonCode.INVALID_STATE, "events": []}
			_transition_to(GameStateMachineClass.State.NIGHT_DEFENSE, events)
			return {"accepted": true, "reason": ProtocolConstantsClass.ReasonCode.ACCEPTED, "events": events}

		"complete_night":
			if s_state.phase != GameStateMachineClass.State.NIGHT_DEFENSE:
				return {"accepted": false, "reason": ProtocolConstantsClass.ReasonCode.INVALID_STATE, "events": []}
			var survived: bool = bool(payload.get("survived", true))
			if survived:
				s_state.last_day_result = {
					"day": s_state.day,
					"survived": true,
					"reason": "victory",
					"legacy_scrap_earned": 0,
					"stats": s_state.day_stats.duplicate(true)
				}
			else:
				var total_storage: int = 0
				for k in s_state.shared_storage:
					total_storage += int(s_state.shared_storage[k])
				var scrap_gain: int = maxi(1, int(ceil(total_storage * 0.1)))
				s_state.legacy_scrap += scrap_gain
				s_state.last_day_result = {
					"day": s_state.day,
					"survived": false,
					"reason": "night_defense_failed",
					"legacy_scrap_earned": scrap_gain,
					"stats": s_state.day_stats.duplicate(true)
				}
			_transition_to(GameStateMachineClass.State.DAY_SUMMARY, events)
			return {"accepted": true, "reason": ProtocolConstantsClass.ReasonCode.ACCEPTED, "events": events}

		"confirm_summary":
			if s_state.phase != GameStateMachineClass.State.DAY_SUMMARY:
				return {"accepted": false, "reason": ProtocolConstantsClass.ReasonCode.INVALID_STATE, "events": []}
			var survived: bool = bool(s_state.last_day_result.get("survived", true))
			if survived:
				s_state.day += 1
			else:
				_rollback_to_day_start_snapshot()
			_reset_day_stats()
			_transition_to(GameStateMachineClass.State.HUB, events)
			_create_day_start_snapshot()
			return {"accepted": true, "reason": ProtocolConstantsClass.ReasonCode.ACCEPTED, "events": events}

	return {"accepted": false, "reason": ProtocolConstantsClass.ReasonCode.INVALID_STATE, "events": []}

func _transition_to(target_phase: int, events: Array[Dictionary]) -> void:
	var prev: int = world.session_state.phase
	world.session_state.phase = target_phase
	world.session_state.phase_revision += 1
	var ev_id = world.id_generator.generate_event_id()
	events.append(DomainEventsClass.create_event(
		ev_id,
		world.server_tick,
		DomainEventsClass.EventType.PHASE_CHANGED,
		{
			"previous_phase": prev,
			"current_phase": target_phase,
			"phase_revision": world.session_state.phase_revision,
			"day": world.session_state.day
		}
	))

func _create_day_start_snapshot() -> void:
	world.day_start_snapshot = {
		"day": world.session_state.day,
		"shared_storage": world.session_state.shared_storage.duplicate(true),
		"unlocked_blueprints": world.session_state.unlocked_blueprints.duplicate(),
		"legacy_scrap": world.session_state.legacy_scrap,
		"build_grid": world.build_grid.to_dict()
	}

func _rollback_to_day_start_snapshot() -> void:
	if world.day_start_snapshot.is_empty():
		return
	world.session_state.day = int(world.day_start_snapshot.get("day", world.session_state.day))
	var saved_storage = world.day_start_snapshot.get("shared_storage", {})
	world.session_state.shared_storage.clear()
	for k in saved_storage:
		world.session_state.shared_storage[StringName(k)] = int(saved_storage[k])
	# Restore build grid
	if world.day_start_snapshot.has("build_grid"):
		world.build_grid.from_dict(world.day_start_snapshot["build_grid"])

func _reset_day_stats() -> void:
	world.session_state.day_stats = {
		"zombies_killed": 0,
		"ammo_consumed": 0,
		"structures_lost": 0,
		"items_harvested": {}
	}
