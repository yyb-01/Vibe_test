class_name Zombie
extends CharacterBody2D

const HealthComponentClass = preload("res://scripts/components/health_component.gd")
const StructureBaseClass = preload("res://entities/structures/structure_base.gd")
const JuiceHelperClass = preload("res://scripts/systems/juice_helper.gd")

signal zombie_died(zombie: CharacterBody2D)

enum State { SPAWN, SEEK, MOVE, ATTACK, DEAD }

@export var move_speed: float = 110.0
@export var acceleration: float = 1050.0
@export var attack_damage: float = 15.0
@export var attacks_per_second: float = 1.0
@export var attack_range: float = 38.0
@export var player_aggro_radius: float = 180.0
@export_range(0.05, 0.5) var navigation_tick_interval: float = 0.16
@export var separation_strength: float = 145.0

var current_state: State = State.SPAWN
var current_target: Node2D = null

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var health_component: HealthComponentClass = $HealthComponent
@onready var visual: Sprite2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var separation_area: Area2D = get_node_or_null("SeparationArea")

var _attack_timer: float = 0.0
var _repath_timer: float = 0.0
var _navigation_tick_timer: float = 0.0
var _stun_timer: float = 0.0
var _speed_multiplier: float = 1.0
var _next_path_position: Vector2 = Vector2.ZERO
var _nearby_zombies: Array[Node2D] = []
var _cached_player: Node2D = null
var _cached_core: Node2D = null

func _ready() -> void:
	add_to_group("zombies")
	collision_layer = 4
	collision_mask = 11
	safe_margin = 0.08
	max_slides = 4
	_speed_multiplier = randf_range(0.85, 1.15)
	_repath_timer = randf_range(0.05, 0.45)
	_navigation_tick_timer = randf_range(0.0, navigation_tick_interval)
	if health_component != null:
		health_component.damage_taken.connect(_on_damage_taken)
		health_component.died.connect(_on_died)
	if nav_agent != null:
		nav_agent.path_desired_distance = 18.0
		nav_agent.target_desired_distance = 28.0
		# Local separation is cheaper and deterministic for the 150+ horde case.
		nav_agent.avoidance_enabled = false
	if separation_area != null:
		separation_area.collision_layer = 0
		separation_area.collision_mask = 4
		separation_area.body_entered.connect(_on_separation_entered)
		separation_area.body_exited.connect(_on_separation_exited)
	current_state = State.SEEK

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_repath_timer = maxf(0.0, _repath_timer - delta)
	_navigation_tick_timer = maxf(0.0, _navigation_tick_timer - delta)
	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		move_and_slide()
		return

	match current_state:
		State.SPAWN, State.SEEK:
			_evaluate_target_and_route()
			if current_target != null:
				current_state = State.MOVE
		State.MOVE:
			_handle_move(delta)
		State.ATTACK:
			_handle_attack()

func _evaluate_target_and_route() -> void:
	var player := _find_player()
	if player != null and global_position.distance_to(player.global_position) <= player_aggro_radius:
		current_target = player
		_set_nav_target(player.global_position)
		return
	var core := _find_core()
	if core == null:
		current_target = player
		if player != null:
			_set_nav_target(player.global_position)
		return
	var blocking_structure := _find_blocking_structure_toward(core.global_position)
	if blocking_structure != null:
		var detour_time := global_position.distance_to(core.global_position) * 1.8 / maxf(move_speed, 1.0)
		var breakthrough_time := blocking_structure.current_health / maxf(attack_damage * attacks_per_second, 1.0)
		if breakthrough_time < detour_time:
			current_target = blocking_structure
			_set_nav_target(blocking_structure.global_position)
			return
	current_target = core
	_set_nav_target(core.global_position)

func _set_nav_target(target_position: Vector2) -> void:
	if nav_agent != null:
		nav_agent.target_position = target_position
	_next_path_position = target_position
	_repath_timer = 0.4 + randf_range(-0.05, 0.05)

func _handle_move(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		current_state = State.SEEK
		velocity = Vector2.ZERO
		return
	var distance := global_position.distance_to(current_target.global_position)
	if distance <= attack_range:
		current_state = State.ATTACK
		velocity = Vector2.ZERO
		return
	if _repath_timer <= 0.0:
		_set_nav_target(current_target.global_position)
	if _navigation_tick_timer <= 0.0:
		_navigation_tick_timer = navigation_tick_interval + randf_range(-0.03, 0.03)
		if nav_agent != null:
			_next_path_position = nav_agent.get_next_path_position()
		if _next_path_position.distance_squared_to(global_position) < 1.0:
			_next_path_position = current_target.global_position
	var next_position := _next_path_position
	var direction := (next_position - global_position).normalized()
	var desired := direction * move_speed * _speed_multiplier + _get_separation() * separation_strength
	desired = desired.limit_length(move_speed * 1.25)
	velocity = velocity.move_toward(desired, acceleration * delta)
	move_and_slide()

func _handle_attack() -> void:
	if current_target == null or not is_instance_valid(current_target):
		current_state = State.SEEK
		return
	if global_position.distance_to(current_target.global_position) > attack_range * 1.3:
		current_state = State.MOVE
		return
	var health = current_target.find_child("HealthComponent", true, false)
	if health != null and bool(health.get("is_dead")):
		current_state = State.SEEK
		return
	if _attack_timer <= 0.0:
		_attack_timer = 1.0 / maxf(attacks_per_second, 0.01)
		_apply_attack_damage(current_target)

func _apply_attack_damage(target: Node2D) -> void:
	if target == null:
		return
	var direction := (target.global_position - global_position).normalized()
	var applied := false
	if target.has_method("receive_damage"):
		applied = target.receive_damage(attack_damage, self)
	if not applied:
		var health = target.find_child("HealthComponent", true, false)
		if health != null and health.has_method("apply_damage"):
			applied = health.apply_damage(attack_damage, self)
	if visual != null:
		var tween := create_tween()
		tween.tween_property(visual, "position", direction * 6.0, 0.06)
		tween.tween_property(visual, "position", Vector2.ZERO, 0.1)
	if applied:
		JuiceHelperClass.hitstop(self, 0.035)

func _get_separation() -> Vector2:
	var force := Vector2.ZERO
	for i in range(_nearby_zombies.size() - 1, -1, -1):
		var other := _nearby_zombies[i]
		if not is_instance_valid(other) or not other.is_inside_tree():
			_nearby_zombies.remove_at(i)
			continue
		var offset := global_position - other.global_position
		var distance := offset.length()
		if distance < 0.01:
			force += Vector2.RIGHT.rotated(float(get_instance_id() % 11))
		elif distance < 52.0:
			force += offset / distance * (1.0 - distance / 52.0)
	return force.limit_length(1.0)

func _find_player() -> Node2D:
	if _cached_player != null and is_instance_valid(_cached_player) and _cached_player.is_inside_tree():
		return _cached_player
	_cached_player = get_tree().root.find_child("Player", true, false) as Node2D
	return _cached_player

func _find_core() -> Node2D:
	if _cached_core != null and is_instance_valid(_cached_core) and _cached_core.is_inside_tree():
		return _cached_core
	_cached_core = get_tree().root.find_child("BaseCore", true, false) as Node2D
	return _cached_core

func _find_blocking_structure_toward(target_position: Vector2) -> StructureBaseClass:
	var query := PhysicsRayQueryParameters2D.create(global_position, target_position, 8, [get_rid()])
	query.collide_with_bodies = true
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	return result.collider as StructureBaseClass if not result.is_empty() and result.collider is StructureBaseClass else null

func _on_damage_taken(amount: float, source: Variant) -> void:
	var direction := Vector2.UP
	if source is Node2D:
		direction = (global_position - (source as Node2D).global_position).normalized()
		velocity += direction * 170.0
		_stun_timer = 0.08
	var critical := bool(source.get("critical")) if source is Object and source.get("critical") != null else false
	JuiceHelperClass.white_flash(visual, 0.05)
	JuiceHelperClass.hit_feedback(self, global_position + Vector2(0.0, -30.0), direction, amount, critical)

func _on_died(_source: Variant) -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.day_stats["zombies_killed"] = int(gm.day_stats.get("zombies_killed", 0)) + 1
	zombie_died.emit(self)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

func _on_separation_entered(body: Node2D) -> void:
	if body != self and body.is_in_group("zombies") and body not in _nearby_zombies:
		_nearby_zombies.append(body)

func _on_separation_exited(body: Node2D) -> void:
	_nearby_zombies.erase(body)
