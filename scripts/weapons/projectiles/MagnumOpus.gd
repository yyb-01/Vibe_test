class_name MagnumOpus
extends "res://scripts/weapons/projectiles/RevolverBullet.gd"

const SHRAPNEL: PackedScene = preload("res://scenes/weapons/advanced/shrapnel_bullet.tscn")
var _crit_chance: float = 0.25

func on_spawn(init_direction: Vector2 = Vector2.RIGHT, init_damage: float = 1.0,
		init_source: Node = null, init_pierce: int = 4, extras: Dictionary = {}) -> void:
	super.on_spawn(init_direction, init_damage, init_source, maxi(4, init_pierce), extras)
	_crit_chance = clampf(float(extras.get("crit_chance", 0.25)), 0.0, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if not _can_hit(body):
		return
	if not body.is_in_group("enemies"):
		despawn()
		return
	hit_targets[body] = true
	var critical := randf() < _crit_chance
	var impact_position := body.global_position
	_apply_damage(body, damage * (1.8 if critical else 1.0), direction, "critical" if critical else "normal")
	if critical:
		for index in 8:
			var shard_direction := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
			spawn_effect(SHRAPNEL, impact_position, [shard_direction, damage * 0.35, source, 0, {"weapon_id": source_weapon_id}])
	remaining_pierce -= 1
	if remaining_pierce < 0:
		despawn()
