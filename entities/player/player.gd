class_name Player
extends CharacterBody2D

# res://entities/player/player.gd
# Player character with 8-direction movement, aiming, ranged shooting, and HealthComponent

const DIRECTION_NAMES: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const ProjectileScene = preload("res://entities/combat/projectile.tscn")
const HealthComponentClass = preload("res://scripts/components/health_component.gd")
const GameStateMachine = preload("res://scripts/core/game_state_machine.gd")

@export var move_speed: float = 220.0
@export var shoot_cooldown: float = 0.2
@export var bullet_damage: float = 25.0
@export var bullet_speed: float = 650.0

@onready var visual: AnimatedSprite2D = $Visual
@onready var health_component: HealthComponentClass = $HealthComponent

var aim_direction: Vector2 = Vector2.RIGHT
var current_direction_index: int = 0 # 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE

var _shoot_timer: float = 0.0

var is_input_blocked: bool = false
var _is_firing: bool = false

func _ready() -> void:
	_update_visual_animation()
	if health_component != null:
		health_component.damage_taken.connect(_on_damage_taken)
		health_component.died.connect(_on_died)
	var eb = get_node_or_null("/root/EventBus")
	if eb != null:
		eb.game_state_changed.connect(_on_game_state_changed)
	_update_control_state()

func _on_game_state_changed(_prev: int, _curr: int) -> void:
	_update_control_state()

func _update_control_state() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var state: int = gm.current_state
	if state == GameStateMachine.State.HUB or state == GameStateMachine.State.DAY_SUMMARY:
		is_input_blocked = true
		_is_firing = false
		velocity = Vector2.ZERO
	else:
		is_input_blocked = false

func _unhandled_input(event: InputEvent) -> void:
	if is_input_blocked:
		return
		
	if event.is_action_pressed("shoot"):
		var gm = get_node_or_null("/root/GameManager")
		if gm != null:
			var state: int = gm.current_state
			if state != GameStateMachine.State.EXPEDITION and state != GameStateMachine.State.NIGHT_DEFENSE:
				return
		_is_firing = true
		if _shoot_timer <= 0.0:
			shoot()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("shoot"):
		_is_firing = false
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if is_input_blocked:
		velocity = Vector2.ZERO
		return
		
	_handle_movement()
	_handle_aim()
	
	if _shoot_timer > 0.0:
		_shoot_timer -= delta
		
	if _is_firing and _shoot_timer <= 0.0:
		var gm = get_node_or_null("/root/GameManager")
		if gm != null:
			var state: int = gm.current_state
			if state == GameStateMachine.State.EXPEDITION or state == GameStateMachine.State.NIGHT_DEFENSE:
				shoot()

func _handle_movement() -> void:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input * move_speed
	move_and_slide()

func _handle_aim() -> void:
	var aim: Vector2 = get_global_mouse_position() - global_position
	if aim.length_squared() >= 1.0:
		aim_direction = aim.normalized()
		var angle: float = wrapf(aim.angle(), 0.0, TAU)
		var new_index: int = int(round(angle / (TAU / 8.0))) % 8
		if new_index != current_direction_index:
			current_direction_index = new_index
			_update_visual_animation()



func shoot() -> void:
	if _shoot_timer > 0.0:
		return
	_shoot_timer = shoot_cooldown
	
	var spawn_pos: Vector2 = global_position + Vector2(0, -32) + aim_direction * 16.0
	var projectile = ProjectileScene.instantiate()
	projectile.setup(spawn_pos, aim_direction, bullet_damage, bullet_speed, self)
	if get_parent() != null:
		get_parent().add_child(projectile)
	
	# Muzzle recoil flash (F.2)
	if visual != null:
		var tween = create_tween()
		tween.tween_property(visual, "position", -aim_direction * 2.5, 0.03)
		tween.tween_property(visual, "position", Vector2.ZERO, 0.05)

func _update_visual_animation() -> void:
	if visual == null:
		return
	var dir_name: String = DIRECTION_NAMES[current_direction_index]
	var anim_name: String = "idle_" + dir_name
	if visual.sprite_frames and visual.sprite_frames.has_animation(anim_name):
		visual.play(anim_name)

func _on_damage_taken(_amount: float, _source: Variant) -> void:
	if visual != null:
		visual.modulate = Color(2.0, 0.4, 0.4)
		var tween = create_tween()
		tween.tween_property(visual, "modulate", Color.WHITE, 0.06)

func _on_died(_source: Variant) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm != null:
		if gm.current_state == GameStateMachine.State.NIGHT_DEFENSE:
			gm.complete_night(false)
		elif gm.current_state == GameStateMachine.State.EXPEDITION:
			gm.complete_expedition(false)
