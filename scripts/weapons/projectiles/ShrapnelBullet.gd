class_name ShrapnelBullet
extends "res://scripts/weapons/BaseProjectile.gd"

func on_spawn(init_direction: Vector2 = Vector2.RIGHT, init_damage: float = 1.0,
		init_source: Node = null, _init_pierce: int = 0, extras: Dictionary = {}) -> void:
	super.on_spawn(init_direction, init_damage, init_source, 0, extras)
	speed = maxf(speed, 560.0)
	max_distance = 320.0

