class_name SpawnTicket
extends RefCounted

enum Lifecycle { PLANNED, ACTIVE, RESOLVED, CANCELLED }

var ticket_id: StringName
var pressure_event_id: StringName
var enemy_pool_id: StringName
var spawn_region: StringName = &"outer_ring"
var target_policy_id: StringName = &"protected_core"
var rng_state_reference: StringName
var spawn_entries: Array = []
var enemy_ids: Array = []
var defeated_enemy_ids: Array = []
var lifecycle: Lifecycle = Lifecycle.PLANNED

func _init(next_id: StringName, next_event_id: StringName, next_enemy_pool_id: StringName, next_entries: Array) -> void:
	ticket_id = next_id
	pressure_event_id = next_event_id
	enemy_pool_id = next_enemy_pool_id
	rng_state_reference = next_id
	spawn_entries = next_entries.duplicate(true)
