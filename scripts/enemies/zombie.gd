class_name Zombie
extends CharacterBody2D

@export var max_health: int = 30
@export var move_speed: float = 100.0
@export var attack_damage: int = 10
@export var attack_range: float = 75.0
@export var attack_cooldown: float = 1.0
@export var knockback_resistance: float = 0.0
@export var ranged_attack: bool = false
@export var preferred_attack_distance: float = 150.0
@export var projectile_damage: int = 8
@export var explodes_on_contact: bool = false
@export var detonates_on_death: bool = false
@export var detonation_radius: float = 140.0
@export var detonation_damage: int = 16
@export_enum("Shambler", "Runner", "Tank", "Spitter", "Bomber", "Bloater") var motion_profile: int = 0

@onready var sprite: Sprite2D = $Sprite2D

var health: int
var player: Node2D = null
var can_attack: bool = true
var knockback: Vector2 = Vector2.ZERO
var is_dying: bool = false

var base_max_health: int
var base_move_speed: float
var base_attack_damage: int
var base_body_scale: Vector2
var base_scale: Vector2
var base_sprite_position: Vector2
var base_sprite_modulate: Color
var walk_time: float = 0.0
var visual_time: float = 0.0
var hit_recoil: Vector2 = Vector2.ZERO
var attack_pulse: float = 0.0
var previous_pos: Vector2
var wall_follow_direction: Vector2 = Vector2.ZERO
var wall_follow_timer: float = 0.0
var ranged_can_attack: bool = true
var boss_attack_timer: float = 4.0
var boss_telegraph_timer: float = 0.0

const WALL_LOOK_AHEAD: float = 54.0
const WALL_FOLLOW_TIME: float = 0.45

func _ready() -> void:
	base_max_health = max_health
	base_move_speed = move_speed
	base_attack_damage = attack_damage
	base_body_scale = scale
	base_scale = sprite.scale
	base_sprite_position = sprite.position
	base_sprite_modulate = sprite.modulate
	if sprite.material:
		sprite.material = sprite.material.duplicate()
	reset()

func reset() -> void:
	max_health = base_max_health
	move_speed = base_move_speed
	attack_damage = base_attack_damage
	health = max_health
	can_attack = true
	knockback = Vector2.ZERO
	is_dying = false
	collision_layer = 2
	collision_mask = 5
	modulate = Color.WHITE
	scale = base_body_scale
	rotation = 0.0
	sprite.modulate = base_sprite_modulate
	sprite.scale = base_scale
	sprite.position = base_sprite_position
	sprite.rotation = 0.0
	sprite.flip_h = false
	walk_time = 0.0
	visual_time = randf() * TAU
	hit_recoil = Vector2.ZERO
	attack_pulse = 0.0
	wall_follow_direction = Vector2.ZERO
	wall_follow_timer = 0.0
	ranged_can_attack = true
	boss_attack_timer = 4.0
	boss_telegraph_timer = 0.0
	set_meta("is_boss", false)
	set_meta("is_elite", false)

	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("active", false)

	player = get_tree().get_first_node_in_group("player")
	previous_pos = global_position
	SpatialGrid.insert(self)

func set_scaled_max_health(multiplier: float) -> void:
	max_health = int(float(base_max_health) * multiplier)
	health = max_health

func set_elite() -> void:
	set_meta("is_elite", true)
	max_health = int(float(max_health) * 1.8)
	health = max_health
	move_speed *= 1.12
	attack_damage = int(float(attack_damage) * 1.25)
	scale = base_body_scale * 1.2
	sprite.modulate = Color(1.0, 0.72, 0.25, 1.0)

func _physics_process(delta: float) -> void:
	if health <= 0:
		return

	if not player:
		player = get_tree().get_first_node_in_group("player")
		return

	var distance_to_player := global_position.distance_to(player.global_position)
	var dir_to_player := global_position.direction_to(player.global_position)
	var position_before_move := global_position

	# Keep physics and collision upright. Facing is communicated by a horizontal
	# flip while the sprite itself receives only a tiny procedural sway.
	if absf(dir_to_player.x) > 0.1:
		sprite.flip_h = dir_to_player.x < 0.0

	# Knockback decay
	knockback = knockback.move_toward(Vector2.ZERO, 500 * delta)

	# Movement. Melee reach is never allowed to be shorter than the two collision
	# bodies together, otherwise zombies could be physically touching the player
	# but remain outside their own damage check.
	var effective_attack_range := attack_range if ranged_attack else _get_melee_engagement_range()
	var needs_movement := distance_to_player > effective_attack_range * 0.9 or (ranged_attack and distance_to_player < preferred_attack_distance)
	if needs_movement:
		var should_advance := not ranged_attack or distance_to_player > effective_attack_range
		var move_dir := Vector2.ZERO
		if should_advance:
			move_dir = _get_wall_aware_direction(dir_to_player, delta)
		elif ranged_attack and distance_to_player < preferred_attack_distance:
			move_dir = _get_wall_aware_direction(-dir_to_player, delta)

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

	# Animate only when the zombie actually travelled this frame. This avoids
	# a fake walk cycle when it is blocked against a wall or another enemy.
	var visually_moving := global_position.distance_squared_to(position_before_move) > 0.25
	_animate_visual(delta, visually_moving)

	if ranged_attack and distance_to_player <= effective_attack_range:
		_attack_ranged()
	elif not ranged_attack and distance_to_player <= effective_attack_range:
		_attack_player()

	_update_boss(delta)

func _attack_player() -> void:
	if can_attack and player.has_method("take_damage"):
		can_attack = false
		attack_pulse = 0.6
		player.take_damage(attack_damage, global_position.direction_to(player.global_position))
		if explodes_on_contact:
			AudioManager.play_named("impact", -4.0)
			die()
			return

		var timer := get_tree().create_timer(attack_cooldown)
		timer.timeout.connect(func() -> void: can_attack = true)

func _attack_ranged() -> void:
	if not ranged_can_attack or not is_instance_valid(player):
		return
	ranged_can_attack = false
	attack_pulse = 1.0
	var projectile = ObjectPoolManager.acquire("acid_projectile", global_position)
	if projectile:
		projectile.direction = global_position.direction_to(player.global_position)
		projectile.damage = projectile_damage
	var timer := get_tree().create_timer(attack_cooldown)
	timer.timeout.connect(func() -> void: ranged_can_attack = true)

func _update_boss(delta: float) -> void:
	if not has_meta("is_boss") or not get_meta("is_boss"):
		return
	if boss_telegraph_timer > 0.0:
		boss_telegraph_timer -= delta
		if boss_telegraph_timer <= 0.0:
			_boss_shockwave()
		return
	boss_attack_timer -= delta
	if boss_attack_timer <= 0.0:
		boss_attack_timer = 4.5
		boss_telegraph_timer = 0.7
		sprite.modulate = Color(1.0, 0.25, 0.2, 1.0)

func _boss_shockwave() -> void:
	sprite.modulate = base_sprite_modulate
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= 260.0:
		player.take_damage(18, global_position.direction_to(player.global_position))

func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if health <= 0 or is_dying:
		return

	health -= amount

	# Damage Number
	var dmg_num = ObjectPoolManager.acquire("damage_number", global_position)
	if dmg_num:
		dmg_num.amount = amount

	# Knockback
	knockback = hit_direction * 200.0 * (1.0 - knockback_resistance)
	hit_recoil = hit_direction * 4.0 * (1.0 - knockback_resistance * 0.55)

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

func _animate_visual(delta: float, moving: bool) -> void:
	visual_time += delta
	attack_pulse = maxf(0.0, attack_pulse - delta * 3.8)
	var movement_weight := 1.0 if moving else 0.24
	var bob := 0.0
	var sway := 0.0
	var desired_rotation := 0.0
	var desired_scale := base_scale

	match motion_profile:
		1: # Runner: sharp, fast strides and a forward rush.
			var stride := sin(visual_time * 15.0)
			bob = absf(stride) * 6.0 * movement_weight
			sway = stride * 3.0 * movement_weight
			desired_rotation = stride * 0.065 * movement_weight
			desired_scale = base_scale * Vector2(1.0 + absf(stride) * 0.11, 1.0 - absf(stride) * 0.085)
		2: # Tank: slow mass shifting and a heavy impact step.
			var stomp := sin(visual_time * 5.2)
			bob = absf(stomp) * 2.8 * movement_weight
			sway = stomp * 1.2 * movement_weight
			desired_rotation = stomp * 0.026 * movement_weight
			desired_scale = base_scale * Vector2(1.0 + absf(stomp) * 0.05, 1.0 - absf(stomp) * 0.035)
		3: # Spitter: tense breathing while circling, then a short firing lunge.
			var breath := sin(visual_time * (5.8 if moving else 2.6))
			bob = breath * (2.5 if moving else 1.25)
			sway = sin(visual_time * 3.4) * 1.4
			desired_rotation = breath * 0.03
			desired_scale = base_scale * Vector2(1.0 + attack_pulse * 0.08, 1.0 - attack_pulse * 0.05)
		4: # Bomber: an unstable warning pulse that accelerates as it advances.
			var alarm := sin(visual_time * (10.0 if moving else 6.0))
			bob = absf(alarm) * 3.6 * movement_weight
			sway = alarm * 1.7
			desired_rotation = alarm * 0.045
			desired_scale = base_scale * Vector2(1.0 + absf(alarm) * 0.09 + attack_pulse * 0.1, 1.0 - absf(alarm) * 0.06)
		5: # Bloater: slow organic swelling, even while standing still.
			var swell := sin(visual_time * 3.2) + sin(visual_time * 5.1) * 0.35
			bob = swell * 1.5
			sway = sin(visual_time * 2.1) * 1.15
			desired_rotation = sway * 0.024
			desired_scale = base_scale * Vector2(1.0 + swell * 0.055 + attack_pulse * 0.05, 1.0 + swell * 0.035)
		_: # Shambler: uneven steps with a small side-to-side stagger.
			var stagger := sin(visual_time * (8.0 if moving else 2.0))
			bob = absf(stagger) * 4.2 * movement_weight
			sway = sin(visual_time * 4.1) * 2.1 * movement_weight
			desired_rotation = stagger * 0.045 * movement_weight
			desired_scale = base_scale * Vector2(1.0 + absf(stagger) * 0.075, 1.0 - absf(stagger) * 0.055)

	hit_recoil = hit_recoil.move_toward(Vector2.ZERO, delta * 30.0)
	var attack_lunge := Vector2(-attack_pulse * 3.0, 0.0)
	if sprite.flip_h:
		attack_lunge.x *= -1.0
	sprite.position = sprite.position.lerp(base_sprite_position + Vector2(sway, -bob) + hit_recoil + attack_lunge, minf(delta * 16.0, 1.0))
	sprite.scale = sprite.scale.lerp(desired_scale, minf(delta * 15.0, 1.0))
	sprite.rotation = lerp_angle(sprite.rotation, desired_rotation, minf(delta * 14.0, 1.0))

func die() -> void:
	if is_dying:
		return
	is_dying = true
	health = 0
	if detonates_on_death:
		_detonate()

	EventBus.zombie_died.emit(global_position)
	RunStats.register_kill()
	var scrap_reward := 1
	if get_meta("is_elite", false):
		RunStats.register_elite_kill()
		scrap_reward = 5
	if has_meta("is_boss") and get_meta("is_boss"):
		scrap_reward = 30
	RunStats.add_scrap(scrap_reward)
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

func _detonate() -> void:
	var player_node := get_tree().get_first_node_in_group("player") as Player
	if is_instance_valid(player_node) and global_position.distance_to(player_node.global_position) <= detonation_radius:
		player_node.take_damage(detonation_damage, global_position.direction_to(player_node.global_position))
	var impact = ObjectPoolManager.acquire("blood_impact", global_position)
	if impact and impact.has_method("configure"):
		impact.configure(Color(1.0, 0.5, 0.12, 1.0), detonation_radius)
	AudioManager.play_named("impact", -2.0, randf_range(0.72, 0.86))

func _get_melee_engagement_range() -> float:
	if not is_instance_valid(player):
		return attack_range
	var self_radius := _get_collision_radius(self)
	var player_radius := _get_collision_radius(player)
	# Leave a small visible contact gap rather than allowing sprite overlap.
	return maxf(attack_range, self_radius + player_radius + 10.0)

func _get_collision_radius(body: Node2D) -> float:
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision and collision.shape is CircleShape2D:
		var circle := collision.shape as CircleShape2D
		return circle.radius * maxf(absf(collision.global_scale.x), absf(collision.global_scale.y))
	return 0.0

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
