class_name WaveManager
extends Node

@export var spawn_points: Array[NodePath]

const ZOMBIE_BASE: PackedScene = preload("res://scenes/enemies/zombie.tscn")
const ZOMBIE_RUNNER: PackedScene = preload("res://scenes/enemies/zombie_runner.tscn")
const ZOMBIE_TANK: PackedScene = preload("res://scenes/enemies/zombie_tank.tscn")

var current_wave: int = 1
var zombies_to_spawn: int = 5
var zombies_remaining: int = 0
var spawn_delay: float = 1.5
var wave_delay: float = 3.0

var spawn_timer: Timer
var wave_timer: Timer
var is_wave_active: bool = false
var spawn_points_nodes: Array[Node2D] = []

func _ready() -> void:
	EventBus.zombie_died.connect(_on_zombie_died)
	EventBus.perk_selected.connect(_on_perk_selected)

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

		# Determine which zombie to spawn based on wave
		var scene_to_spawn: PackedScene = ZOMBIE_BASE

		if current_wave >= 5:
			# Base, Runner, Tank
			var r := randf()
			if r < 0.2:
				scene_to_spawn = ZOMBIE_TANK
			elif r < 0.5:
				scene_to_spawn = ZOMBIE_RUNNER
		elif current_wave >= 3:
			# Base, Runner
			if randf() < 0.3:
				scene_to_spawn = ZOMBIE_RUNNER

		var zombie := scene_to_spawn.instantiate() as Zombie

		# Compound 10% health increase multiplier (using base stats of the specific variant)
		var hp_multiplier: float = pow(1.1, current_wave - 1)

		# We must use call_deferred or set it after adding child if we want _ready to catch it,
		# but since we set it before add_child, _ready in zombie.gd will copy max_health to health correctly.
		zombie.max_health = int(float(zombie.max_health) * hp_multiplier)
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
	is_wave_active = false
	EventBus.perk_selection_requested.emit()

func _on_perk_selected(_perk: PerkData) -> void:
	current_wave += 1

	# Scaling logic
	var next_zombies_count := 5 + ((current_wave - 1) * 3)
	zombies_to_spawn = next_zombies_count

	_prepare_next_wave()
