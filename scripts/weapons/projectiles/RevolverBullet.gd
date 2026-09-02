class_name RevolverBullet
extends "res://scripts/weapons/BaseProjectile.gd"

func on_spawn(init_direction: Vector2 = Vector2.RIGHT, init_damage: float = 1.0,
		init_source: Node = null, init_pierce: int = 3, extras: Dictionary = {}) -> void:
	super.on_spawn(init_direction, init_damage, init_source, maxi(3, init_pierce), extras)
	speed = maxf(speed, 1150.0)
	max_lifetime = 2.0

