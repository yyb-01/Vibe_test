class_name MuzzleFlash
extends Node2D

var age := 0.0
var lifetime := 0.085
var flash_color := Color(1.0, 0.75, 0.25, 1.0)
var flash_size := 24.0

func setup(spawn_position: Vector2, direction: Vector2, color: Color, size: float) -> void:
	global_position = spawn_position
	rotation = direction.angle()
	flash_color = color
	flash_size = size
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= lifetime:
		queue_free()

func _draw() -> void:
	var fade := 1.0 - clampf(age / lifetime, 0.0, 1.0)
	var length := flash_size * (0.8 + fade * 0.45)
	var points := PackedVector2Array([
		Vector2.ZERO,
		Vector2(length * 0.48, -flash_size * 0.18),
		Vector2(length, 0.0),
		Vector2(length * 0.48, flash_size * 0.18)
	])
	draw_colored_polygon(points, Color(flash_color, fade))
	draw_circle(Vector2.ZERO, flash_size * 0.24, Color(1.0, 0.95, 0.72, fade * 0.9))
