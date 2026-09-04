class_name Telegraph
extends Node2D

var event_id: StringName = &""
var remaining_ticks: int = 0
var duration_ticks: int = 1

func _ready() -> void:
	visible = false

func configure(next_event_id: StringName, started_tick: int, next_duration_ticks: int, _severity: int) -> void:
	event_id = next_event_id
	duration_ticks = maxi(1, next_duration_ticks)
	remaining_ticks = duration_ticks
	visible = true
	queue_redraw()

func update_progress(current_tick: int, expiry_tick: int) -> void:
	remaining_ticks = maxi(0, expiry_tick - current_tick)
	queue_redraw()

func clear() -> void:
	event_id = &""
	remaining_ticks = 0
	visible = false
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var progress := clampf(float(remaining_ticks) / float(duration_ticks), 0.0, 1.0)
	draw_circle(Vector2.ZERO, 28.0, Color(0.9, 0.12, 0.08, 0.18))
	draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 32, Color(1.0, 0.35, 0.15, 0.9), 3.0)
	draw_rect(Rect2(-36.0, 38.0, 72.0, 6.0), Color(0.15, 0.05, 0.03, 0.7))
	draw_rect(Rect2(-36.0, 38.0, 72.0 * progress, 6.0), Color(1.0, 0.35, 0.15, 0.9))
