class_name DamageNumber
extends Node2D

@onready var label: Label = $Label

var amount: int = 0:
	set(value):
		amount = value
		if is_node_ready():
			label.text = str(amount)
var is_critical: bool = false
var hit_kind: String = "normal"
var active_tween: Tween

func _ready() -> void:
	reset()

func reset() -> void:
	if active_tween:
		active_tween.kill()
	is_critical = false
	hit_kind = "normal"
	label.text = str(amount)
	modulate.a = 1.0
	_apply_style()

func configure(value: int, kind: String = "normal") -> void:
	amount = value
	hit_kind = kind
	is_critical = kind == "critical"
	label.text = str(amount)
	_apply_style()
	_start_animation()

func _apply_style() -> void:
	match hit_kind:
		"critical":
			label.modulate = Color(1.0, 0.82, 0.18, 1.0)
			label.scale = Vector2(1.65, 1.65)
			label.text = "✦ %d" % amount
		"execute":
			label.modulate = Color(1.0, 0.18, 0.28, 1.0)
			label.scale = Vector2(1.9, 1.9)
			label.text = "처형 %d" % amount
		"heavy":
			label.modulate = Color(0.35, 0.9, 1.0, 1.0)
			label.scale = Vector2(1.3, 1.3)
		_:
			label.modulate = Color.WHITE
			label.scale = Vector2.ONE

func _start_animation() -> void:
	if active_tween:
		active_tween.kill()
	active_tween = create_tween()
	active_tween.set_parallel(true)
	var random_offset := Vector2(randf_range(-24, 24), -58 if hit_kind != "normal" else -48)
	active_tween.tween_property(self, "position", position + random_offset, 0.52).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	active_tween.tween_property(self, "modulate:a", 0.0, 0.38).set_delay(0.22)
	active_tween.chain().tween_callback(func(): ObjectPoolManager.release(self))
