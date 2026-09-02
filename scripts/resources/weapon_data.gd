class_name WeaponData
extends "res://scripts/resources/item_data.gd"

@export var weapon_name: String = "Pistol"
@export var damage: float = 15.0
@export var cooldown: float = 0.0
@export var fire_rate: float = 0.25 # Time in seconds between shots
@export var magazine_size: int = 12
@export var reload_time: float = 1.5 # Time in seconds to reload
@export var projectile_count: int = 1
@export var pierce: int = 0
@export var speed: float = 0.0
@export var projectile_speed: float = 700.0
@export var spread_angle: float = 0.0
@export var area_scale: float = 1.0
@export var knockback: float = 0.0
@export var projectile_scene: PackedScene
@export var is_evolution: bool = false

func get_id() -> String:
	return id if not id.is_empty() else weapon_name.to_snake_case()

func get_display_name() -> String:
	return display_name if not display_name.is_empty() else weapon_name

func get_cooldown() -> float:
	return cooldown if cooldown > 0.0 else fire_rate

func get_speed() -> float:
	return speed if speed > 0.0 else projectile_speed
