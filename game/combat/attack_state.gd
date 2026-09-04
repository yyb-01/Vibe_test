class_name AttackState
extends RefCounted

enum Lifecycle { REQUESTED, RESOLVED }

var attack_id: StringName
var actor_id: StringName
var target_id: StringName
var damage: int
var issued_tick: int
var lifecycle: Lifecycle = Lifecycle.REQUESTED

func _init(next_id: StringName, next_actor: StringName, next_target: StringName, next_damage: int, next_tick: int) -> void:
	attack_id = next_id
	actor_id = next_actor
	target_id = next_target
	damage = next_damage
	issued_tick = next_tick
