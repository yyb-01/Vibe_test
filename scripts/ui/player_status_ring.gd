class_name PlayerStatusRing
extends Control

var player: Player

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(72, 72)
	size = Vector2(72, 72)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	visible = is_instance_valid(player) and not get_tree().paused
	if not visible:
		return
	position = get_viewport().get_mouse_position() - size * 0.5
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(player):
		return
	var center := size * 0.5
	draw_circle(center, 3.0, Color(0.8, 1.0, 0.95, 0.9))
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + direction * 9.0, center + direction * 15.0, Color(0.8, 1.0, 0.95, 0.8), 1.5, true)
	var dash_max := 2.4 * (1.0 - SaveManager.get_upgrade_level("dash_cooldown") * 0.08)
	var dash_ready := 1.0 - clampf(player.dash_cooldown / maxf(dash_max, 0.01), 0.0, 1.0)
	_draw_meter(center, 23.0, dash_ready, Color(0.25, 0.9, 1.0, 0.95), -PI * 0.75)
	var reload_progress := _reload_progress()
	if reload_progress >= 0.0:
		_draw_meter(center, 29.0, reload_progress, Color(1.0, 0.65, 0.24, 0.95), PI * 0.25)

func _draw_meter(center: Vector2, radius: float, progress: float, color: Color, start: float) -> void:
	draw_arc(center, radius, start, start + PI * 1.5, 36, Color(0.08, 0.14, 0.16, 0.75), 3.0, true)
	draw_arc(center, radius, start, start + PI * 1.5 * progress, 36, color, 3.0, true)

func _reload_progress() -> float:
	if not is_instance_valid(player):
		return -1.0
	for weapon in player.weapons:
		if weapon.reload_timer > 0.0 and weapon.data:
			var duration: float = weapon.data.reload_time * player.reload_mult
			return 1.0 - clampf(weapon.reload_timer / maxf(duration, 0.01), 0.0, 1.0)
	return -1.0
