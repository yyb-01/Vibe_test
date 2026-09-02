class_name Explosion
extends Area2D

var _age: float = 0.0
var _radius: float = 72.0
var _damage: float = 1.0
var _knockback: float = 0.0
var _color := Color(1.0, 0.38, 0.08, 1.0)
var _source: Node
var _applied: bool = false
var _generation: int = 0

func _ready() -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape != null:
		shape.shape = shape.shape.duplicate()

func on_spawn(radius: float = 72.0, init_damage: float = 1.0, init_source: Node = null,
		init_knockback: float = 0.0, init_color: Color = Color(1.0, 0.38, 0.08, 1.0)) -> void:
	_age = 0.0
	_radius = maxf(4.0, radius)
	_damage = maxf(0.0, init_damage)
	_source = init_source
	_knockback = maxf(0.0, init_knockback)
	_color = init_color
	_applied = false
	_generation += 1
	collision_layer = 0
	collision_mask = 4
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is CircleShape2D:
		(shape.shape as CircleShape2D).radius = _radius
	call_deferred("_apply_once", _generation)
	queue_redraw()

func _apply_once(generation: int) -> void:
	if generation != _generation or _applied or get_meta("_pool_release_pending", false):
		return
	_applied = true
	var bodies: Array = []
	for body in get_overlapping_bodies():
		bodies.append(body)
	if bodies.is_empty():
		var grid := get_node_or_null("/root/SpatialGrid")
		if is_instance_valid(grid) and grid.has_method("get_nearby_entities"):
			var nearby = grid.call("get_nearby_entities", global_position, _radius)
			if nearby is Array:
				bodies = nearby
	for body in bodies:
		if not _is_live_enemy(body):
			continue
		var target := body as Node2D
		var target_position := target.global_position
		var direction := global_position.direction_to(target_position)
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		if _damage > 0.0 and target.has_method("take_damage"):
			target.call("take_damage", maxi(1, roundi(_damage)), direction, "explosion", "폭발")
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		if _knockback > 0.0:
			if target.has_method("apply_knockback"):
				target.call("apply_knockback", direction * _knockback)
			elif target.get("knockback") is Vector2:
				target.set("knockback", target.get("knockback") + direction * _knockback)

func _physics_process(delta: float) -> void:
	if get_meta("_pool_release_pending", false):
		return
	_age += delta
	queue_redraw()
	if _age >= 0.14:
		ObjectPoolManager.despawn(self)

func _is_live_enemy(body: Node) -> bool:
	if not body is Node2D or not is_instance_valid(body) or body.is_queued_for_deletion():
		return false
	var health = body.get("health")
	return body.is_in_group("enemies") and health != null \
		and int(health) > 0 and not bool(body.get("is_dying")) \
		and global_position.distance_squared_to(body.global_position) <= _radius * _radius

func on_despawn() -> void:
	_age = 0.0
	_applied = false
	_source = null
	set_process(false)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

func _draw() -> void:
	var progress := clampf(_age / 0.14, 0.0, 1.0)
	draw_circle(Vector2.ZERO, _radius * (0.55 + progress * 0.45), Color(_color, 0.22 * (1.0 - progress)))
	draw_arc(Vector2.ZERO, _radius * (0.55 + progress * 0.45), 0.0, TAU, 48, Color(_color, 1.0 - progress), 5.0, true)
