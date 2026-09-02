class_name CombatPet
extends Node2D

const PET_SHEETS := {
	"rescue_hound": preload("res://assets/graphics/animated/pet_rescue_hound_sheet_v1.png"),
	"toxic_crow": preload("res://assets/graphics/animated/pet_toxic_crow_sheet_v1.png"),
	"lab_drone": preload("res://assets/graphics/animated/pet_lab_drone_sheet_v1.png")
}

var pet_id: String = ""
var owner_player: Player
var attack_timer: float = 0.0
var support_timer: float = 12.0
var visual_timer: float = 0.0
var target_position: Vector2
var ability_color := Color(0.4, 0.9, 1.0, 1.0)
var pet_sprite: Sprite2D
var sprite_base_scale := Vector2.ONE
var animation_time: float = 0.0
var lunge_offset := Vector2.ZERO

const FOLLOW_SPEED: float = 620.0
const LUNGE_DISTANCE: float = 145.0
const LUNGE_RECOVERY_SPEED: float = 540.0

func _ready() -> void:
	z_index = 8
	target_position = global_position
	VisualShadow.attach(self, Vector2(36.0, 12.0), Vector2(0.0, 24.0))
	_create_pet_sprite()
	queue_redraw()

func _create_pet_sprite() -> void:
	pet_sprite = Sprite2D.new()
	pet_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var old_texture: Texture2D
	match pet_id:
		"rescue_hound":
			old_texture = preload("res://assets/graphics/pet_rescue_hound_v1.png")
			pet_sprite.scale = Vector2.ONE * 0.052
		"toxic_crow":
			old_texture = preload("res://assets/graphics/pet_toxic_crow_v1.png")
			pet_sprite.scale = Vector2.ONE * 0.048
		_:
			old_texture = preload("res://assets/graphics/pet_lab_drone_v1.png")
			pet_sprite.scale = Vector2.ONE * 0.046
	var sheet: Texture2D = PET_SHEETS.get(pet_id, PET_SHEETS["lab_drone"])
	pet_sprite.texture = sheet
	pet_sprite.region_enabled = true
	var cell_size := Vector2(float(sheet.get_width()) / 4.0, float(sheet.get_height()))
	pet_sprite.region_rect = Rect2(Vector2.ZERO, cell_size)
	pet_sprite.scale *= float(old_texture.get_width()) / (float(sheet.get_width()) / 4.0)
	pet_sprite.z_index = 1
	sprite_base_scale = pet_sprite.scale
	add_child(pet_sprite)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_player) or owner_player.is_queued_for_deletion():
		queue_free()
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	animation_time += delta
	support_timer = maxf(0.0, support_timer - delta)
	visual_timer = maxf(0.0, visual_timer - delta)
	var orbit_angle := Time.get_ticks_msec() * 0.0015 + float(get_instance_id() % 10)
	var follow_offset := Vector2(-72.0, 26.0) + Vector2(cos(orbit_angle), sin(orbit_angle)) * 12.0
	var follow_target := owner_player.global_position + follow_offset + lunge_offset
	global_position = global_position.move_toward(follow_target, FOLLOW_SPEED * delta)
	lunge_offset = lunge_offset.move_toward(Vector2.ZERO, LUNGE_RECOVERY_SPEED * delta)
	_animate_pet(delta)
	if attack_timer <= 0.0:
		_use_combat_ability()
	if pet_id == "lab_drone" and support_timer <= 0.0:
		owner_player.heal(12)
		support_timer = 12.0
		ability_color = Color(0.35, 1.0, 0.6, 1.0)
		visual_timer = 0.35
	queue_redraw()

func _animate_pet(delta: float) -> void:
	if not is_instance_valid(pet_sprite):
		return
	var facing_target := target_position if visual_timer > 0.0 else owner_player.global_position
	pet_sprite.flip_h = facing_target.x < global_position.x
	var animation_rate := 11.0 if pet_id == "rescue_hound" else (8.0 if pet_id == "toxic_crow" else 5.5)
	var frame := int(animation_time * animation_rate) % 4
	var cell_size := Vector2(float(pet_sprite.texture.get_width()) / 4.0, float(pet_sprite.texture.get_height()))
	pet_sprite.region_rect = Rect2(Vector2(float(frame) * cell_size.x, 0.0), cell_size)
	match pet_id:
		"rescue_hound":
			var stride := sin(animation_time * 13.0)
			pet_sprite.position.y = -absf(stride) * 5.0
			pet_sprite.rotation = lerpf(pet_sprite.rotation, stride * 0.035, minf(delta * 12.0, 1.0))
			pet_sprite.scale = sprite_base_scale
		"toxic_crow":
			var flap := sin(animation_time * 10.5)
			pet_sprite.position.y = -10.0 + sin(animation_time * 4.0) * 5.0
			pet_sprite.rotation = flap * 0.045
			pet_sprite.scale = sprite_base_scale
		_:
			var hover := sin(animation_time * 5.2)
			pet_sprite.position.y = -8.0 + hover * 4.0
			pet_sprite.rotation = lerpf(pet_sprite.rotation, hover * 0.025, minf(delta * 8.0, 1.0))
			pet_sprite.scale = sprite_base_scale

func _use_combat_ability() -> void:
	var target := _nearest_enemy(520.0)
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		attack_timer = 0.25
		return
	target_position = target.global_position
	match pet_id:
		"rescue_hound":
			var target_pos := target_position
			var direction := global_position.direction_to(target_pos)
			target.take_damage(int(22.0 * owner_player.damage_mult), direction)
			# Keep the attack readable without snapping across the arena in one frame.
			lunge_offset = owner_player.global_position.direction_to(target_pos) * LUNGE_DISTANCE
			ability_color = Color(1.0, 0.7, 0.28, 1.0)
			attack_timer = 1.15
		"toxic_crow":
			var center_position := target_position
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if _is_active_enemy(enemy) and enemy.global_position.distance_to(center_position) <= 145.0:
					enemy.take_damage(int(12.0 * owner_player.damage_mult), center_position.direction_to(enemy.global_position))
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
		if not _is_active_enemy(enemy):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest

func _is_active_enemy(enemy: Node) -> bool:
	return is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.has_method("take_damage") and enemy is CanvasItem and enemy.visible and enemy.process_mode != Node.PROCESS_MODE_DISABLED and enemy.get("health") != null and int(enemy.get("health")) > 0 and enemy.get("is_dying") != true

func _draw() -> void:
	if visual_timer > 0.0:
		draw_line(Vector2.ZERO, to_local(target_position), ability_color, 5.0, true)
		draw_circle(to_local(target_position), 22.0, Color(ability_color, 0.22))
