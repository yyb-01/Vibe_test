class_name UniqueSkillEffect
extends Node2D

var effect_kind := "scavenger"
var age := 0.0
var duration := 0.9
var target_points := PackedVector2Array()

func setup(kind: String, origin: Vector2, targets: PackedVector2Array = PackedVector2Array()) -> void:
	effect_kind = kind
	global_position = origin
	target_points = targets
	duration = 1.15 if kind in ["medic", "ranger", "bulwark", "chronomancer"] else 0.82
	z_index = 20
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= duration:
		queue_free()

func _draw() -> void:
	var progress := clampf(age / duration, 0.0, 1.0)
	var fade := 1.0 - progress
	match effect_kind:
		"medic": _draw_medic(progress, fade)
		"ranger": _draw_ranger(progress, fade)
		"bulwark": _draw_bulwark(progress, fade)
		"pyro": _draw_pyro(progress, fade)
		"engineer": _draw_engineer(progress, fade)
		"reaper": _draw_reaper(progress, fade)
		"chronomancer": _draw_chronomancer(progress, fade)
		_: _draw_scavenger(progress, fade)

func _draw_scavenger(progress: float, fade: float) -> void:
	var color := Color(1.0, 0.62, 0.18, fade)
	draw_arc(Vector2.ZERO, lerpf(35.0, 285.0, progress), 0.0, TAU, 64, color, 8.0, true)
	for index in 12:
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 12.0 + age * 1.8)
		draw_rect(Rect2(direction * lerpf(25.0, 240.0, progress) - Vector2(7, 3), Vector2(14, 6)), color, true)

func _draw_medic(progress: float, fade: float) -> void:
	var color := Color(0.28, 1.0, 0.58, fade)
	for ring in 3:
		draw_arc(Vector2.ZERO, lerpf(25.0 + ring * 18.0, 210.0 + ring * 22.0, progress), 0.0, TAU, 56, color, 5.0, true)
	draw_rect(Rect2(-10, -42, 20, 84), Color(0.8, 1.0, 0.88, fade * 0.8), true)
	draw_rect(Rect2(-42, -10, 84, 20), Color(0.8, 1.0, 0.88, fade * 0.8), true)

func _draw_ranger(progress: float, fade: float) -> void:
	var color := Color(0.3, 0.9, 1.0, fade)
	draw_arc(Vector2.ZERO, 105.0 + sin(age * 16.0) * 8.0, 0.0, TAU, 48, color, 4.0, true)
	for index in 8:
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
		draw_line(direction * 55.0, direction * lerpf(170.0, 95.0, progress), color, 4.0, true)
	draw_circle(Vector2.ZERO, 10.0, Color(0.75, 1.0, 1.0, fade))

func _draw_bulwark(progress: float, fade: float) -> void:
	var color := Color(0.25, 0.65, 1.0, fade)
	var radius := lerpf(55.0, 260.0, progress)
	var points := PackedVector2Array()
	for index in 6:
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / 6.0) * radius)
	points.append(points[0])
	draw_polyline(points, color, 11.0, true)
	draw_circle(Vector2.ZERO, radius * 0.72, Color(0.18, 0.5, 1.0, fade * 0.13))

func _draw_pyro(progress: float, fade: float) -> void:
	for index in 18:
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 18.0 + sin(float(index)) * 0.12)
		var distance := lerpf(25.0, 340.0, progress)
		var tip := direction * distance
		draw_circle(tip, lerpf(22.0, 5.0, progress), Color(1.0, 0.25 + float(index % 3) * 0.16, 0.05, fade))
	draw_circle(Vector2.ZERO, lerpf(35.0, 230.0, progress), Color(1.0, 0.18, 0.02, fade * 0.18))

func _draw_engineer(_progress: float, fade: float) -> void:
	var color := Color(0.25, 0.92, 1.0, fade)
	for target in target_points:
		var local_target := to_local(target)
		draw_line(Vector2.ZERO, local_target, Color(color, fade * 0.42), 10.0, true)
		draw_line(Vector2.ZERO, local_target, color, 3.0, true)
		draw_arc(local_target, 20.0, 0.0, TAU, 20, color, 4.0, true)
	draw_rect(Rect2(-22, -22, 44, 44), Color(0.15, 0.7, 0.9, fade), true)

func _draw_reaper(progress: float, fade: float) -> void:
	var color := Color(1.0, 0.12, 0.3, fade)
	for target in target_points:
		var local_target := to_local(target)
		draw_arc(local_target, lerpf(42.0, 16.0, progress), -PI * 0.8, PI * 0.8, 24, color, 7.0, true)
		draw_line(local_target + Vector2(-18, -18), local_target + Vector2(18, 18), color, 5.0, true)
		draw_line(local_target + Vector2(18, -18), local_target + Vector2(-18, 18), color, 5.0, true)
	draw_circle(Vector2.ZERO, lerpf(180.0, 35.0, progress), Color(0.4, 0.0, 0.12, fade * 0.25))

func _draw_chronomancer(progress: float, fade: float) -> void:
	var color := Color(0.72, 0.38, 1.0, fade)
	for ring in 3:
		var radius := lerpf(360.0 - ring * 55.0, 70.0 + ring * 24.0, progress)
		draw_arc(Vector2.ZERO, radius, age * (1.0 + ring), age * (1.0 + ring) + PI * 1.55, 56, color, 5.0, true)
	for index in 12:
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 12.0 - age * 1.8)
		draw_line(direction * 45.0, direction * 82.0, color, 4.0, true)
