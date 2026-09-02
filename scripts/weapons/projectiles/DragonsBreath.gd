class_name DragonsBreath
extends "res://scripts/weapons/projectiles/ShotgunPellet.gd"

const FIRE_ZONE: PackedScene = preload("res://scenes/weapons/advanced/fire_zone.tscn")

func on_spawn(init_direction: Vector2 = Vector2.RIGHT, init_damage: float = 1.0,
		init_source: Node = null, _init_pierce: int = 999999, extras: Dictionary = {}) -> void:
	super.on_spawn(init_direction, init_damage, init_source, 999999, extras)
	remaining_pierce = 999999
	if bool(extras.get("spawn_zone", true)):
		spawn_effect(FIRE_ZONE, global_position + direction * 64.0, [damage * 0.35, 42.0 * float(extras.get("area_scale", 1.0)), init_source, 1.5, 0.2, Color(1.0, 0.28, 0.04, 1.0)])
