class_name Weapon
extends Node

@export var data: WeaponData
var current_level: int = 1

var cooldown_timer: float = 0.0
var reload_timer: float = 0.0
var ammo_in_magazine: int = 0

func _ready() -> void:
	if data:
		ammo_in_magazine = data.magazine_size

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta
	if reload_timer > 0:
		reload_timer -= delta
		if reload_timer <= 0 and data:
			reload_timer = 0
			ammo_in_magazine = data.magazine_size

func fire(player: Player, target_pos: Vector2) -> bool:
	if not data or cooldown_timer > 0 or reload_timer > 0:
		return false
	if data.magazine_size > 0 and ammo_in_magazine <= 0:
		reload(player)
		return false

	# Apply player modifiers
	var actual_fire_rate = data.fire_rate * player.reload_mult
	cooldown_timer = actual_fire_rate
	if data.magazine_size > 0:
		ammo_in_magazine -= 1
	return true

func reload(player: Player) -> void:
	if not data or data.magazine_size <= 0 or reload_timer > 0:
		return
	if ammo_in_magazine >= data.magazine_size:
		return
	reload_timer = data.reload_time * player.reload_mult
	if reload_timer <= 0:
		ammo_in_magazine = data.magazine_size

func upgrade() -> void:
	current_level += 1
