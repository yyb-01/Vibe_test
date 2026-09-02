class_name PassiveData
extends "res://scripts/resources/item_data.gd"

@export_enum("fire_rate", "fire_damage", "crit_chance", "area", "cooldown", "magnet") var stat_type: String = "fire_rate"
@export var value_per_level: float = 0.05

func value_at_level(level: int) -> float:
	return value_per_level * float(clampi(level, 1, max_level))
