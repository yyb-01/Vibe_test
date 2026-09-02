class_name BossSkillEffect
extends Node2D

var kind := "blink"
var color := Color.WHITE
var radius := 120.0
var duration := 0.5
var age := 0.0
var damage := 0
var direction := Vector2.RIGHT
var tick := 0.0
var damage_source := "보스"
var attack_name := "위험 장판"

func setup(effect_kind: String, effect_color: Color, effect_radius: float, effect_duration: float, effect_damage: int = 0, effect_direction: Vector2 = Vector2.RIGHT, source: String = "보스", attack: String = "위험 장판") -> void:
	kind = effect_kind
	color = effect_color
	radius = effect_radius
	duration = maxf(effect_duration, 0.01)
	damage = effect_damage
	direction = effect_direction.normalized()
	damage_source = source
	attack_name = attack
	z_index = 7
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	tick -= delta
	if damage > 0 and tick <= 0.0:
		tick = 0.55
		var player := get_tree().get_first_node_in_group("player") as Player
		if is_instance_valid(player) and not player.is_queued_for_deletion() and global_position.distance_to(player.global_position) <= radius:
			player.take_damage(damage, global_position.direction_to(player.global_position), damage_source, attack_name)
	queue_redraw()
	if age >= duration:
		queue_free()

func _draw() -> void:
	var progress := clampf(age / duration, 0.0, 1.0)
	var fade := 1.0 - progress
	match kind:
		"charge":
			draw_line(-direction * radius, Vector2.ZERO, Color(color, fade * 0.5), 44.0 * fade, true)
			for i in 4:
				draw_circle(-direction * radius * float(i) / 4.0, 18.0 * fade, Color(color, fade * 0.18))
		"fire":
			draw_circle(Vector2.ZERO, radius, Color(color, 0.12 + sin(age * 15.0) * 0.04))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(0.02, 0.02, 0.02, 0.85), 12.0, true)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(color, 0.9), 6.0, true)
			for i in 10:
				var angle := TAU * float(i) / 10.0 + age
				var flame := Vector2.RIGHT.rotated(angle) * radius * (0.25 + 0.65 * fmod(float(i) * 0.37 + age, 1.0))
				draw_circle(flame, 10.0 + sin(age * 18.0 + i) * 4.0, Color(color, fade * 0.7))
		"toxic":
			draw_circle(Vector2.ZERO, radius, Color(color, 0.16 + sin(age * 7.0) * 0.04))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(0.02, 0.02, 0.02, 0.85), 13.0, true)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(color, 0.9), 6.0, true)
			for i in 8:
				var bubble := Vector2(cos(float(i) * 2.4), sin(float(i) * 3.1)) * radius * 0.65
				draw_circle(bubble, 8.0 + sin(age * 5.0 + i) * 3.0, Color(color, fade * 0.55))
		_:
			for i in 3:
				var ring := radius * clampf(progress * 1.6 - float(i) * 0.18, 0.0, 1.0)
				draw_arc(Vector2.ZERO, ring, 0.0, TAU, 40, Color(color, fade * 0.9), 7.0, true)
