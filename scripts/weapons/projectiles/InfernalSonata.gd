class_name InfernalSonata
extends "res://scripts/weapons/projectiles/FlameStream.gd"

func _on_flame_hit(target: Node2D) -> void:
	target.set_meta("blue_fire", true)
	target.set_meta("blue_fire_damage", maxi(1, roundi(damage * 0.75)))
	target.set_meta("blue_fire_weapon_id", source_weapon_id)
	super._on_flame_hit(target)
