class_name Weapon
extends Node

@export var data: WeaponData
var current_level: int = 1

var cooldown_timer: float = 0.0

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta

func fire(player: Player, target_pos: Vector2) -> bool:
	if cooldown_timer > 0:
		return false

	# Apply player modifiers
	var actual_fire_rate = data.fire_rate * player.reload_mult
	cooldown_timer = actual_fire_rate
	return true

func upgrade() -> void:
	current_level += 1
