class_name DamageNumber
extends Node2D

@onready var label: Label = $Label

var amount: int = 0
var is_critical: bool = false

func _ready() -> void:
	reset()

func reset() -> void:
	label.text = str(amount)
	modulate.a = 1.0

	if is_critical:
		label.modulate = Color(1.0, 0.2, 0.2, 1.0)
		label.scale = Vector2(1.5, 1.5)
	else:
		label.modulate = Color.WHITE
		label.scale = Vector2(1.0, 1.0)

	var tween := create_tween()
	tween.set_parallel(true)

	var random_offset := Vector2(randf_range(-20, 20), -50)
	tween.tween_property(self, "position", position + random_offset, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.2)

	tween.chain().tween_callback(func(): ObjectPoolManager.release(self))
