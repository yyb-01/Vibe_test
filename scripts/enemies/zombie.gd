class_name Zombie
extends CharacterBody2D

@export var max_health: int = 30
@export var move_speed: float = 100.0
@export var attack_damage: int = 10
@export var attack_range: float = 75.0
@export var attack_cooldown: float = 1.0
@export var knockback_resistance: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var soft_collision: Area2D = $SoftCollision

var health: int
var player: Node2D = null
var can_attack: bool = true
var knockback: Vector2 = Vector2.ZERO

var base_scale: Vector2
var walk_time: float = 0.0

const EXP_GEM_SCENE: PackedScene = preload("res://scenes/items/exp_gem.tscn")
const BLOOD_IMPACT_SCENE: PackedScene = preload("res://scenes/effects/blood_impact.tscn")
const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/effects/damage_number.tscn")

func _ready() -> void:
	health = max_health
	base_scale = sprite.scale

	player = get_tree().get_first_node_in_group("player")

	if sprite.material:
		sprite.material = sprite.material.duplicate()

func _physics_process(delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return

	var distance_to_player := global_position.distance_to(player.global_position)
	var dir_to_player := global_position.direction_to(player.global_position)

	look_at(player.global_position)

	# Knockback decay
	knockback = knockback.move_toward(Vector2.ZERO, 500 * delta)

	# Movement
	if distance_to_player > attack_range * 0.9:
		var move_dir = dir_to_player

		# Soft Collision Separation
		var separation_vector := Vector2.ZERO
		var areas := soft_collision.get_overlapping_areas()
		for area in areas:
			if area != soft_collision:
				separation_vector -= global_position.direction_to(area.global_position) * 10.0

		move_dir = (move_dir * move_speed + separation_vector).normalized()

		velocity = move_dir * move_speed + knockback
		move_and_slide()

		# Procedural Animation (Squash & Stretch)
		walk_time += delta * (move_speed / 20.0)
		var stretch = sin(walk_time) * 0.1
		var squash = cos(walk_time) * 0.1
		sprite.scale = base_scale + Vector2(stretch, squash)
	else:
		sprite.scale = base_scale

	if distance_to_player <= attack_range:
		_attack_player()

func _attack_player() -> void:
	if can_attack and player.has_method("take_damage"):
		can_attack = false
		player.take_damage(attack_damage)

		var timer := get_tree().create_timer(attack_cooldown)
		timer.timeout.connect(func() -> void: can_attack = true)

func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if health <= 0:
		return

	health -= amount

	# Camera Shake
	EventBus.camera_shake_requested.emit()

	# Damage Number
	var dmg_num = DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
	dmg_num.amount = amount
	dmg_num.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", dmg_num)

	# Blood Particles
	var blood := BLOOD_IMPACT_SCENE.instantiate() as CPUParticles2D
	blood.global_position = global_position
	if hit_direction != Vector2.ZERO:
		blood.rotation = hit_direction.angle()
	get_tree().current_scene.call_deferred("add_child", blood)

	# Knockback
	knockback = hit_direction * 200.0 * (1.0 - knockback_resistance)

	# White Flash Shader
	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("active", true)
		var timer := get_tree().create_timer(0.05)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(sprite) and sprite.material is ShaderMaterial:
				sprite.material.set_shader_parameter("active", false)
		)

	if health <= 0:
		die()

func die() -> void:
	EventBus.zombie_died.emit(global_position)

	# Spawn EXP Gem
	var gem := EXP_GEM_SCENE.instantiate()
	gem.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", gem)

	# Leave corpse
	sprite.reparent(get_tree().current_scene)
	sprite.modulate.a = 0.5
	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 5.0)
	tween.tween_callback(sprite.queue_free)

	queue_free()
