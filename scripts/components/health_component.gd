class_name HealthComponent
extends Node

# res://scripts/components/health_component.gd
# Universal health management component per Section E.3 of game_system_architecture.md

signal health_changed(current: float, maximum: float)
signal damage_taken(amount: float, source: Variant)
signal died(source: Variant)

@export var max_health: float = 100.0
@export var invulnerability_time: float = 0.0

var current_health: float = 100.0
var is_dead: bool = false
var _invulnerability_timer: float = 0.0

func _ready() -> void:
	current_health = max_health

func _process(delta: float) -> void:
	if _invulnerability_timer > 0.0:
		_invulnerability_timer -= delta

func apply_damage(amount: float, source: Variant = null) -> bool:
	if is_dead or amount <= 0.0:
		return false
	if _invulnerability_timer > 0.0:
		return false
		
	var actual_damage: float = minf(amount, current_health)
	current_health = maxf(0.0, current_health - actual_damage)
	
	if invulnerability_time > 0.0:
		_invulnerability_timer = invulnerability_time
		
	damage_taken.emit(actual_damage, source)
	health_changed.emit(current_health, max_health)
	
	var event_bus = get_node_or_null("/root/EventBus")
	if owner != null and event_bus != null:
		event_bus.health_changed.emit(owner, current_health, max_health)
		
	if current_health <= 0.0 and not is_dead:
		is_dead = true
		died.emit(source)
		
	return true

func heal(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
		
	var needed: float = max_health - current_health
	var actual_heal: float = minf(amount, needed)
	current_health = minf(max_health, current_health + actual_heal)
	
	if actual_heal > 0.0:
		health_changed.emit(current_health, max_health)
		var event_bus = get_node_or_null("/root/EventBus")
		if owner != null and event_bus != null:
			event_bus.health_changed.emit(owner, current_health, max_health)
			
	return actual_heal

func reset() -> void:
	is_dead = false
	current_health = max_health
	_invulnerability_timer = 0.0
	health_changed.emit(current_health, max_health)
