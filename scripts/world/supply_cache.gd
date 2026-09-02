class_name SupplyCache
extends Area2D

@export var gold_reward: int = 35
@export var heal_amount: int = 25
@export var lifetime: float = 0.0
var opened: bool = false
var age: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if lifetime <= 0.0 or opened:
		return
	age += delta
	if age >= lifetime:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if opened or not is_instance_valid(body) or body.is_queued_for_deletion() or not body.is_in_group("player"):
		return
	opened = true
	RunStats.register_supply_cache()
	SaveManager.add_gold(gold_reward)
	if body.has_method("heal"):
		body.heal(heal_amount)
	EventBus.supply_cache_opened.emit(RunStats.supply_caches_opened)
	queue_free()
