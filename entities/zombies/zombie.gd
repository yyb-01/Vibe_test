class_name Zombie
extends CharacterBody2D

# res://entities/zombies/zombie.gd
# Zombie AI with NavigationAgent2D and breakthrough vs detour cost evaluation per Section E.2

const HealthComponentClass = preload("res://scripts/components/health_component.gd")
const StructureBaseClass = preload("res://entities/structures/structure_base.gd")

signal zombie_died(zombie: CharacterBody2D)

enum State { SPAWN, SEEK, MOVE, ATTACK, DEAD }

@export var move_speed: float = 110.0
@export var attack_damage: float = 15.0
@export var attacks_per_second: float = 1.0
@export var attack_range: float = 38.0
@export var player_aggro_radius: float = 180.0

var current_state: State = State.SPAWN
var current_target: Node2D = null

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var health_component: HealthComponentClass = $HealthComponent
@onready var visual: Sprite2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _attack_timer: float = 0.0
var _repath_timer: float = 0.0

var _cached_player: Node2D = null
var _cached_core: Node2D = null

func _ready() -> void:
	collision_layer = 4 # Layer 3: Enemy
	collision_mask = 11 # Layer 1 (World=1) + Layer 2 (Player=2) + Layer 4 (Structure=8) -> 11
	
	if health_component != null:
		health_component.damage_taken.connect(_on_damage_taken)
		health_component.died.connect(_on_died)
		
	if nav_agent != null:
		nav_agent.path_desired_distance = 18.0
		nav_agent.target_desired_distance = 28.0
		
	_repath_timer = randf_range(0.05, 0.45)
	current_state = State.SEEK

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
		
	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _repath_timer > 0.0:
		_repath_timer -= delta
		
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
	# Priority 1: Player if in aggro range
	var player: Node2D = _find_player()
	if player != null and global_position.distance_to(player.global_position) <= player_aggro_radius:
		current_target = player
		_set_nav_target(player.global_position)
		return
		
	# Priority 2: Base Core
	var core: Node2D = _find_core()
	if core == null:
		current_target = player
		if player != null:
			_set_nav_target(player.global_position)
		return
		
	# Priority 3: Breakthrough vs Detour evaluation (Section E.2)
	var blocking_structure: StructureBaseClass = _find_blocking_structure_toward(core.global_position)
	if blocking_structure != null:
		var detour_dist: float = global_position.distance_to(core.global_position) * 1.8 # Detour estimate
		var detour_time: float = detour_dist / maxf(move_speed, 1.0)
		
		var zombie_dps: float = attack_damage * attacks_per_second
		var struct_hp: float = blocking_structure.current_health
		var breakthrough_time: float = struct_hp / maxf(zombie_dps, 1.0)
		
		# If breakthrough is faster than detour, target and destroy the blocking structure
		if breakthrough_time < detour_time:
			current_target = blocking_structure
			_set_nav_target(blocking_structure.global_position)
			return
			
	current_target = core
	_set_nav_target(core.global_position)

func _set_nav_target(target_pos: Vector2) -> void:
	if nav_agent != null:
		nav_agent.target_position = target_pos
		_repath_timer = 0.4 + randf_range(-0.05, 0.05)

func _handle_move(_delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		current_state = State.SEEK
		velocity = Vector2.ZERO
		return
		
	var dist_to_target: float = global_position.distance_to(current_target.global_position)
	if dist_to_target <= attack_range:
		current_state = State.ATTACK
		velocity = Vector2.ZERO
		return
		
	# Repath periodically
	if _repath_timer <= 0.0:
		_set_nav_target(current_target.global_position)
		
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var dir: Vector2 = (next_pos - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()

func _handle_attack() -> void:
	if current_target == null or not is_instance_valid(current_target):
		current_state = State.SEEK
		return
		
	var dist: float = global_position.distance_to(current_target.global_position)
	if dist > attack_range * 1.3:
		current_state = State.MOVE
		return
		
	if _attack_timer <= 0.0:
		_attack_timer = 1.0 / attacks_per_second
		_apply_attack_damage(current_target)

func _apply_attack_damage(target: Node2D) -> void:
	if target == null:
		return
		
	# Visual attack lunge
	if visual != null:
		var dir = (target.global_position - global_position).normalized()
		var tween = create_tween()
		tween.tween_property(visual, "position", dir * 6.0, 0.08)
		tween.tween_property(visual, "position", Vector2.ZERO, 0.1)
		
	var health = target.find_child("HealthComponent", true, false)
	if health != null and health.has_method("apply_damage"):
		health.apply_damage(attack_damage, self)
	elif target.has_method("receive_damage"):
		target.receive_damage(attack_damage, self)
	elif target.has_method("apply_damage"):
		target.apply_damage(attack_damage, self)

func _find_player() -> Node2D:
	if _cached_player != null and is_instance_valid(_cached_player) and _cached_player.is_inside_tree():
		return _cached_player
	if get_tree() != null and get_tree().root != null:
		_cached_player = get_tree().root.find_child("Player", true, false) as Node2D
	return _cached_player

func _find_core() -> Node2D:
	if _cached_core != null and is_instance_valid(_cached_core) and _cached_core.is_inside_tree():
		return _cached_core
	if get_tree() != null and get_tree().root != null:
		_cached_core = get_tree().root.find_child("BaseCore", true, false) as Node2D
	return _cached_core

func _find_blocking_structure_toward(target_pos: Vector2) -> StructureBaseClass:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target_pos, 8, [get_rid()])
	var result := space_state.intersect_ray(query)
	if not result.is_empty() and result.collider is StructureBaseClass:
		return result.collider as StructureBaseClass
	return null

func _on_damage_taken(_amount: float, _source: Variant) -> void:
	if visual != null:
		visual.modulate = Color(2.0, 0.3, 0.3)
		var tween = create_tween()
		tween.tween_property(visual, "modulate", Color.WHITE, 0.06)

func _on_died(_source: Variant) -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	zombie_died.emit(self)
	
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
		
	var tween = create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
