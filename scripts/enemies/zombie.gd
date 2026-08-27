class_name Zombie
extends CharacterBody2D

@export var max_health: int = 30
@export var move_speed: float = 100.0
@export var attack_damage: int = 10
@export var attack_range: float = 75.0
@export var attack_cooldown: float = 1.0

var health: int
var player: Node2D = null
var can_attack: bool = true

const DROP_ITEM_SCENE: PackedScene = preload("res://scenes/items/drop_item.tscn")

func _ready() -> void:
	health = max_health

	# Attempt to find player in the scene
	player = get_tree().get_first_node_in_group("player")

func set_stats(new_max_health: int) -> void:
	max_health = new_max_health
	health = max_health

func _physics_process(delta: float) -> void:
	if not player:
		# Try to find player again if not found initially
		player = get_tree().get_first_node_in_group("player")
		return

	var distance_to_player := global_position.distance_to(player.global_position)
	var dir_to_player := global_position.direction_to(player.global_position)

	look_at(player.global_position)

	if distance_to_player > attack_range * 0.9:
		velocity = dir_to_player * move_speed
		move_and_slide()

	if distance_to_player <= attack_range:
		_attack_player()

func _attack_player() -> void:
	if can_attack and player.has_method("take_damage"):
		can_attack = false
		player.take_damage(attack_damage)

		var timer := get_tree().create_timer(attack_cooldown)
		timer.timeout.connect(func() -> void: can_attack = true)

func take_damage(amount: int) -> void:
	health -= amount
	# Simple visual feedback
	modulate = Color.RED
	var timer := get_tree().create_timer(0.1)
	timer.timeout.connect(func() -> void: modulate = Color.WHITE)

	if health <= 0:
		die()

func die() -> void:
	EventBus.zombie_died.emit(global_position)
	_attempt_drop_item()
	queue_free()

func _attempt_drop_item() -> void:
	# 35% chance to drop item
	if randf() <= 0.35:
		var item := DROP_ITEM_SCENE.instantiate() as DropItem

		# 30% health kit, 70% ammo box
		if randf() <= 0.30:
			item.type = DropItem.ItemType.HEALTH_KIT
		else:
			item.type = DropItem.ItemType.AMMO_BOX

		item.global_position = global_position
		get_tree().current_scene.call_deferred("add_child", item)
