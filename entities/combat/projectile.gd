class_name Projectile
extends Area2D

# res://entities/combat/projectile.gd
# Ranged projectile moving in Canvas space with fast collision & raycast anti-tunneling per Section E.3

@export var speed: float = 650.0
@export var damage: float = 25.0
@export var lifetime: float = 2.0

var velocity: Vector2 = Vector2.ZERO
var shooter: Node = null

var _time_alive: float = 0.0

func _ready() -> void:
	# Layer 5: PlayerHit (16), Mask: Layer 1 (World=1) + Layer 3 (Enemy=4) -> 5
	collision_layer = 16
	collision_mask = 5
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(p_position: Vector2, p_direction: Vector2, p_damage: float, p_speed: float, p_shooter: Node = null) -> void:
	global_position = p_position
	if p_direction.length_squared() > 0.0:
		velocity = p_direction.normalized() * p_speed
		rotation = p_direction.angle()
	damage = p_damage
	speed = p_speed
	shooter = p_shooter

func _physics_process(delta: float) -> void:
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()
		return
		
	var step: Vector2 = velocity * delta
	
	# Anti-tunneling raycast query only when step exceeds threshold
	if step.length_squared() > 256.0:
		var space_state := get_world_2d().direct_space_state
		var excludes: Array[RID] = [get_rid()]
		if shooter is CollisionObject2D:
			excludes.append(shooter.get_rid())
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step, collision_mask, excludes)
		var result := space_state.intersect_ray(query)
		
		if not result.is_empty():
			global_position = result.position
			_handle_hit(result.collider)
			return
			
	global_position += step

func _on_body_entered(body: Node2D) -> void:
	if body != shooter:
		_handle_hit(body)

func _on_area_entered(area: Area2D) -> void:
	if area != shooter and area.owner != shooter:
		_handle_hit(area)

func _handle_hit(target: Object) -> void:
	if target == null:
		queue_free()
		return
		
	# Try HitboxComponent first
	if target.has_method("receive_damage"):
		target.receive_damage(damage, shooter)
	elif target is Node:
		var health = target.find_child("HealthComponent", true, false)
		if health != null and health.has_method("apply_damage"):
			health.apply_damage(damage, shooter)
			
	queue_free()
