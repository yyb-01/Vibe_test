class_name HitboxComponent
extends Area2D

# res://scripts/components/hitbox_component.gd
# Receives hits and forwards damage to HealthComponent per Section E.3

const HealthComponentClass = preload("res://scripts/components/health_component.gd")

@export var health_component: HealthComponentClass

func _ready() -> void:
	if health_component == null and get_parent() != null:
		health_component = get_parent().find_child("HealthComponent", true, false) as HealthComponentClass

func receive_damage(amount: float, source: Node = null) -> bool:
	if health_component != null:
		return health_component.apply_damage(amount, source)
	return false
