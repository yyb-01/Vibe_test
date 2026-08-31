class_name AcidProjectile
extends Area2D

@export var speed: float = 260.0
var direction: Vector2 = Vector2.ZERO
var damage: int = 8
var life_time: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	reset()

func reset() -> void:
	direction = Vector2.ZERO
	damage = 8
	life_time = 0.0
	rotation = 0.0

func _physics_process(delta: float) -> void:
	life_time += delta
	if life_time >= 3.0:
		ObjectPoolManager.release(self)
		return
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage, direction)
		ObjectPoolManager.release(self)
	elif not body.is_in_group("enemies"):
		ObjectPoolManager.release(self)
