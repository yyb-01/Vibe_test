class_name SupplyCache
extends Area2D

@export var gold_reward: int = 35
@export var heal_amount: int = 18
var opened: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if opened or not body.is_in_group("player"):
		return
	opened = true
	RunStats.register_supply_cache()
	SaveManager.add_gold(gold_reward)
	if body.has_method("heal"):
		body.heal(heal_amount)
	AudioManager.play_named("pickup", -3.0, randf_range(0.82, 0.92))
	EventBus.supply_cache_opened.emit(RunStats.supply_caches_opened)
	queue_free()
