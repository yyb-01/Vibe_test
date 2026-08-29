class_name SkillTracer
extends Line2D

var age: float = 0.0
var duration: float = 0.18
var glow_line: Line2D

func setup_arc(chain_points: PackedVector2Array, color: Color, line_width: float, life: float) -> void:
	points = chain_points
	default_color = color
	width = line_width
	duration = life
	age = 0.0
	z_index = 8
	glow_line = Line2D.new()
	glow_line.points = chain_points
	glow_line.width = line_width * 2.4
	glow_line.default_color = Color(color.r, color.g, color.b, 0.22)
	glow_line.z_index = -1
	add_child(glow_line)

func _process(delta: float) -> void:
	age += delta
	modulate.a = 1.0 - clampf(age / duration, 0.0, 1.0)
	if age >= duration:
		queue_free()
