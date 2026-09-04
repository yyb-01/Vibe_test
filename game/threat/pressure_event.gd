class_name PressureEvent
extends RefCounted

enum Lifecycle { PLANNED, TELEGRAPHED, ACTIVE, RESOLVED, RECOVERY }

var event_id: StringName
var source_fact_type: StringName
var started_tick: int = 0
var expiry_tick: int = 0
var severity: int = 1
var spawn_ticket_ids: Array = []
var lifecycle: Lifecycle = Lifecycle.PLANNED

func _init(next_event_id: StringName, next_source_fact_type: StringName, next_started_tick: int, duration_ticks: int, next_severity: int = 1) -> void:
	event_id = next_event_id
	source_fact_type = next_source_fact_type
	started_tick = next_started_tick
	expiry_tick = next_started_tick + maxi(1, duration_ticks)
	severity = maxi(1, next_severity)
