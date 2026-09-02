class_name PooledProjectile
extends "res://scripts/weapons/BaseProjectile.gd"

func _ready() -> void:
	super._ready()

func on_spawn(init_direction: Vector2 = Vector2.RIGHT, init_damage: float = 1.0,
		init_source: Node = null, init_pierce: int = -1, extras: Dictionary = {}) -> void:
	super.on_spawn(init_direction, init_damage, init_source, init_pierce, extras)
	collision_layer = 8
	collision_mask = 2 | 4
	set_meta("projectile_target", init_source)

func on_despawn() -> void:
	super.on_despawn()
	set_meta("projectile_target", null)

func _on_body_entered(body: Node2D) -> void:
	if not _can_hit(body):
		return
	if not body.is_in_group("enemies"):
		despawn()
		return
	hit_targets[body] = true
	_apply_damage(body, damage, direction)
	remaining_pierce -= 1
	if remaining_pierce < 0:
		despawn()
