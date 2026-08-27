class_name DamageNumber
extends Node2D

@onready var label: Label = $Label

var amount: int = 0
var is_critical: bool = false

func _ready() -> void:
	label.text = str(amount)

	if is_critical:
		label.modulate = Color(1.0, 0.2, 0.2, 1.0)
		label.scale = Vector2(1.5, 1.5)

	# Floating and fading animation using Tween
	var tween := create_tween()
	tween.set_parallel(true)

	# Move up randomly slightly
	var random_offset := Vector2(randf_range(-20, 20), -50)
	tween.tween_property(self, "position", position + random_offset, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.2)

	tween.chain().tween_callback(queue_free)
