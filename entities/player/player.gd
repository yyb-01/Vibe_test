class_name Player
extends CharacterBody2D

const DIRECTION_NAMES: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const ProjectileScene = preload("res://entities/combat/projectile.tscn")
const HealthComponentClass = preload("res://scripts/components/health_component.gd")
const JuiceHelperClass = preload("res://scripts/systems/juice_helper.gd")
const GameStateMachine = preload("res://scripts/core/game_state_machine.gd")

@export var move_speed: float = 220.0
@export var acceleration: float = 3200.0
@export var friction: float = 2800.0
@export var shoot_cooldown: float = 0.2
@export var bullet_damage: float = 25.0
@export var bullet_speed: float = 650.0
@export_range(0.0, 1.0) var critical_chance: float = 0.12
@export var critical_multiplier: float = 1.75
@export var dash_speed: float = 760.0
@export var dash_duration: float = 0.2
@export var dash_iframe_duration: float = 0.15
@export var dash_cooldown: float = 0.45
@export var recoil_push: float = 18.0
@export var melee_damage: float = 38.0
@export var melee_radius: float = 86.0
@export_range(10.0, 180.0) var melee_cone_angle: float = 90.0
@export var melee_cooldown: float = 0.32

@onready var visual: AnimatedSprite2D = $Visual
@onready var health_component: HealthComponentClass = $HealthComponent

var aim_direction: Vector2 = Vector2.RIGHT
var current_direction_index: int = 0
var is_input_blocked: bool = false

var _shoot_timer: float = 0.0
var _melee_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_iframe_timer: float = 0.0
var _dash_trail_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _normal_collision_mask: int = 13
var _is_firing: bool = false
var _melee_shape: CircleShape2D

func _ready() -> void:
	_normal_collision_mask = collision_mask
	_melee_shape = CircleShape2D.new()
	_melee_shape.radius = melee_radius
	safe_margin = 0.08
	max_slides = 6
	_update_visual_animation()
	if health_component != null:
		health_component.damage_taken.connect(_on_damage_taken)
		health_component.died.connect(_on_died)
	var eb := get_node_or_null("/root/EventBus")
	if eb != null:
		eb.game_state_changed.connect(_on_game_state_changed)
	_update_control_state()

func _on_game_state_changed(_prev: int, _curr: int) -> void:
	_update_control_state()

func _update_control_state() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var state: int = gm.current_state
	is_input_blocked = state == GameStateMachine.State.HUB or state == GameStateMachine.State.DAY_SUMMARY
	if is_input_blocked:
		_is_firing = false
		_end_dash()

func _unhandled_input(event: InputEvent) -> void:
	if is_input_blocked:
		return
	if event.is_action_pressed("dash") and not (event is InputEventKey and event.echo):
		try_dash()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("shoot"):
		if _combat_state_allowed():
			_is_firing = true
			if _shoot_timer <= 0.0:
				shoot()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("shoot"):
		_is_firing = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("melee") and _combat_state_allowed():
		melee()
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_handle_aim()
	_shoot_timer = maxf(0.0, _shoot_timer - delta)
	_melee_timer = maxf(0.0, _melee_timer - delta)
	_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)
	if is_input_blocked:
		velocity = Vector2.ZERO
		return
	if _dash_timer > 0.0:
		_dash_timer -= delta
		_dash_iframe_timer = maxf(0.0, _dash_iframe_timer - delta)
		_dash_trail_timer -= delta
		if _dash_trail_timer <= 0.0:
			_spawn_dash_ghost()
			_dash_trail_timer = 0.035
		velocity = _dash_direction * dash_speed
		move_and_slide()
		if _dash_iframe_timer <= 0.0 and health_component != null:
			health_component.set_invulnerable(false)
		if _dash_timer <= 0.0:
			_end_dash()
		return

	_handle_movement(delta)
	if _is_firing and _shoot_timer <= 0.0 and _combat_state_allowed():
		shoot()

func _handle_movement(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_velocity := input_vector * move_speed
	var rate := acceleration if input_vector.length_squared() > 0.0 else friction
	velocity = velocity.move_toward(target_velocity, rate * delta)
	move_and_slide()
	if input_vector.length_squared() > 0.0 and get_slide_collision_count() > 0:
		# CharacterBody2D already slides; projecting once more removes corner drag.
		for i in range(get_slide_collision_count()):
			var normal := get_slide_collision(i).get_normal()
			if absf(normal.dot(input_vector)) > 0.02:
				velocity = velocity.slide(normal)

func _handle_aim() -> void:
	var aim := get_global_mouse_position() - global_position
	if aim.length_squared() < 1.0:
		return
	aim_direction = aim.normalized()
	var angle := wrapf(aim.angle(), 0.0, TAU)
	var new_index := int(round(angle / (TAU / 8.0))) % 8
	if new_index != current_direction_index:
		current_direction_index = new_index
		_update_visual_animation()

func try_dash() -> bool:
	if _dash_timer > 0.0 or _dash_cooldown_timer > 0.0 or is_input_blocked:
		return false
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_direction = input_vector.normalized() if input_vector.length_squared() > 0.0 else aim_direction
	if _dash_direction.length_squared() < 0.01:
		return false
	_dash_timer = dash_duration
	_dash_iframe_timer = dash_iframe_duration
	_dash_cooldown_timer = dash_cooldown
	_dash_trail_timer = 0.0
	collision_mask = _normal_collision_mask & ~4
	if health_component != null:
		health_component.set_invulnerable(true)
	JuiceHelperClass.add_trauma(self, 0.08)
	return true

func shoot() -> void:
	if _shoot_timer > 0.0 or not _combat_state_allowed():
		return
	var spawn_position := global_position + Vector2(0.0, -32.0) + aim_direction * 16.0
	var critical := randf() < critical_chance
	var shot_damage := bullet_damage * critical_multiplier if critical else bullet_damage
	var projectile: Projectile = null
	var pool := get_tree().get_first_node_in_group("projectile_pool")
	if pool != null and pool.has_method("spawn"):
		projectile = pool.spawn(spawn_position, aim_direction, shot_damage, bullet_speed, self, critical)
	else:
		projectile = ProjectileScene.instantiate() as Projectile
		get_parent().add_child(projectile)
		projectile.setup(spawn_position, aim_direction, shot_damage, bullet_speed, self, critical)
	if projectile == null:
		return
	_shoot_timer = shoot_cooldown
	velocity -= aim_direction * recoil_push
	JuiceHelperClass.shot_feedback(self, spawn_position, aim_direction)
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.day_stats["ammo_consumed"] = int(gm.day_stats.get("ammo_consumed", 0)) + 1

func melee() -> int:
	if _melee_timer > 0.0 or not _combat_state_allowed() or _melee_shape == null:
		return 0
	_melee_timer = melee_cooldown
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _melee_shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 4
	query.collide_with_bodies = true
	var hits := get_world_2d().direct_space_state.intersect_shape(query, 24)
	var hit_health: Array[Node] = []
	var hit_count := 0
	var cone_cos := cos(deg_to_rad(melee_cone_angle) * 0.5)
	for hit in hits:
		var target := hit.get("collider") as Node2D
		if target == null or not target.is_in_group("zombies"):
			continue
		var to_target := target.global_position - global_position
		if to_target.length_squared() < 0.01 or aim_direction.dot(to_target.normalized()) < cone_cos:
			continue
		if not _melee_line_clear(target):
			continue
		var health := target.find_child("HealthComponent", true, false) as Node
		if health == null or health in hit_health:
			continue
		if health.has_method("apply_damage") and health.apply_damage(melee_damage, self):
			hit_health.append(health)
			hit_count += 1
	var pool := JuiceHelperClass.vfx(self)
	if pool != null:
		pool.spawn_melee_arc(global_position + Vector2(0.0, -24.0), aim_direction, melee_radius, deg_to_rad(melee_cone_angle), Color(1.0, 0.82, 0.3, 0.5))
	if hit_count > 0:
		JuiceHelperClass.hitstop(self, 0.05)
	return hit_count

func _melee_line_clear(target: Node2D) -> bool:
	var start := global_position + aim_direction * 32.0
	var query := PhysicsRayQueryParameters2D.create(start, target.global_position, 9, [get_rid(), target.get_rid()])
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _combat_state_allowed() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return true
	return gm.current_state == GameStateMachine.State.EXPEDITION or gm.current_state == GameStateMachine.State.NIGHT_DEFENSE

func _spawn_dash_ghost() -> void:
	var pool := JuiceHelperClass.vfx(self)
	if pool == null or visual == null or visual.sprite_frames == null:
		return
	var texture := visual.sprite_frames.get_frame_texture(visual.animation, 0)
	pool.spawn_ghost(texture, global_position + visual.offset)

func _end_dash() -> void:
	if _dash_timer <= 0.0 and collision_mask == _normal_collision_mask:
		return
	_dash_timer = 0.0
	_dash_iframe_timer = 0.0
	collision_mask = _normal_collision_mask
	if health_component != null:
		health_component.set_invulnerable(false)
	velocity *= 0.25

func _update_visual_animation() -> void:
	if visual == null or visual.sprite_frames == null:
		return
	var animation_name := "idle_" + DIRECTION_NAMES[current_direction_index]
	if visual.sprite_frames.has_animation(animation_name):
		visual.play(animation_name)

func _on_damage_taken(amount: float, source: Variant) -> void:
	var direction := Vector2.UP
	if source is Node2D:
		direction = (global_position - (source as Node2D).global_position).normalized()
		velocity += direction * 40.0
	JuiceHelperClass.white_flash(visual, 0.05)
	JuiceHelperClass.hit_feedback(self, global_position + Vector2(0.0, -48.0), direction, amount)

func _on_died(_source: Variant) -> void:
	_end_dash()
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return
	if gm.current_state == GameStateMachine.State.NIGHT_DEFENSE:
		gm.complete_night(false)
	elif gm.current_state == GameStateMachine.State.EXPEDITION:
		gm.complete_expedition(false)
