class_name Bullet
extends Area2D

@export var speed: float = 600.0
var damage: int = 0
var direction: Vector2 = Vector2.ZERO
var pierce_count: int = 0
var hit_targets: Array[Node] = []

var life_time: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	reset()

func reset() -> void:
	life_time = 0.0
	direction = Vector2.ZERO
	pierce_count = 0
	hit_targets.clear()

func _physics_process(delta: float) -> void:
	life_time += delta
	if life_time >= 2.0:
		ObjectPoolManager.release(self)
		return

	position += direction * speed * delta
	rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	if hit_targets.has(body):
		return

	if body.has_method("take_damage"):
		hit_targets.append(body)
		body.take_damage(damage, direction)
		var impact = ObjectPoolManager.acquire("blood_impact", body.global_position)
		if impact and impact.has_method("configure"):
			impact.configure(Color(1.0, 0.2, 0.08, 1.0), 38.0)

		# Handle Pierce
		pierce_count -= 1
		if pierce_count < 0:
			ObjectPoolManager.release(self)
	else:
		# Hit a non-damageable body (e.g. Wall)
		ObjectPoolManager.release(self)
