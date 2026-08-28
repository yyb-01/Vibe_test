class_name SpawnManager
extends Node

@export var spawn_points: Array[NodePath]
@export var spawn_bounds: Rect2 = Rect2(0, 0, 1000, 1000)

const ZOMBIE_BASE: PackedScene = preload("res://scenes/enemies/zombie.tscn")
const ZOMBIE_RUNNER: PackedScene = preload("res://scenes/enemies/zombie_runner.tscn")
const ZOMBIE_TANK: PackedScene = preload("res://scenes/enemies/zombie_tank.tscn")

var spawn_points_nodes: Array[Node2D] = []
var time_elapsed: float = 0.0

var base_spawn_delay: float = 2.0
var min_spawn_delay: float = 0.2

var spawn_debt: float = 0.0
var boss_spawned: bool = false

func _ready() -> void:
	get_tree().paused = false # Absolute guarantee on map load
	var pool_parent := get_tree().current_scene
	if not is_instance_valid(pool_parent):
		pool_parent = get_parent()

	for path in spawn_points:
		var node := get_node(path) as Node2D
		if node:
			spawn_points_nodes.append(node)

	# Wait until the map has finished adding its children before warming pools.
	call_deferred("_register_pools", pool_parent)

func _register_pools(pool_parent: Node) -> void:
	ObjectPoolManager.register_pool("zombie_base", ZOMBIE_BASE, pool_parent, 200)
	ObjectPoolManager.register_pool("zombie_runner", ZOMBIE_RUNNER, pool_parent, 100)
	ObjectPoolManager.register_pool("zombie_tank", ZOMBIE_TANK, pool_parent, 50)
	ObjectPoolManager.register_pool("exp_gem", preload("res://scenes/items/exp_gem.tscn"), pool_parent, 300)
	ObjectPoolManager.register_pool("bullet", preload("res://scenes/weapons/bullet.tscn"), pool_parent, 50)
	ObjectPoolManager.register_pool("damage_number", preload("res://scenes/ui/effects/damage_number.tscn"), pool_parent, 100)
	ObjectPoolManager.register_pool("blood_impact", preload("res://scenes/effects/blood_impact.tscn"), pool_parent, 100)

func _process(delta: float) -> void:
	time_elapsed += delta

	if time_elapsed >= 300.0 and not boss_spawned: # 5 Minutes
		_spawn_boss()
		return

	if boss_spawned:
		return # Stop normal spawns during boss fight

	var speed_up_factor = clampf(time_elapsed / 300.0, 0.0, 1.0)
	var current_delay = lerpf(base_spawn_delay, min_spawn_delay, speed_up_factor)

	# Spawn debt allows us to spawn multiple per frame if delay < delta
	var spawn_rate = 1.0 / current_delay
	spawn_debt += spawn_rate * delta

	var spawns_this_frame: int = 0
	const MAX_SPAWNS_PER_FRAME: int = 10

	while spawn_debt >= 1.0 and spawns_this_frame < MAX_SPAWNS_PER_FRAME:
		spawn_debt -= 1.0
		spawns_this_frame += 1
		if not _spawn_zombie():
			# Pool exhausted or error, break loop early to prevent spin-lock
			break

	# If we hit the cap, clamp debt so we don't spiral infinitely behind
	if spawn_debt > MAX_SPAWNS_PER_FRAME * 2.0:
		spawn_debt = float(MAX_SPAWNS_PER_FRAME)

func _spawn_boss() -> void:
	boss_spawned = true
	var sp := spawn_points_nodes[0]
	var boss = ObjectPoolManager.acquire("zombie_tank", sp.global_position)
	if boss:
		boss.set_meta("pool_id", "zombie_tank")
		boss.set_meta("is_boss", true)
		boss.set_scaled_max_health(50.0) # Massive HP multiplier
		boss.scale = Vector2(3.0, 3.0)
		boss.modulate = Color.RED

func _spawn_zombie() -> bool:
	if spawn_points_nodes.size() > 0:
		var sp := spawn_points_nodes[randi() % spawn_points_nodes.size()]

		var pool_id: String = "zombie_base"
		var hp_multiplier: float = 1.0 + (time_elapsed / 60.0) * 0.5 # 50% extra hp per minute

		if time_elapsed > 120.0:
			var r := randf()
			if r < 0.15:
				pool_id = "zombie_tank"
			elif r < 0.4:
				pool_id = "zombie_runner"
		elif time_elapsed > 60.0:
			if randf() < 0.25:
				pool_id = "zombie_runner"

		# Offset slightly around spawn point to prevent immediate stacking
		# Safety check for player instance
		var player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player):
			return false

		var offset := Vector2(randf_range(-40, 40), randf_range(-40, 40))
		var final_pos = sp.global_position + offset

		# Clamp to safe playable area bounds
		final_pos.x = clampf(final_pos.x, spawn_bounds.position.x, spawn_bounds.position.x + spawn_bounds.size.x)
		final_pos.y = clampf(final_pos.y, spawn_bounds.position.y, spawn_bounds.position.y + spawn_bounds.size.y)

		var zombie = ObjectPoolManager.acquire(pool_id, final_pos)
		if not zombie:
			return false # Failed to acquire from pool

		zombie.set_meta("pool_id", pool_id)

		# We must re-assign max health manually since the pool object might have been dirty
		if zombie.has_method("set_scaled_max_health"):
			zombie.set_scaled_max_health(hp_multiplier)

		return true
	return false
