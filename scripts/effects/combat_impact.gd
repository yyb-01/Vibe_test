class_name CombatImpact
extends Node2D

const DEFAULT_COLOR := Color(1.0, 0.24, 0.12, 1.0)
var impact_color: Color = DEFAULT_COLOR
var max_radius: float = 44.0
var age: float = 0.0

@onready var particles: CPUParticles2D = $Particles

func _ready() -> void:
	reset()

func reset() -> void:
	age = 0.0
	impact_color = DEFAULT_COLOR
	max_radius = 44.0
	scale = Vector2.ONE
	visible = true
	particles.color = impact_color
	particles.restart()
	queue_redraw()

func configure(color: Color, radius: float) -> void:
	impact_color = color
	max_radius = radius
	particles.color = color
	particles.restart()
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= 0.42:
		ObjectPoolManager.release(self)

func _draw() -> void:
	var progress := clampf(age / 0.42, 0.0, 1.0)
	var alpha := 1.0 - progress
	var radius := lerpf(8.0, max_radius, progress)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(impact_color.r, impact_color.g, impact_color.b, alpha * 0.8), 3.5, true)
	draw_circle(Vector2.ZERO, lerpf(4.0, 1.0, progress), Color(1.0, 0.92, 0.72, alpha))
	for i in range(6):
		var angle := float(i) * TAU / 6.0 + 0.2
		var start := Vector2.RIGHT.rotated(angle) * radius * 0.58
		var end := Vector2.RIGHT.rotated(angle) * radius
		draw_line(start, end, Color(impact_color.r, impact_color.g, impact_color.b, alpha * 0.9), 2.0, true)
