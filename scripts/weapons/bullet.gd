class_name Bullet
extends Area2D

@export var speed: float = 600.0
var damage: int = 0
var direction: Vector2 = Vector2.ZERO
var pierce_count: int = 0
var hit_targets: Array[Node] = []
var critical_chance: float = 0.08
var impact_kind: String = "normal"
var execute_threshold: float = 0.0

var life_time: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	reset()

func reset() -> void:
	life_time = 0.0
	direction = Vector2.ZERO
	pierce_count = 0
	hit_targets.clear()
	critical_chance = 0.08
	impact_kind = "normal"
	execute_threshold = 0.0

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
		var is_critical := randf() < critical_chance
		var final_damage := roundi(float(damage) * (1.75 if is_critical else 1.0))
		var hit_kind := "critical" if is_critical else impact_kind
		var target_health = body.get("health")
		var target_max_health = body.get("max_health")
		if execute_threshold > 0.0 and target_health != null and target_max_health != null and float(target_health) / float(maxi(1, int(target_max_health))) <= execute_threshold:
			final_damage = int(target_health) + 1
			hit_kind = "execute"
		body.take_damage(final_damage, direction, hit_kind)
		if is_critical:
			AudioManager.play_named("impact", -9.0, randf_range(1.12, 1.26))
			EventBus.camera_shake_requested.emit(0.34)
		elif hit_kind == "execute":
			EventBus.camera_shake_requested.emit(0.7)
		elif hit_kind == "heavy":
			EventBus.camera_shake_requested.emit(0.2)
		var impact = ObjectPoolManager.acquire("blood_impact", body.global_position)
		if impact and impact.has_method("configure"):
			var color := Color(1.0, 0.9, 0.28, 1.0) if is_critical else (Color(0.3, 0.9, 1.0, 1.0) if impact_kind == "heavy" else Color(1.0, 0.2, 0.08, 1.0))
			impact.configure(color, 58.0 if is_critical or impact_kind == "heavy" else 38.0)

		# Handle Pierce
		pierce_count -= 1
		if pierce_count < 0:
			ObjectPoolManager.release(self)
	else:
		# Hit a non-damageable body (e.g. Wall)
		ObjectPoolManager.release(self)
