class_name CombatPet
extends Node2D

var pet_id: String = ""
var owner_player: Player
var attack_timer: float = 0.0
var support_timer: float = 12.0
var visual_timer: float = 0.0
var target_position: Vector2
var ability_color := Color(0.4, 0.9, 1.0, 1.0)

func _ready() -> void:
	z_index = 8
	target_position = global_position
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_player):
		queue_free()
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	support_timer = maxf(0.0, support_timer - delta)
	visual_timer = maxf(0.0, visual_timer - delta)
	var orbit_angle := Time.get_ticks_msec() * 0.0015 + float(get_instance_id() % 10)
	var follow_offset := Vector2(-72.0, 26.0) + Vector2(cos(orbit_angle), sin(orbit_angle)) * 12.0
	global_position = global_position.lerp(owner_player.global_position + follow_offset, minf(1.0, delta * 7.5))
	if attack_timer <= 0.0:
		_use_combat_ability()
	if pet_id == "lab_drone" and support_timer <= 0.0:
		owner_player.heal(12)
		support_timer = 12.0
		ability_color = Color(0.35, 1.0, 0.6, 1.0)
		visual_timer = 0.35
	queue_redraw()

func _use_combat_ability() -> void:
	var target := _nearest_enemy(520.0)
	if not is_instance_valid(target):
		attack_timer = 0.25
		return
	target_position = target.global_position
	match pet_id:
		"rescue_hound":
			var direction := global_position.direction_to(target.global_position)
			target.take_damage(int(22.0 * owner_player.damage_mult), direction)
			global_position = global_position.lerp(target.global_position - direction * 38.0, 0.7)
			ability_color = Color(1.0, 0.7, 0.28, 1.0)
			attack_timer = 1.15
		"toxic_crow":
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) and enemy.global_position.distance_to(target.global_position) <= 145.0:
					enemy.take_damage(int(12.0 * owner_player.damage_mult), target.global_position.direction_to(enemy.global_position))
			ability_color = Color(0.45, 1.0, 0.25, 1.0)
			attack_timer = 2.25
		_:
			target.take_damage(int(15.0 * owner_player.damage_mult), global_position.direction_to(target.global_position))
			ability_color = Color(0.3, 0.85, 1.0, 1.0)
			attack_timer = 0.9
	visual_timer = 0.22

func _nearest_enemy(max_range: float) -> Node2D:
	var nearest: Node2D
	var nearest_distance := max_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest

func _draw() -> void:
	match pet_id:
		"rescue_hound":
			draw_circle(Vector2.ZERO, 18.0, Color(0.48, 0.3, 0.16, 1.0))
			draw_circle(Vector2(13, -7), 10.0, Color(0.78, 0.55, 0.3, 1.0))
			draw_circle(Vector2(17, -9), 2.5, Color.WHITE)
		"toxic_crow":
			draw_colored_polygon(PackedVector2Array([Vector2(-23, 0), Vector2(0, -12), Vector2(23, 0), Vector2(0, 8)]), Color(0.18, 0.25, 0.2, 1.0))
			draw_circle(Vector2.ZERO, 8.0, Color(0.45, 0.9, 0.25, 1.0))
		_:
			draw_circle(Vector2.ZERO, 16.0, Color(0.2, 0.65, 0.82, 1.0))
			draw_rect(Rect2(-24, -5, 48, 10), Color(0.38, 0.9, 1.0, 0.8))
			draw_circle(Vector2.ZERO, 5.0, Color.WHITE)
	if visual_timer > 0.0:
		draw_line(Vector2.ZERO, to_local(target_position), ability_color, 5.0, true)
		draw_circle(to_local(target_position), 22.0, Color(ability_color, 0.22))
