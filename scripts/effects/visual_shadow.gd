class_name VisualShadow
extends Node2D

var shadow_size := Vector2(52.0, 18.0)

static func attach(parent: Node2D, size: Vector2, offset: Vector2) -> void:
	var shadow := VisualShadow.new()
	shadow.shadow_size = size
	shadow.position = offset
	shadow.z_index = -1
	parent.add_child(shadow)

func _draw() -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(Vector2(cos(angle) * shadow_size.x, sin(angle) * shadow_size.y))
	draw_colored_polygon(points, Color(0.005, 0.02, 0.025, 0.42))
