class_name Survivor
extends Area2D

@export var rescue_reward: int = 50
var rescued: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if rescued or not body.is_in_group("player"):
		return
	rescued = true
	RunStats.register_rescue()
	SaveManager.add_gold(rescue_reward)
	EventBus.survivor_rescued.emit(RunStats.survivors_rescued)
	queue_free()
