class_name ShotgunPellet
extends "res://scripts/weapons/BaseProjectile.gd"

var _origin: Vector2
var _falloff_distance: float = 420.0
var _knockback: float = 180.0

func on_spawn(init_direction: Vector2 = Vector2.RIGHT, init_damage: float = 1.0,
		init_source: Node = null, init_pierce: int = 0, extras: Dictionary = {}) -> void:
	super.on_spawn(init_direction, init_damage, init_source, init_pierce, extras)
	_origin = global_position
	_falloff_distance = maxf(float(extras.get("max_distance", 420.0)), 1.0)
	_knockback = maxf(float(extras.get("knockback", 180.0)), 0.0)

func _on_body_entered(body: Node2D) -> void:
	if not _can_hit(body):
		return
	if not body.is_in_group("enemies"):
		despawn()
		return
	hit_targets[body] = true
	var falloff := clampf(1.0 - _origin.distance_to(body.global_position) / _falloff_distance, 0.25, 1.0)
	_apply_damage(body, damage * falloff, direction, "heavy")
	add_knockback(body, _knockback * falloff, direction)
	remaining_pierce -= 1
	if remaining_pierce < 0:
		despawn()

