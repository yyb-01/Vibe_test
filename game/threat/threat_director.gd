class_name ThreatDirector
extends Node

const PressureEventClass = preload("res://game/threat/pressure_event.gd")
const SpawnTicketClass = preload("res://game/threat/spawn_ticket.gd")
const ThreatStateClass = preload("res://game/threat/threat_state.gd")

signal pressure_event_created(event_id: StringName)
signal spawn_ticket_created(ticket)

@onready var telegraph = get_node("../World/Telegraph")

var state
var operation_id: StringName
var fact_types: Array = []
var pressure_per_action: int = 1
var pressure_threshold: int = 1
var event_duration_ticks: int = 1
var spawn_waves: Array = []
var enabled: bool = false
var _sequence: int = 0
var _current_tick: int = 0

func setup(next_operation_id: StringName, next_fact_types: Array, next_pressure_per_action: int, next_pressure_threshold: int, next_event_duration_ticks: int, next_spawn_waves: Array = []) -> bool:
	if String(next_operation_id).is_empty() or next_fact_types.is_empty() or next_pressure_per_action <= 0 or next_pressure_threshold <= 0 or next_event_duration_ticks <= 0:
		return false
	operation_id = next_operation_id
	fact_types = next_fact_types.duplicate()
	pressure_per_action = next_pressure_per_action
	pressure_threshold = next_pressure_threshold
	event_duration_ticks = next_event_duration_ticks
	spawn_waves = next_spawn_waves.duplicate(true)
	state = ThreatStateClass.new()
	_sequence = 0
	_current_tick = 0
	enabled = false
	telegraph.clear()
	return true

func set_enabled(next_enabled: bool) -> void:
	enabled = next_enabled
	if not enabled:
		telegraph.clear()

func accept_facts(facts: Array, current_tick: int) -> void:
	if not enabled or state == null:
		return
	var source_fact_type: StringName = &""
	for fact in facts:
		if fact != null and fact.operation_id == operation_id and fact_types.has(fact.fact_type):
			source_fact_type = fact.fact_type
			break
	if String(source_fact_type).is_empty():
		return
	var previous_tier: int = state.pressure_tier
	state.pressure += pressure_per_action
	state.pressure_tier = state.pressure / pressure_threshold
	state.revision += 1
	if String(state.active_event_id).is_empty() and state.pressure_tier > previous_tier:
		_create_event(source_fact_type, current_tick)

func start_extraction_pressure(current_tick: int) -> void:
	if state == null:
		return
	state.extraction_pressure = maxi(1, state.extraction_pressure + 1)
	state.revision += 1
	if enabled and String(state.active_event_id).is_empty():
		_create_event(&"EXTRACTION_REQUESTED", current_tick)

func advance_tick(current_tick: int) -> void:
	if not enabled or state == null:
		return
	_current_tick = current_tick
	if String(state.active_event_id).is_empty():
		if state.recovery_until_tick >= 0 and current_tick >= state.recovery_until_tick:
			for event in state.events.values():
				if event.lifecycle == PressureEventClass.Lifecycle.RESOLVED:
					event.lifecycle = PressureEventClass.Lifecycle.RECOVERY
			state.recovery_until_tick = -1
			state.revision += 1
		return
	var event = state.events.get(state.active_event_id)
	if event == null:
		state.active_event_id = &""
		return
	if event.lifecycle == PressureEventClass.Lifecycle.TELEGRAPHED:
		event.lifecycle = PressureEventClass.Lifecycle.ACTIVE
		_issue_spawn_ticket(event)
		state.revision += 1
	if current_tick >= event.expiry_tick:
		telegraph.clear()
		_try_resolve_event(event, current_tick)
	else:
		telegraph.update_progress(current_tick, event.expiry_tick)

func _create_event(source_fact_type: StringName, current_tick: int) -> void:
	_sequence += 1
	var event_id := StringName("pressure_%d" % _sequence)
	var event = PressureEventClass.new(event_id, source_fact_type, current_tick, event_duration_ticks)
	event.lifecycle = PressureEventClass.Lifecycle.TELEGRAPHED
	state.events[event_id] = event
	state.active_event_id = event_id
	state.revision += 1
	telegraph.configure(event_id, current_tick, event_duration_ticks, event.severity)
	pressure_event_created.emit(event_id)

func bind_spawn_ticket(ticket_id: StringName, enemy_ids: Array) -> bool:
	if state == null:
		return false
	var ticket = state.spawn_tickets.get(ticket_id)
	if ticket == null or ticket.lifecycle != SpawnTicketClass.Lifecycle.ACTIVE or enemy_ids.is_empty():
		return false
	ticket.enemy_ids = enemy_ids.duplicate()
	ticket.defeated_enemy_ids.clear()
	state.revision += 1
	return true

func cancel_spawn_ticket(ticket_id: StringName) -> bool:
	return _finish_spawn_ticket(ticket_id, SpawnTicketClass.Lifecycle.CANCELLED)

func mark_enemy_defeated(enemy_id: StringName) -> void:
	if state == null:
		return
	for ticket in state.spawn_tickets.values():
		if ticket.lifecycle != SpawnTicketClass.Lifecycle.ACTIVE or not ticket.enemy_ids.has(enemy_id):
			continue
		if not ticket.defeated_enemy_ids.has(enemy_id):
			ticket.defeated_enemy_ids.append(enemy_id)
			state.revision += 1
		if ticket.defeated_enemy_ids.size() >= ticket.enemy_ids.size():
			ticket.lifecycle = SpawnTicketClass.Lifecycle.RESOLVED
			state.revision += 1
			var event = state.events.get(ticket.pressure_event_id)
			if event != null:
				_try_resolve_event(event, _current_tick)

func _issue_spawn_ticket(event) -> void:
	if state.next_spawn_wave_index >= spawn_waves.size():
		return
	var wave: Dictionary = spawn_waves[state.next_spawn_wave_index] if typeof(spawn_waves[state.next_spawn_wave_index]) == TYPE_DICTIONARY else {}
	var required_tier := int(wave.get("pressure_tier", 0))
	if required_tier > state.pressure_tier:
		return
	var wave_id := StringName(wave.get("id", ""))
	var entries = wave.get("spawn_entries", [])
	if String(wave_id).is_empty() or typeof(entries) != TYPE_ARRAY or entries.is_empty():
		return
	state.next_spawn_wave_index += 1
	var ticket_id := StringName("spawn_%s" % String(event.event_id))
	var ticket = SpawnTicketClass.new(ticket_id, event.event_id, wave_id, entries)
	ticket.spawn_region = StringName(wave.get("spawn_region", "outer_ring"))
	ticket.target_policy_id = StringName(wave.get("target_policy_id", "protected_core"))
	ticket.lifecycle = SpawnTicketClass.Lifecycle.ACTIVE
	state.spawn_tickets[ticket_id] = ticket
	event.spawn_ticket_ids.append(ticket_id)
	state.revision += 1
	spawn_ticket_created.emit(ticket)

func _finish_spawn_ticket(ticket_id: StringName, next_lifecycle: int) -> bool:
	if state == null:
		return false
	var ticket = state.spawn_tickets.get(ticket_id)
	if ticket == null or ticket.lifecycle != SpawnTicketClass.Lifecycle.ACTIVE:
		return false
	ticket.lifecycle = next_lifecycle
	state.revision += 1
	var event = state.events.get(ticket.pressure_event_id)
	if event != null:
		_try_resolve_event(event, _current_tick)
	return true

func _try_resolve_event(event, current_tick: int) -> void:
	if event.lifecycle != PressureEventClass.Lifecycle.ACTIVE or current_tick < event.expiry_tick:
		return
	for ticket_id in event.spawn_ticket_ids:
		var ticket = state.spawn_tickets.get(ticket_id)
		if ticket != null and ticket.lifecycle == SpawnTicketClass.Lifecycle.ACTIVE:
			return
	event.lifecycle = PressureEventClass.Lifecycle.RESOLVED
	state.active_event_id = &""
	state.recovery_until_tick = current_tick + event_duration_ticks
	state.revision += 1
