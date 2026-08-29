class_name PlayerHitEffect
extends Node2D

var age: float = 0.0
@onready var particles: CPUParticles2D = $Particles

func _ready() -> void:
	reset()

func reset() -> void:
	age = 0.0
	scale = Vector2.ONE
	visible = true
	particles.restart()
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= 0.5:
		ObjectPoolManager.release(self)

func _draw() -> void:
	var progress := clampf(age / 0.5, 0.0, 1.0)
	var alpha := 1.0 - progress
	var radius := lerpf(10.0, 52.0, progress)
	draw_arc(Vector2.ZERO, radius, -1.15, 1.15, 18, Color(1.0, 0.26, 0.12, alpha * 0.9), 4.0, true)
	draw_arc(Vector2.ZERO, radius * 0.7, 1.95, 4.3, 18, Color(1.0, 0.82, 0.35, alpha * 0.65), 2.0, true)
