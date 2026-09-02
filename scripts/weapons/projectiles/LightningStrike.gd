class_name LightningStrike
extends Node2D

var _age: float = 0.0
var _duration: float = 0.28
var _color := Color(0.55, 0.8, 1.0, 1.0)

func on_spawn(init_position: Vector2 = Vector2.ZERO, init_duration: float = 0.28,
		init_color: Color = Color(0.55, 0.8, 1.0, 1.0)) -> void:
	global_position = init_position
	_age = 0.0
	_duration = maxf(0.03, init_duration)
	_color = init_color
	modulate.a = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if get_meta("_pool_release_pending", false):
		return
	_age += delta
	modulate.a = 1.0 - clampf(_age / _duration, 0.0, 1.0)
	queue_redraw()
	if _age >= _duration:
		ObjectPoolManager.despawn(self)

func on_despawn() -> void:
	_age = 0.0
	modulate.a = 0.0
	set_process(false)

func _draw() -> void:
	var points := PackedVector2Array([Vector2(0.0, -190.0), Vector2(-12.0, -128.0), Vector2(9.0, -72.0), Vector2(0.0, 0.0)])
	draw_polyline(points, Color(_color, 0.85), 7.0, true)
	draw_circle(Vector2.ZERO, 20.0 + sin(_age * 40.0) * 4.0, Color(_color, 0.35))

