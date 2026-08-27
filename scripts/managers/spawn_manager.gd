class_name SpawnManager
extends Node

@export var spawn_points: Array[NodePath]

const ZOMBIE_BASE: PackedScene = preload("res://scenes/enemies/zombie.tscn")
const ZOMBIE_RUNNER: PackedScene = preload("res://scenes/enemies/zombie_runner.tscn")
const ZOMBIE_TANK: PackedScene = preload("res://scenes/enemies/zombie_tank.tscn")

var spawn_points_nodes: Array[Node2D] = []
var time_elapsed: float = 0.0

var base_spawn_delay: float = 2.0
var min_spawn_delay: float = 0.2

var spawn_timer: Timer

func _ready() -> void:
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_spawn_zombie)
	add_child(spawn_timer)

	for path in spawn_points:
		var node := get_node(path) as Node2D
		if node:
			spawn_points_nodes.append(node)

	# Start engine
	spawn_timer.start(base_spawn_delay)

func _process(delta: float) -> void:
	time_elapsed += delta

func _spawn_zombie() -> void:
	if spawn_points_nodes.size() > 0:
		var sp := spawn_points_nodes[randi() % spawn_points_nodes.size()]

		var scene_to_spawn: PackedScene = ZOMBIE_BASE
		var hp_multiplier: float = 1.0 + (time_elapsed / 60.0) * 0.5 # 50% extra hp per minute

		if time_elapsed > 120.0:
			# After 2 minutes, all variants can spawn
			var r := randf()
			if r < 0.15:
				scene_to_spawn = ZOMBIE_TANK
			elif r < 0.4:
				scene_to_spawn = ZOMBIE_RUNNER
		elif time_elapsed > 60.0:
			# After 1 minute, runners start spawning
			if randf() < 0.25:
				scene_to_spawn = ZOMBIE_RUNNER

		var zombie := scene_to_spawn.instantiate() as Zombie
		zombie.max_health = int(float(zombie.max_health) * hp_multiplier)
		zombie.global_position = sp.global_position

		# Offset slightly around spawn point to prevent immediate stacking
		var offset := Vector2(randf_range(-20, 20), randf_range(-20, 20))
		zombie.global_position += offset

		get_tree().current_scene.add_child(zombie)

	# Calculate next spawn time based on elapsed time (gets faster as time goes on)
	var speed_up_factor = time_elapsed / 300.0 # Reaches max speed at 5 minutes
	speed_up_factor = clampf(speed_up_factor, 0.0, 1.0)

	var current_delay = lerpf(base_spawn_delay, min_spawn_delay, speed_up_factor)
	spawn_timer.start(current_delay)
