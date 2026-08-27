class_name Player
extends CharacterBody2D

@export var max_health: int = 100
@export var move_speed: float = 200.0
@export var current_weapon: WeaponData

var health: int
var current_ammo: int = 0
var is_reloading: bool = false
var can_shoot: bool = true
var fire_timer: Timer

const BULLET_SCENE: PackedScene = preload("res://scenes/weapons/bullet.tscn")

func _ready() -> void:
	health = max_health

	fire_timer = Timer.new()
	fire_timer.one_shot = true
	add_child(fire_timer)
	fire_timer.timeout.connect(_on_fire_timer_timeout)

	if current_weapon:
		current_ammo = current_weapon.magazine_size

func _physics_process(_delta: float) -> void:
	_handle_movement()
	_handle_aiming()
	_handle_shooting()
	_handle_reloading()

func _handle_movement() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * move_speed
	move_and_slide()

func _handle_aiming() -> void:
	look_at(get_global_mouse_position())

func _handle_shooting() -> void:
	if not current_weapon:
		return

	if Input.is_action_just_pressed("shoot") and can_shoot and not is_reloading:
		if current_ammo > 0:
			_shoot()
		else:
			_start_reload()

func _handle_reloading() -> void:
	if Input.is_action_just_pressed("reload") and not is_reloading and current_ammo < current_weapon.magazine_size:
		_start_reload()

func _shoot() -> void:
	can_shoot = false
	current_ammo -= 1

	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.global_position = global_position
	# Add a slight offset to spawn outside the player body if necessary, or let collision layer handle it
	# For simplicity, using mouse direction
	var dir := (get_global_mouse_position() - global_position).normalized()
	bullet.direction = dir
	bullet.damage = current_weapon.damage

	# Add to main scene tree
	get_tree().current_scene.add_child(bullet)

	fire_timer.start(current_weapon.fire_rate)

func _start_reload() -> void:
	is_reloading = true
	print("Reloading...")
	var reload_timer := get_tree().create_timer(current_weapon.reload_time)
	reload_timer.timeout.connect(_on_reload_finished)

func _on_reload_finished() -> void:
	current_ammo = current_weapon.magazine_size
	is_reloading = false
	print("Reload complete!")

func _on_fire_timer_timeout() -> void:
	can_shoot = true

func take_damage(amount: int) -> void:
	health -= amount
	print("Player took damage! Health: ", health)
	if health <= 0:
		die()

func die() -> void:
	print("Player died!")
	# Restart scene for now
	get_tree().reload_current_scene()
