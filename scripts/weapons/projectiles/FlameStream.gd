class_name FlameStream
extends "res://scripts/weapons/BaseProjectile.gd"

var _age: float = 0.0
var _tick: float = 0.0
var _fan_angle: float = 42.0
var _area_scale: float = 1.0
var _base_sprite_scale := Vector2.ONE
var _last_hit: Dictionary = {}
var _slowed: Dictionary = {}

func _ready() -> void:
	super._ready()
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape != null:
		shape.shape = shape.shape.duplicate()
	var flame_sprite := get_node_or_null("Sprite2D") as Sprite2D
	if flame_sprite != null:
		_base_sprite_scale = flame_sprite.scale

func on_spawn(init_direction: Vector2 = Vector2.RIGHT, init_damage: float = 1.0,
		init_source: Node = null, _init_pierce: int = 999, extras: Dictionary = {}) -> void:
	super.on_spawn(init_direction, init_damage, init_source, 999, extras)
	_age = 0.0
	_tick = 0.0
	_fan_angle = float(extras.get("fan_angle", 42.0))
	_area_scale = maxf(float(extras.get("area_scale", 1.0)), 0.1)
	max_distance = maxf(float(extras.get("max_distance", 280.0)), 1.0)
	speed = maxf(speed, 340.0)
	_last_hit.clear()
	_slowed.clear()

func _physics_process(delta: float) -> void:
	if get_meta("_pool_release_pending", false):
		return
	_age += delta
	lifetime += delta
	_restore_slow_targets()
	if lifetime >= max_lifetime or distance_traveled >= max_distance:
		despawn()
		return
	var step := speed * delta
	global_position += direction * step
	distance_traveled += step
	rotation = direction.angle()
	var growth := clampf(distance_traveled / max_distance, 0.0, 1.0)
	var radius := lerpf(16.0, 74.0, growth) * _area_scale
	var flame_sprite := get_node_or_null("Sprite2D") as Sprite2D
	if flame_sprite != null:
		flame_sprite.scale = _base_sprite_scale * lerpf(0.55, 1.6, growth)
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is CircleShape2D:
		(shape.shape as CircleShape2D).radius = radius
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.12
		_apply_cone_damage(radius)

func _apply_cone_damage(radius: float) -> void:
	var half_angle := cos(deg_to_rad(_fan_angle * 0.5))
	for body in get_overlapping_bodies():
		if not body is Node2D or not _is_live_enemy(body as Node2D):
			continue
		var target := body as Node2D
		var offset := target.global_position - global_position
		if offset.length_squared() > radius * radius or direction.dot(offset.normalized()) < half_angle:
			continue
		var previous: float = float(_last_hit.get(target, -INF))
		if _age - previous < 0.12:
			continue
		_last_hit[target] = _age
		_on_flame_hit(target)

func _on_flame_hit(target: Node2D) -> void:
	_apply_damage(target, damage, direction, "fire")
	if not _is_live_enemy(target):
		return
	_apply_slow(target)

func _apply_slow(target: Node2D) -> void:
	if not _is_live_enemy(target):
		return
	if target.has_method("apply_slow"):
		target.call("apply_slow", 0.7, 0.45)
		return
	var current = target.get("move_speed")
	if current == null:
		return
	if not _slowed.has(target):
		_slowed[target] = [float(current), _age + 0.45]
		target.set("move_speed", float(current) * 0.7)
	else:
		var state: Array = _slowed[target]
		state[1] = _age + 0.45

func _restore_slow_targets() -> void:
	for target in _slowed.keys():
		var state: Array = _slowed[target]
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			_slowed.erase(target)
		elif _age >= float(state[1]):
			target.set("move_speed", state[0])
			_slowed.erase(target)

func _is_live_enemy(target: Node2D) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	var health = target.get("health")
	return target.is_in_group("enemies") and health != null \
		and int(health) > 0 and not bool(target.get("is_dying"))

func _on_body_entered(body: Node2D) -> void:
	# Enemy hits are sampled above; only a world body ends the stream.
	if is_instance_valid(body) and not body.is_in_group("enemies"):
		despawn()

func on_despawn() -> void:
	_restore_all_slow_targets()
	_slowed.clear()
	_last_hit.clear()
	_age = 0.0
	scale = Vector2.ONE
	var flame_sprite := get_node_or_null("Sprite2D") as Sprite2D
	if flame_sprite != null:
		flame_sprite.scale = _base_sprite_scale
	super.on_despawn()

func _restore_all_slow_targets() -> void:
	for target in _slowed.keys():
		if is_instance_valid(target) and not target.is_queued_for_deletion():
			var state: Array = _slowed[target]
			target.set("move_speed", state[0])
