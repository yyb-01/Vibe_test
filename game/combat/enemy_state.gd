class_name EnemyState
extends RefCounted

enum Lifecycle { SPAWNING, SEEKING, MOVING, ATTACKING, RECOVERING, DYING, REMOVED }

var enemy_id: StringName
var definition_id: StringName
var cell: Vector2i
var path: Array = []
var path_index: int = 0
var attack_cooldown: int = 0
var attack_damage: int = 1
var attack_cooldown_ticks: int = 10
var lifecycle: Lifecycle = Lifecycle.SPAWNING

func _init(next_id: StringName, next_cell: Vector2i, next_definition_id: StringName = &"") -> void:
	enemy_id = next_id
	cell = next_cell
	definition_id = next_definition_id
