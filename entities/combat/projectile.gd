class_name Projectile
extends Area2D

const JuiceHelperClass = preload("res://scripts/systems/juice_helper.gd")

@export var speed: float = 650.0
@export var damage: float = 25.0
@export var lifetime: float = 2.0

var velocity: Vector2 = Vector2.ZERO
var shooter: Node = null
var pool: Node = null
var critical: bool = false

@onready var trail: Line2D = get_node_or_null("Trail")

var _time_alive: float = 0.0
var _active: bool = true
var _has_hit: bool = false

func _ready() -> void:
	collision_layer = 16
	collision_mask = 5
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(p_position: Vector2, p_direction: Vector2, p_damage: float, p_speed: float, p_shooter: Node = null, p_critical: bool = false) -> void:
	global_position = p_position
	velocity = p_direction.normalized() * p_speed if p_direction.length_squared() > 0.0 else Vector2.ZERO
	rotation = p_direction.angle()
	damage = p_damage
	speed = p_speed
	shooter = p_shooter
	critical = p_critical
	_time_alive = 0.0
	_has_hit = false
	_active = true
	visible = true
	monitoring = true
	monitorable = true
	set_physics_process(true)
	if trail != null:
		trail.clear_points()
		trail.add_point(Vector2.ZERO)
		trail.add_point(-velocity.normalized() * 20.0)

func deactivate() -> void:
	_active = false
	_has_hit = false
	velocity = Vector2.ZERO
	shooter = null
	critical = false
	monitoring = false
	monitorable = false
	visible = false
	set_physics_process(false)
	if trail != null:
		trail.clear_points()

func _physics_process(delta: float) -> void:
	if not _active:
		return
	_time_alive += delta
	if _time_alive >= lifetime:
		_release()
		return

	var step := velocity * delta
	if step.length_squared() > 0.0:
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step, collision_mask, _get_excludes())
		query.collide_with_bodies = true
		query.collide_with_areas = true
		var result := get_world_2d().direct_space_state.intersect_ray(query)
		if not result.is_empty():
			global_position = result.position
			_handle_hit(result.collider)
			return
	global_position += step
	if trail != null:
		trail.set_point_position(0, Vector2.ZERO)
		trail.set_point_position(1, -velocity.normalized() * 20.0)

func _get_excludes() -> Array[RID]:
	var excludes: Array[RID] = [get_rid()]
	if shooter is CollisionObject2D:
		excludes.append((shooter as CollisionObject2D).get_rid())
	return excludes

func _on_body_entered(body: Node2D) -> void:
	if _active and body != shooter:
		_handle_hit(body)

func _on_area_entered(area: Area2D) -> void:
	if _active and area != shooter and area.owner != shooter:
		_handle_hit(area)

func _handle_hit(target: Object) -> void:
	if not _active or _has_hit:
		return
	_has_hit = true
	var applied := false
	if target != null:
		if target.has_method("receive_damage"):
			applied = target.receive_damage(damage, self)
		elif target is Node:
			var health = (target as Node).find_child("HealthComponent", true, false)
			if health != null and health.has_method("apply_damage"):
				applied = health.apply_damage(damage, self)
	if applied:
		JuiceHelperClass.hitstop(self, 0.045 if critical else 0.035)
	_release()

func _release() -> void:
	if pool != null and pool.has_method("release"):
		pool.release(self)
	else:
		deactivate()
		queue_free()
