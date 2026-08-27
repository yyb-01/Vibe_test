class_name Player
extends CharacterBody2D

@export var max_health: int = 100
@export var move_speed: float = 200.0
@export var current_weapon: WeaponData

var health: int
var current_exp: int = 0
var required_exp: int = 50
var current_level: int = 1

# Perk Multipliers
var damage_mult: float = 1.0
var speed_mult: float = 1.0
var reload_mult: float = 1.0
var pierce_add: int = 0

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

	# Delay emitting signals slightly so HUD is ready
	call_deferred("_update_ui")

func _update_ui() -> void:
	EventBus.player_health_changed.emit(health, max_health)
	EventBus.exp_changed.emit(current_exp, required_exp, current_level)

func _physics_process(_delta: float) -> void:
	_handle_movement()
	_handle_auto_shooting()

func _handle_movement() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * (move_speed * speed_mult)
	move_and_slide()

func _handle_auto_shooting() -> void:
	if not current_weapon or not can_shoot:
		return

	var target = _get_closest_enemy()
	if target:
		look_at(target.global_position)
		_shoot(target.global_position)

func _get_closest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var min_dist = INF

	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		# Add a maximum range logic here if desired, e.g., if dist < 800.0:
		if dist < min_dist:
			min_dist = dist
			closest = enemy

	return closest

func _shoot(target_pos: Vector2) -> void:
	can_shoot = false

	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.global_position = global_position

	var dir := (target_pos - global_position).normalized()
	bullet.direction = dir
	bullet.damage = int(current_weapon.damage * damage_mult)
	bullet.pierce_count = pierce_add

	get_tree().current_scene.add_child(bullet)

	var actual_fire_rate = current_weapon.fire_rate * reload_mult
	fire_timer.start(actual_fire_rate)

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
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/main_menu.tscn")

func heal(amount: int) -> void:
	health += amount
	if health > max_health:
		health = max_health
	EventBus.player_health_changed.emit(health, max_health)
	print("Player healed! Health: ", health)

func add_exp(amount: int) -> void:
	current_exp += amount
	if current_exp >= required_exp:
		_level_up()
	EventBus.exp_changed.emit(current_exp, required_exp, current_level)

func _level_up() -> void:
	current_level += 1
	current_exp -= required_exp
	required_exp = int(float(required_exp) * 1.2) # Exponential exp curve

	EventBus.level_up.emit()
	EventBus.exp_changed.emit(current_exp, required_exp, current_level)

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
