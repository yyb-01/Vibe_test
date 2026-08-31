class_name CombatPet
extends Node2D

const RESCUE_HOUND_TEXTURE: Texture2D = preload("res://assets/graphics/pet_rescue_hound_v1.png")
const TOXIC_CROW_TEXTURE: Texture2D = preload("res://assets/graphics/pet_toxic_crow_v1.png")
const LAB_DRONE_TEXTURE: Texture2D = preload("res://assets/graphics/pet_lab_drone_v1.png")

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

func _ready() -> void:
	z_index = 8
	target_position = global_position
	_create_pet_sprite()
	queue_redraw()

func _create_pet_sprite() -> void:
	pet_sprite = Sprite2D.new()
	pet_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	match pet_id:
		"rescue_hound":
			pet_sprite.texture = RESCUE_HOUND_TEXTURE
			pet_sprite.scale = Vector2.ONE * 0.052
		"toxic_crow":
			pet_sprite.texture = TOXIC_CROW_TEXTURE
			pet_sprite.scale = Vector2.ONE * 0.048
		_:
			pet_sprite.texture = LAB_DRONE_TEXTURE
			pet_sprite.scale = Vector2.ONE * 0.046
	pet_sprite.z_index = 1
	sprite_base_scale = pet_sprite.scale
	add_child(pet_sprite)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_player):
		queue_free()
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	animation_time += delta
	support_timer = maxf(0.0, support_timer - delta)
	visual_timer = maxf(0.0, visual_timer - delta)
	var orbit_angle := Time.get_ticks_msec() * 0.0015 + float(get_instance_id() % 10)
	var follow_offset := Vector2(-72.0, 26.0) + Vector2(cos(orbit_angle), sin(orbit_angle)) * 12.0
	global_position = global_position.lerp(owner_player.global_position + follow_offset, minf(1.0, delta * 7.5))
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
	match pet_id:
		"rescue_hound":
			var stride := sin(animation_time * 13.0)
			pet_sprite.position.y = -absf(stride) * 5.0
			pet_sprite.rotation = lerpf(pet_sprite.rotation, stride * 0.035, minf(delta * 12.0, 1.0))
			pet_sprite.scale = sprite_base_scale * Vector2(1.0 + absf(stride) * 0.035, 1.0 - absf(stride) * 0.025)
		"toxic_crow":
			var flap := sin(animation_time * 10.5)
			pet_sprite.position.y = -10.0 + sin(animation_time * 4.0) * 5.0
			pet_sprite.rotation = flap * 0.045
			pet_sprite.scale = sprite_base_scale * Vector2(1.0 + flap * 0.025, 1.0 - flap * 0.08)
		_:
			var hover := sin(animation_time * 5.2)
			pet_sprite.position.y = -8.0 + hover * 4.0
			pet_sprite.rotation = lerpf(pet_sprite.rotation, hover * 0.025, minf(delta * 8.0, 1.0))
			pet_sprite.scale = sprite_base_scale * (1.0 + hover * 0.018)

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
	if visual_timer > 0.0:
		draw_line(Vector2.ZERO, to_local(target_position), ability_color, 5.0, true)
		draw_circle(to_local(target_position), 22.0, Color(ability_color, 0.22))
