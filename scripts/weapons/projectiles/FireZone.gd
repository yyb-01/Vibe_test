class_name FireZone
extends Area2D

var _age: float = 0.0
var _duration: float = 1.5
var _tick: float = 0.0
var _interval: float = 0.2
var _damage: float = 1.0
var _color := Color(1.0, 0.28, 0.04, 1.0)
var _source: Node

func _ready() -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape != null:
		shape.shape = shape.shape.duplicate()

func on_spawn(init_damage: float = 1.0, radius: float = 42.0, init_source: Node = null,
		init_duration: float = 1.5, init_interval: float = 0.2,
		init_color: Color = Color(1.0, 0.28, 0.04, 1.0)) -> void:
	_age = 0.0
	_tick = 0.0
	_damage = maxf(0.0, init_damage)
	_duration = maxf(0.01, init_duration)
	_interval = maxf(0.05, init_interval)
	_source = init_source
	_color = init_color
	collision_layer = 0
	collision_mask = 4
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is CircleShape2D:
		(shape.shape as CircleShape2D).radius = maxf(radius, 4.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if get_meta("_pool_release_pending", false):
		return
	_age += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick += _interval
		for body in get_overlapping_bodies():
			if _is_live_enemy(body) and body.has_method("take_damage"):
				body.call("take_damage", maxi(1, roundi(_damage)), Vector2.ZERO, "fire", "잔류 화염")
	queue_redraw()
	if _age >= _duration:
		ObjectPoolManager.despawn(self)

func _is_live_enemy(body: Node) -> bool:
	var health = body.get("health") if is_instance_valid(body) else null
	return is_instance_valid(body) and not body.is_queued_for_deletion() and body.is_in_group("enemies") and health != null \
		and int(health) > 0 and not bool(body.get("is_dying"))

func on_despawn() -> void:
	_age = 0.0
	_source = null
	set_process(false)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

func _draw() -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var radius := 42.0
	if shape != null and shape.shape is CircleShape2D:
		radius = (shape.shape as CircleShape2D).radius
	draw_circle(Vector2.ZERO, radius, Color(_color, 0.15 + sin(_age * 12.0) * 0.03))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(_color, 0.75), 3.0, true)
