class_name ClusterBomblet
extends "res://scripts/weapons/BaseProjectile.gd"

const EXPLOSION: PackedScene = preload("res://scenes/weapons/advanced/explosion.tscn")
var _age: float = 0.0
var _fuse: float = 0.4
var _target_position: Vector2 = Vector2.ZERO
var _exploded: bool = false
var _knockback: float = 160.0

func on_spawn(init_direction: Vector2 = Vector2.RIGHT, init_damage: float = 1.0,
		init_source: Node = null, _init_pierce: int = 0, extras: Dictionary = {}) -> void:
	super.on_spawn(init_direction, init_damage, init_source, 0, extras)
	_age = 0.0
	_fuse = clampf(float(extras.get("fuse", 0.4)), 0.3, 0.5)
	_target_position = extras.get("target_position", global_position + direction * 48.0)
	_knockback = maxf(float(extras.get("knockback", 160.0)), 0.0)
	_exploded = false
	var distance := global_position.distance_to(_target_position)
	speed = distance / _fuse if distance > 1.0 else 1.0
	max_distance = distance + 4.0

func _physics_process(delta: float) -> void:
	if get_meta("_pool_release_pending", false) or _exploded:
		return
	_age += delta
	if _age >= _fuse:
		global_position = _target_position
		_explode()
		return
	var step := speed * delta
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
		[52.0, damage, source, _knockback, Color(0.72, 0.44, 1.0, 1.0)])
	despawn()

func on_despawn() -> void:
	_exploded = false
	_age = 0.0
	super.on_despawn()

