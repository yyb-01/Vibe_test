class_name RocketMissile
extends "res://scripts/weapons/BaseProjectile.gd"

const EXPLOSION: PackedScene = preload("res://scenes/weapons/advanced/explosion.tscn")
var _has_target_position: bool = false
var _target_position: Vector2 = Vector2.ZERO
var _exploded: bool = false
var _area_scale: float = 1.0
var _knockback: float = 260.0

func on_spawn(init_direction: Vector2 = Vector2.RIGHT, init_damage: float = 1.0,
		init_source: Node = null, _init_pierce: int = 0, extras: Dictionary = {}) -> void:
	super.on_spawn(init_direction, init_damage, init_source, 0, extras)
	_has_target_position = extras.get("target_position") is Vector2
	_target_position = extras.get("target_position", Vector2.ZERO)
	_area_scale = maxf(float(extras.get("area_scale", 1.0)), 0.1)
	_knockback = maxf(float(extras.get("knockback", 260.0)), 0.0)
	_exploded = false
	speed = maxf(speed, 540.0)
	max_distance = 1600.0

func _physics_process(delta: float) -> void:
	if get_meta("_pool_release_pending", false) or _exploded:
		return
	lifetime += delta
	if lifetime >= max_lifetime or distance_traveled >= max_distance:
		_explode()
		return
	var step := speed * delta
	if _has_target_position:
		var to_target := global_position.direction_to(_target_position)
		if global_position.distance_to(_target_position) <= step:
			global_position = _target_position
			_explode()
			return
		direction = to_target
	global_position += direction * step
	distance_traveled += step
	rotation = direction.angle()

func _on_body_entered(_body: Node2D) -> void:
	_explode()

func _explode() -> void:
	if _exploded or get_meta("_pool_release_pending", false):
		return
	_exploded = true
	spawn_effect(EXPLOSION, global_position,
		[82.0 * _area_scale, damage, source, _knockback, Color(1.0, 0.38, 0.08, 1.0)])
	despawn()

func on_despawn() -> void:
	_exploded = false
	_has_target_position = false
	_target_position = Vector2.ZERO
	super.on_despawn()

