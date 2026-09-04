class_name OperationCore
extends Node2D

var health: int = 1
var max_health: int = 1

func configure_health(next_max_health: int) -> void:
	max_health = maxi(1, next_max_health)
	health = max_health
	queue_redraw()

func set_health(next_health: int) -> void:
	health = clampi(next_health, 0, max_health)
	queue_redraw()

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-24.0, -43.0, 48.0, 5.0), Color("321f25"))
	draw_rect(Rect2(-24.0, -43.0, 48.0 * float(health) / float(max_health), 5.0), Color("74c69d"))
