class_name PerkData
extends Resource

@export var id: String = ""
@export var perk_name: String = ""
@export_multiline var description: String = ""
@export var level: int = 1

# Multipliers and Additions
@export var damage_mult: float = 1.0
@export var speed_mult: float = 1.0
@export var reload_speed_mult: float = 1.0 # Lower is faster (e.g. 0.75 for 25% faster)
@export var pierce_add: int = 0
@export var max_hp_add: int = 0
