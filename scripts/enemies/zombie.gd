class_name Zombie
extends CharacterBody2D

@export var max_health: int = 30
@export var move_speed: float = 100.0
@export var attack_damage: int = 10
@export var attack_range: float = 75.0
@export var attack_cooldown: float = 1.0
@export var knockback_resistance: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

var health: int
var player: Node2D = null
var can_attack: bool = true
var knockback: Vector2 = Vector2.ZERO

var base_max_health: int
var base_scale: Vector2
var walk_time: float = 0.0
var previous_pos: Vector2

func _ready() -> void:
	base_max_health = max_health
	base_scale = sprite.scale
	if sprite.material:
		sprite.material = sprite.material.duplicate()
	reset()

func reset() -> void:
	max_health = base_max_health
	health = max_health
	can_attack = true
	knockback = Vector2.ZERO
	sprite.modulate.a = 1.0
	sprite.scale = base_scale

	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("active", false)

	player = get_tree().get_first_node_in_group("player")
	previous_pos = global_position
	SpatialGrid.insert(self)

func set_scaled_max_health(multiplier: float) -> void:
	max_health = int(float(base_max_health) * multiplier)
	health = max_health

func _physics_process(delta: float) -> void:
	if health <= 0:
		return

	SpatialGrid.update_entity(self, previous_pos, global_position)
	previous_pos = global_position

	if not player:
		player = get_tree().get_first_node_in_group("player")
		return

	var distance_to_player := global_position.distance_to(player.global_position)
	var dir_to_player := global_position.direction_to(player.global_position)

	look_at(player.global_position)

	# Knockback decay
	knockback = knockback.move_toward(Vector2.ZERO, 500 * delta)

	# Movement
	if distance_to_player > attack_range * 0.9:
		var move_dir = dir_to_player

		# Soft Collision Separation using Grid O(1)
		var separation_vector := Vector2.ZERO
		var neighbors = SpatialGrid.get_nearby_entities(global_position)
		for neighbor in neighbors:
			if neighbor != self and is_instance_valid(neighbor):
				var dist = global_position.distance_to(neighbor.global_position)
				if dist < 60.0 and dist > 0.1:
					separation_vector -= global_position.direction_to(neighbor.global_position) * (60.0 / dist)

		move_dir = (move_dir * move_speed + separation_vector * 5.0).normalized()

		# Use global_position directly to avoid move_and_slide physics overhead for 2000+ entities
		# Only block via actual physics layers if colliding with World (Layer 1)
		velocity = move_dir * move_speed + knockback
		var collision = move_and_collide(velocity * delta)

		# Procedural Animation (Squash & Stretch)
		walk_time += delta * (move_speed / 20.0)
		var stretch = sin(walk_time) * 0.1
		var squash = cos(walk_time) * 0.1
		sprite.scale = base_scale + Vector2(stretch, squash)
	else:
		sprite.scale = base_scale

	if distance_to_player <= attack_range:
		_attack_player()

func _attack_player() -> void:
	if can_attack and player.has_method("take_damage"):
		can_attack = false
		player.take_damage(attack_damage)

		var timer := get_tree().create_timer(attack_cooldown)
		timer.timeout.connect(func() -> void: can_attack = true)

func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if health <= 0:
		return

	health -= amount

	# Camera Shake
	EventBus.camera_shake_requested.emit()

	# Damage Number
	var dmg_num = ObjectPoolManager.acquire("damage_number", global_position)
	if dmg_num:
		dmg_num.amount = amount

	# Blood Particles
	var blood = ObjectPoolManager.acquire("blood_impact", global_position)
	if blood and hit_direction != Vector2.ZERO:
		blood.rotation = hit_direction.angle()

	# Knockback
	knockback = hit_direction * 200.0 * (1.0 - knockback_resistance)

	# White Flash Shader
	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("active", true)
		var timer := get_tree().create_timer(0.05)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(sprite) and sprite.material is ShaderMaterial:
				sprite.material.set_shader_parameter("active", false)
		)

	if health <= 0:
		die()

func die() -> void:
	EventBus.zombie_died.emit(global_position)
	SpatialGrid.remove(self)

	if has_meta("is_boss") and get_meta("is_boss"):
		SaveManager.add_gold(1000)
		EventBus.game_over.emit(true)
	else:
		# Standard drop
		ObjectPoolManager.acquire("exp_gem", global_position)
		if randf() < 0.05:
			SaveManager.add_gold(10)

	# Fade out logic without immediately blocking process so tween can finish
	collision_layer = 0
	collision_mask = 0
	can_attack = false
	velocity = Vector2.ZERO

	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func():
		collision_layer = 2
		collision_mask = 5
		ObjectPoolManager.release(self)
	)
