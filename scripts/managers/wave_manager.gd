class_name WaveManager
extends Node

@export var spawn_points: Array[NodePath]

const ZOMBIE_SCENE: PackedScene = preload("res://scenes/enemies/zombie.tscn")

var current_wave: int = 1
var zombies_to_spawn: int = 5
var zombies_remaining: int = 0
var base_zombie_health: int = 30
var spawn_delay: float = 1.5
var wave_delay: float = 3.0

var spawn_timer: Timer
var wave_timer: Timer
var is_wave_active: bool = false
var spawn_points_nodes: Array[Node2D] = []

func _ready() -> void:
	EventBus.zombie_died.connect(_on_zombie_died)

	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_spawn_zombie)
	add_child(spawn_timer)

	wave_timer = Timer.new()
	wave_timer.one_shot = true
	wave_timer.timeout.connect(_start_wave)
	add_child(wave_timer)

	for path in spawn_points:
		var node := get_node(path) as Node2D
		if node:
			spawn_points_nodes.append(node)

	# Delay initial wave start slightly
	call_deferred("_prepare_next_wave")

func _prepare_next_wave() -> void:
	is_wave_active = false
	EventBus.wave_cleared.emit(wave_delay)
	wave_timer.start(wave_delay)

func _start_wave() -> void:
	is_wave_active = true
	zombies_remaining = zombies_to_spawn
	EventBus.wave_started.emit(current_wave)
	EventBus.zombie_count_changed.emit(zombies_remaining)

	_spawn_zombie()

func _spawn_zombie() -> void:
	if not is_wave_active or zombies_to_spawn <= 0:
		return

	if spawn_points_nodes.size() > 0:
		var sp := spawn_points_nodes[randi() % spawn_points_nodes.size()]
		var zombie := ZOMBIE_SCENE.instantiate() as Zombie

		# Set scaled health
		zombie.max_health = base_zombie_health
		zombie.global_position = sp.global_position

		get_tree().current_scene.add_child(zombie)

		zombies_to_spawn -= 1

		if zombies_to_spawn > 0:
			spawn_timer.start(spawn_delay)

func _on_zombie_died(_pos: Vector2) -> void:
	if not is_wave_active:
		return

	zombies_remaining -= 1
	EventBus.zombie_count_changed.emit(zombies_remaining)

	if zombies_remaining <= 0 and zombies_to_spawn <= 0:
		_end_wave()

func _end_wave() -> void:
	current_wave += 1

	# Scaling logic
	var next_zombies_count := 5 + ((current_wave - 1) * 3)
	zombies_to_spawn = next_zombies_count

	# Increase health by 10% compound
	base_zombie_health = int(float(base_zombie_health) * 1.1)

	_prepare_next_wave()
