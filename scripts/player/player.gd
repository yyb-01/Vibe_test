class_name Player
extends CharacterBody2D

@export var max_health: int = 100
@export var move_speed: float = 200.0
@export var current_weapon: WeaponData

var health: int
var current_ammo: int = 0
var reserve_ammo: int = 36
const MAX_RESERVE_AMMO: int = 120

# Perk Multipliers
var damage_mult: float = 1.0
var speed_mult: float = 1.0
var reload_mult: float = 1.0
var pierce_add: int = 0

var is_reloading: bool = false
var can_shoot: bool = true
var fire_timer: Timer

const BULLET_SCENE: PackedScene = preload("res://scenes/weapons/bullet.tscn")

func _ready() -> void:
	health = max_health

	EventBus.perk_selected.connect(apply_perk)

	fire_timer = Timer.new()
	fire_timer.one_shot = true
	add_child(fire_timer)
	fire_timer.timeout.connect(_on_fire_timer_timeout)

	if current_weapon:
		current_ammo = current_weapon.magazine_size

	# Delay emitting signals slightly so HUD is ready
	call_deferred("_update_ui")

func _update_ui() -> void:
	EventBus.player_health_changed.emit(health, max_health)
	EventBus.ammo_changed.emit(current_ammo, reserve_ammo)

func _physics_process(_delta: float) -> void:
	_handle_movement()
	_handle_aiming()
	_handle_shooting()
	_handle_reloading()

func _handle_movement() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * (move_speed * speed_mult)
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
	if Input.is_action_just_pressed("reload") and not is_reloading and current_ammo < current_weapon.magazine_size and reserve_ammo > 0:
		_start_reload()

func _shoot() -> void:
	can_shoot = false
	current_ammo -= 1
	EventBus.ammo_changed.emit(current_ammo, reserve_ammo)

	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.global_position = global_position
	# Add a slight offset to spawn outside the player body if necessary, or let collision layer handle it
	# For simplicity, using mouse direction
	var dir := (get_global_mouse_position() - global_position).normalized()
	bullet.direction = dir
	bullet.damage = int(current_weapon.damage * damage_mult)
	bullet.pierce_count = pierce_add

	# Add to main scene tree
	get_tree().current_scene.add_child(bullet)

	fire_timer.start(current_weapon.fire_rate)

func _start_reload() -> void:
	if reserve_ammo <= 0:
		return

	is_reloading = true
	print("Reloading...")
	var actual_reload_time := current_weapon.reload_time * reload_mult
	var reload_timer := get_tree().create_timer(actual_reload_time)
	reload_timer.timeout.connect(_on_reload_finished)

func _on_reload_finished() -> void:
	var ammo_needed: int = current_weapon.magazine_size - current_ammo
	var ammo_to_load: int = min(ammo_needed, reserve_ammo)

	current_ammo += ammo_to_load
	reserve_ammo -= ammo_to_load

	is_reloading = false
	print("Reload complete!")
	EventBus.ammo_changed.emit(current_ammo, reserve_ammo)

func _on_fire_timer_timeout() -> void:
	can_shoot = true

func take_damage(amount: int) -> void:
	health -= amount
	print("Player took damage! Health: ", health)
	EventBus.player_health_changed.emit(health, max_health)

	if health <= 0:
		die()

func die() -> void:
	print("Player died!")
	# Use call_deferred to safely change scenes without crashing during physics steps
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/main_menu.tscn")

func heal(amount: int) -> void:
	health += amount
	if health > max_health:
		health = max_health
	EventBus.player_health_changed.emit(health, max_health)
	print("Player healed! Health: ", health)

func add_ammo(amount: int) -> void:
	reserve_ammo += amount
	if reserve_ammo > MAX_RESERVE_AMMO:
		reserve_ammo = MAX_RESERVE_AMMO
	EventBus.ammo_changed.emit(current_ammo, reserve_ammo)
	print("Got ammo! Reserve: ", reserve_ammo)

func apply_perk(perk: PerkData) -> void:
	print("Applying perk: ", perk.perk_name)
	damage_mult *= perk.damage_mult
	speed_mult *= perk.speed_mult
	reload_mult *= perk.reload_speed_mult
	pierce_add += perk.pierce_add

	if perk.max_hp_add > 0:
		max_health += perk.max_hp_add
		health += perk.max_hp_add
		EventBus.player_health_changed.emit(health, max_health)
