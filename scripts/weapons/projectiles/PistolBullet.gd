class_name PistolBullet
extends "res://scripts/weapons/BaseProjectile.gd"

func on_spawn(init_direction: Vector2 = Vector2.RIGHT, init_damage: float = 1.0,
		init_source: Node = null, _init_pierce: int = 0, extras: Dictionary = {}) -> void:
	super.on_spawn(init_direction, init_damage, init_source, 0, extras)
	remaining_pierce = 0

func _on_body_entered(body: Node2D) -> void:
	if not _can_hit(body):
		return
	if not body.is_in_group("enemies"):
		despawn()
		return
	hit_targets[body] = true
	_apply_damage(body, damage, direction)
	despawn()

