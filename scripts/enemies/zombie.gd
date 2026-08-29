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
var is_dying: bool = false

var base_max_health: int
var base_scale: Vector2
var base_sprite_modulate: Color
var walk_time: float = 0.0
var previous_pos: Vector2
var wall_follow_direction: Vector2 = Vector2.ZERO
var wall_follow_timer: float = 0.0

const WALL_LOOK_AHEAD: float = 54.0
const WALL_FOLLOW_TIME: float = 0.45

func _ready() -> void:
	base_max_health = max_health
	base_scale = sprite.scale
	base_sprite_modulate = sprite.modulate
	if sprite.material:
		sprite.material = sprite.material.duplicate()
	reset()

func reset() -> void:
	max_health = base_max_health
	health = max_health
	can_attack = true
	knockback = Vector2.ZERO
	is_dying = false
	collision_layer = 2
	collision_mask = 5
	modulate = Color.WHITE
	sprite.modulate = base_sprite_modulate
	sprite.scale = base_scale
	walk_time = 0.0
	wall_follow_direction = Vector2.ZERO
	wall_follow_timer = 0.0

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
		var move_dir = _get_wall_aware_direction(dir_to_player, delta)

		# Soft Collision Separation using Grid O(1)
		var separation_vector := Vector2.ZERO
		var neighbors = SpatialGrid.get_nearby_entities(global_position)
		for neighbor in neighbors:
			if neighbor != self and is_instance_valid(neighbor):
				var dist = global_position.distance_to(neighbor.global_position)
				if dist < 60.0 and dist > 0.1:
					separation_vector -= global_position.direction_to(neighbor.global_position) * (60.0 / dist)

		move_dir = (move_dir * move_speed + separation_vector * 5.0).normalized()

		velocity = move_dir * move_speed + knockback
		# move_and_slide resolves the wall contact while the steering probe keeps the
		# enemy moving along the wall instead of pressing into it forever.
		move_and_slide()
		SpatialGrid.update_entity(self, previous_pos, global_position)
		previous_pos = global_position

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
		player.take_damage(attack_damage, global_position.direction_to(player.global_position))

		var timer := get_tree().create_timer(attack_cooldown)
		timer.timeout.connect(func() -> void: can_attack = true)

func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if health <= 0 or is_dying:
		return

	health -= amount

	# Camera Shake
	EventBus.camera_shake_requested.emit()

	# Damage Number
	var dmg_num = ObjectPoolManager.acquire("damage_number", global_position)
	if dmg_num:
		dmg_num.amount = amount

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
	if is_dying:
		return
	is_dying = true
	health = 0

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

func _get_wall_aware_direction(target_direction: Vector2, delta: float) -> Vector2:
	wall_follow_timer = maxf(0.0, wall_follow_timer - delta)

	var probe_direction := target_direction
	if wall_follow_timer > 0.0 and wall_follow_direction != Vector2.ZERO:
		probe_direction = wall_follow_direction

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + probe_direction * WALL_LOOK_AHEAD,
		1
	)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.get("collider") == player:
		if wall_follow_timer > 0.0 and wall_follow_direction != Vector2.ZERO:
			return wall_follow_direction
		return target_direction

	var normal: Vector2 = hit.get("normal", Vector2.ZERO)
	if normal == Vector2.ZERO:
		return target_direction

	# Pick the tangent that keeps pointing toward the player. This makes the
	# zombie round either side of pillars and room walls instead of getting stuck.
	var tangent_a := Vector2(-normal.y, normal.x)
	var tangent_b := -tangent_a
	wall_follow_direction = tangent_a if tangent_a.dot(target_direction) > tangent_b.dot(target_direction) else tangent_b
	wall_follow_direction = (wall_follow_direction * 0.92 + target_direction * 0.18).normalized()
	wall_follow_timer = WALL_FOLLOW_TIME
	return wall_follow_direction
