class_name ThreatState
extends RefCounted

var pressure: int = 0
var pressure_tier: int = 0
var active_event_id: StringName = &""
var recovery_until_tick: int = -1
var extraction_pressure: int = 0
var events: Dictionary = {}
var spawn_tickets: Dictionary = {}
var next_spawn_wave_index: int = 0
var revision: int = 0
