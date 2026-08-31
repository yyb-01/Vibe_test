class_name Zombie
extends CharacterBody2D

const SHAMBLER_WALK_A: Texture2D = preload("res://assets/graphics/zombie_walk_a_v3.png")
const SHAMBLER_WALK_B: Texture2D = preload("res://assets/graphics/zombie_walk_b_v3.png")
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
var base_projectile_damage: int
var base_body_scale: Vector2
var base_scale: Vector2
var base_sprite_position: Vector2
var base_sprite_modulate: Color
var base_sprite_texture: Texture2D
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
var boss_charge_time: float = 0.0
var boss_phase: int = 1
var boss_attack_mode: String = "shockwave"
var runner_dash_time: float = 0.0
var runner_dash_cooldown: float = 0.0
var tank_stomp_cooldown: float = 0.0
var bloater_spit_cooldown: float = 1.5
var strafe_sign: float = 1.0
var hit_stop_timer: float = 0.0

const WALL_LOOK_AHEAD: float = 54.0
const WALL_FOLLOW_TIME: float = 0.45

func _ready() -> void:
	z_index = 6
	base_max_health = max_health
	base_move_speed = move_speed
	base_attack_damage = attack_damage
	base_projectile_damage = projectile_damage
	base_body_scale = scale
	base_scale = sprite.scale
	base_sprite_position = sprite.position
	base_sprite_modulate = sprite.modulate
	base_sprite_texture = sprite.texture
	if sprite.material:
		sprite.material = sprite.material.duplicate()
	reset()

func reset() -> void:
	max_health = base_max_health
	move_speed = base_move_speed
	attack_damage = base_attack_damage
	projectile_damage = base_projectile_damage
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
	sprite.texture = base_sprite_texture
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
	boss_charge_time = 0.0
	boss_phase = 1
	boss_attack_mode = "shockwave"
	runner_dash_time = 0.0
	runner_dash_cooldown = randf_range(0.6, 1.4)
	tank_stomp_cooldown = randf_range(1.0, 2.2)
	bloater_spit_cooldown = randf_range(1.5, 3.5)
	strafe_sign = -1.0 if randf() < 0.5 else 1.0
	hit_stop_timer = 0.0
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
	if hit_stop_timer > 0.0:
		hit_stop_timer = maxf(0.0, hit_stop_timer - delta)
		return

	if not player:
		player = get_tree().get_first_node_in_group("player")
		return

	var distance_to_player := global_position.distance_to(player.global_position)
	var dir_to_player := global_position.direction_to(player.global_position)
	var position_before_move := global_position
	var boss_speed_multiplier := _update_boss(delta)
	var profile_speed_multiplier := _update_special_pattern(delta, distance_to_player, dir_to_player) * boss_speed_multiplier

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
		if motion_profile == 3 and move_dir != Vector2.ZERO:
			# Spitters sidestep while maintaining their preferred firing distance.
			move_dir = (move_dir + dir_to_player.orthogonal() * strafe_sign * 0.52).normalized()

		# Soft Collision Separation using Grid O(1)
		var separation_vector := Vector2.ZERO
		var neighbors = SpatialGrid.get_nearby_entities(global_position)
		for neighbor in neighbors:
			if neighbor != self and is_instance_valid(neighbor):
				var dist = global_position.distance_to(neighbor.global_position)
				if dist < 60.0 and dist > 0.1:
					separation_vector -= global_position.direction_to(neighbor.global_position) * (60.0 / dist)

		move_dir = (move_dir * move_speed + separation_vector * 5.0).normalized()

		velocity = move_dir * move_speed * profile_speed_multiplier + knockback
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
	var aim_direction := global_position.direction_to(player.global_position)
	var spread := PackedFloat32Array([0.0])
	if motion_profile == 3:
		# The spitter is identifiable in play: it spits a short, dodgeable fan.
		spread = PackedFloat32Array([-0.16, 0.0, 0.16])
	for angle_offset in spread:
		var projectile = ObjectPoolManager.acquire("acid_projectile", global_position)
		if projectile:
			projectile.direction = aim_direction.rotated(angle_offset)
			projectile.damage = projectile_damage if is_zero_approx(angle_offset) else max(1, projectile_damage - 2)
	var timer := get_tree().create_timer(attack_cooldown)
	timer.timeout.connect(func() -> void: ranged_can_attack = true)

func _update_boss(delta: float) -> float:
	if not has_meta("is_boss") or not get_meta("is_boss"):
		return 1.0
	queue_redraw()
	var health_ratio := float(health) / float(maxi(1, max_health))
	var next_phase := 1 if health_ratio > 0.66 else (2 if health_ratio > 0.33 else 3)
	if next_phase != boss_phase:
		boss_phase = next_phase
		attack_pulse = 1.0
		boss_attack_timer = 1.1
		if boss_phase == 2:
			_summon_boss_escorts("zombie_runner", 4)
		else:
			_summon_boss_escorts("zombie_bomber", 2)
			_summon_boss_escorts("zombie_spitter", 2)
	EventBus.boss_status_changed.emit("격리 파괴자", health_ratio, boss_phase)
	if boss_charge_time > 0.0:
		boss_charge_time -= delta
		return 2.15
	if boss_telegraph_timer > 0.0:
		boss_telegraph_timer -= delta
		if boss_telegraph_timer <= 0.0:
			_execute_boss_attack()
		return 1.0
	boss_attack_timer -= delta
	if boss_attack_timer <= 0.0:
		boss_attack_timer = 4.8 - float(boss_phase) * 0.45
		boss_telegraph_timer = 0.7
		if boss_phase == 1:
			boss_attack_mode = "shockwave"
		elif boss_phase == 2:
			boss_attack_mode = "summon" if randf() < 0.45 else "shockwave"
		else:
			boss_attack_mode = "charge" if randf() < 0.58 else "summon"
		EventBus.boss_attack_warning.emit(boss_attack_mode, true)
		sprite.modulate = Color(1.0, 0.22 + float(boss_phase) * 0.08, 0.12, 1.0)
	return 1.0

func _execute_boss_attack() -> void:
	EventBus.boss_attack_warning.emit(boss_attack_mode, false)
	sprite.modulate = base_sprite_modulate
	match boss_attack_mode:
		"charge":
			boss_charge_time = 0.78
			attack_pulse = 1.0
		"summon":
			_summon_boss_escorts("zombie_runner", 3 + boss_phase)
			if boss_phase >= 3:
				_summon_boss_escorts("zombie_spitter", 2)
		_: _boss_shockwave()

func _boss_shockwave() -> void:
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= 270.0 + boss_phase * 30.0:
		player.take_damage(13 + boss_phase * 5, global_position.direction_to(player.global_position))
	var impact = ObjectPoolManager.acquire("blood_impact", global_position)
	if impact and impact.has_method("configure"):
		impact.configure(Color(1.0, 0.22, 0.1, 1.0), 270.0 + boss_phase * 30.0)

func _summon_boss_escorts(pool_id: String, count: int) -> void:
	for index in range(count):
		var summon_position := global_position + Vector2.RIGHT.rotated((TAU / float(count)) * float(index) + randf_range(-0.2, 0.2)) * randf_range(96.0, 160.0)
		var summon = ObjectPoolManager.acquire(pool_id, summon_position)
		if summon:
			summon.set_meta("pool_id", pool_id)
			if summon.has_method("set_scaled_max_health"):
				summon.set_scaled_max_health(1.0 + float(boss_phase) * 0.3)

func _draw() -> void:
	if not has_meta("is_boss") or not get_meta("is_boss") or boss_telegraph_timer <= 0.0:
		return
	var pulse := 0.62 + absf(sin(Time.get_ticks_msec() * 0.012)) * 0.38
	var warning_color := Color(1.0, 0.18, 0.08, 0.72 * pulse)
	match boss_attack_mode:
		"shockwave":
			var radius := 270.0 + float(boss_phase) * 30.0
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, warning_color, 9.0, true)
			draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 96, Color(warning_color, 0.22), 3.0, true)
		"charge":
			if is_instance_valid(player):
				var target := to_local(player.global_position)
				draw_line(Vector2.ZERO, target, warning_color, 26.0, true)
				draw_line(Vector2.ZERO, target, Color(1.0, 0.75, 0.25, 0.9 * pulse), 4.0, true)
				draw_circle(target, 24.0, Color(1.0, 0.2, 0.08, 0.42 * pulse))
		"summon":
			var marker_count := 3 + boss_phase
			for index in range(marker_count):
				var marker := Vector2.RIGHT.rotated((TAU / float(marker_count)) * float(index)) * 130.0
				draw_circle(marker, 34.0, Color(1.0, 0.16, 0.08, 0.26 * pulse))
				draw_arc(marker, 34.0, 0.0, TAU, 32, warning_color, 6.0, true)

func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO, hit_kind: String = "normal") -> void:
	if health <= 0 or is_dying:
		return

	var applied_damage := mini(amount, health)
	health -= amount
	RunStats.register_combat_hit(applied_damage, hit_kind)

	# Damage Number
	var dmg_num = ObjectPoolManager.acquire("damage_number", global_position)
	if dmg_num:
		if dmg_num.has_method("configure"):
			dmg_num.configure(amount, hit_kind)
		else:
			dmg_num.amount = amount

	match hit_kind:
		"critical": hit_stop_timer = maxf(hit_stop_timer, 0.055)
		"execute": hit_stop_timer = maxf(hit_stop_timer, 0.075)
		"heavy": hit_stop_timer = maxf(hit_stop_timer, 0.038)
		_: hit_stop_timer = maxf(hit_stop_timer, 0.018)

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
	var render_base_scale := _update_walk_texture(moving)
	var movement_weight := 1.0 if moving else 0.24
	var bob := 0.0
	var sway := 0.0
	var desired_rotation := 0.0
	var desired_scale := render_base_scale

	match motion_profile:
		1: # Runner: sharp, fast strides and a forward rush.
			var stride := sin(visual_time * 15.0)
			bob = absf(stride) * 6.0 * movement_weight
			sway = stride * 3.0 * movement_weight
			desired_rotation = stride * 0.065 * movement_weight
		2: # Tank: slow mass shifting and a heavy impact step.
			var stomp := sin(visual_time * 5.2)
			bob = absf(stomp) * 2.8 * movement_weight
			sway = stomp * 1.2 * movement_weight
			desired_rotation = stomp * 0.026 * movement_weight
		3: # Spitter: tense breathing while circling, then a short firing lunge.
			var breath := sin(visual_time * (5.8 if moving else 2.6))
			bob = breath * (2.5 if moving else 1.25)
			sway = sin(visual_time * 3.4) * 1.4
			desired_rotation = breath * 0.03
		4: # Bomber: an unstable warning pulse that accelerates as it advances.
			var alarm := sin(visual_time * (10.0 if moving else 6.0))
			bob = absf(alarm) * 3.6 * movement_weight
			sway = alarm * 1.7
			desired_rotation = alarm * 0.045
		5: # Bloater: slow organic swelling, even while standing still.
			var swell := sin(visual_time * 3.2) + sin(visual_time * 5.1) * 0.35
			bob = swell * 1.5
			sway = sin(visual_time * 2.1) * 1.15
			desired_rotation = sway * 0.024
		_: # Shambler: uneven steps with a small side-to-side stagger.
			var stagger := sin(visual_time * (8.0 if moving else 2.0))
			bob = absf(stagger) * 4.2 * movement_weight
			sway = sin(visual_time * 4.1) * 2.1 * movement_weight
			desired_rotation = stagger * 0.045 * movement_weight

	hit_recoil = hit_recoil.move_toward(Vector2.ZERO, delta * 30.0)
	var attack_lunge := Vector2(-attack_pulse * 3.0, 0.0)
	if sprite.flip_h:
		attack_lunge.x *= -1.0
	sprite.position = sprite.position.lerp(base_sprite_position + Vector2(sway, -bob) + hit_recoil + attack_lunge, minf(delta * 16.0, 1.0))
	sprite.scale = sprite.scale.lerp(desired_scale, minf(delta * 15.0, 1.0))
	sprite.rotation = lerp_angle(sprite.rotation, desired_rotation, minf(delta * 14.0, 1.0))

func _update_special_pattern(delta: float, distance_to_player: float, dir_to_player: Vector2) -> float:
	match motion_profile:
		1: # Runner: punctuated lunge that has to be sidestepped.
			runner_dash_cooldown = maxf(0.0, runner_dash_cooldown - delta)
			if runner_dash_time > 0.0:
				runner_dash_time -= delta
				return 1.72
			if runner_dash_cooldown <= 0.0 and distance_to_player > 110.0 and distance_to_player < 390.0:
				runner_dash_time = 0.42
				runner_dash_cooldown = 2.7
				attack_pulse = 0.9
		2: # Tank: a close shock stomp punishes standing directly in front of it.
			tank_stomp_cooldown = maxf(0.0, tank_stomp_cooldown - delta)
			if tank_stomp_cooldown <= 0.0 and distance_to_player <= 230.0:
				tank_stomp_cooldown = 3.8
				attack_pulse = 1.0
				if is_instance_valid(player) and player.has_method("take_damage"):
					player.take_damage(max(8, int(float(attack_damage) * 0.55)), dir_to_player)
		3: # Spitter: alternates which side it circles from between bursts.
			if int(visual_time * 0.42) % 2 == 0:
				strafe_sign = 1.0
			else:
				strafe_sign = -1.0
		4: # Bomber accelerates on approach and visibly swells before contact.
			if distance_to_player < 310.0:
				attack_pulse = maxf(attack_pulse, 0.34)
				return 1.28
		5: # Bloater occasionally throws a wide acid burst before dying.
			bloater_spit_cooldown = maxf(0.0, bloater_spit_cooldown - delta)
			if bloater_spit_cooldown <= 0.0 and distance_to_player > 120.0 and distance_to_player < 350.0:
				bloater_spit_cooldown = 5.6
				attack_pulse = 1.0
				for angle_offset in PackedFloat32Array([-0.34, 0.0, 0.34]):
					var projectile = ObjectPoolManager.acquire("acid_projectile", global_position)
					if projectile:
						projectile.direction = dir_to_player.rotated(angle_offset)
						projectile.damage = max(3, projectile_damage)
	return 1.0

func _update_walk_texture(moving: bool) -> Vector2:
	if motion_profile == 0:
		sprite.texture = SHAMBLER_WALK_B if moving and int(visual_time * 6.5) % 2 == 1 else SHAMBLER_WALK_A
		return base_scale
	# Special zombies keep their scene-assigned identity sprite. Their animations
	# are positional only; mixing frames with different canvases made them pop in
	# size and briefly resemble the wrong enemy type.
	sprite.texture = base_sprite_texture
	return base_scale

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
		EventBus.boss_status_changed.emit("", -1.0, 0)
		EventBus.boss_attack_warning.emit("", false)
	RunStats.add_scrap(scrap_reward)
	SpatialGrid.remove(self)

	if has_meta("is_boss") and get_meta("is_boss"):
		EventBus.boss_defeated.emit()
		if RunStats.endless_mode:
			SaveManager.add_gold(250)
			ObjectPoolManager.acquire("exp_gem", global_position)
		else:
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
	# Leave a brief hit-confirmation after death, then return the body to the
	# pool quickly so crowded waves do not accumulate visible corpses.
	tween.tween_property(sprite, "modulate:a", 0.0, 0.38)
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
