class_name Player
extends CharacterBody2D

@export var max_health: int = 100
@export var move_speed: float = 200.0
var weapons: Array[Weapon] = []
var max_weapons: int = 6
var passives: Array[PerkData] = []
var max_passives: int = 6

var health: int
var current_exp: int = 0
var required_exp: int = 50
var current_level: int = 1

# Perk Multipliers
var damage_mult: float = 1.0
var speed_mult: float = 1.0
var reload_mult: float = 1.0
var pierce_add: int = 0

const BULLET_SCENE: PackedScene = preload("res://scenes/weapons/bullet.tscn")

func _ready() -> void:
	# Initialize default starting weapon
	var starting_weap_data = preload("res://data/perks/weap_pistol.tres")
	add_weapon(starting_weap_data.weapon_script, starting_weap_data.weapon_data)

	# Apply meta-progression
	max_health += SaveManager.upgrade_max_hp * 20
	damage_mult += SaveManager.upgrade_damage * 0.1
	speed_mult += SaveManager.upgrade_speed * 0.05

	health = max_health

	EventBus.perk_selected.connect(apply_perk)

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
	# Always aim at the mouse cursor
	look_at(get_global_mouse_position())

	# Iterate over all weapons and attempt to fire
	var target_pos = get_global_mouse_position()
	for weapon in weapons:
		weapon.fire(self, target_pos)

func add_weapon(weapon_script: Script, data: WeaponData) -> void:
	if weapons.size() >= max_weapons:
		return
	var w = weapon_script.new()
	w.data = data
	add_child(w)
	weapons.append(w)
	EventBus.inventory_updated.emit(weapons, passives)

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
	passives.append(perk)
	damage_mult *= perk.damage_mult
	speed_mult *= perk.speed_mult
	reload_mult *= perk.reload_speed_mult
	pierce_add += perk.pierce_add

	if perk.max_hp_add > 0:
		max_health += perk.max_hp_add
		health += perk.max_hp_add
		EventBus.player_health_changed.emit(health, max_health)

	EventBus.inventory_updated.emit(weapons, passives)
