class_name SpawnManager
extends Node

@export var spawn_points: Array[NodePath]
@export var spawn_bounds: Rect2 = Rect2(0, 0, 1000, 1000)

const ZOMBIE_BASE: PackedScene = preload("res://scenes/enemies/zombie.tscn")
const ZOMBIE_RUNNER: PackedScene = preload("res://scenes/enemies/zombie_runner.tscn")
const ZOMBIE_TANK: PackedScene = preload("res://scenes/enemies/zombie_tank.tscn")
const ZOMBIE_SPITTER: PackedScene = preload("res://scenes/enemies/zombie_spitter.tscn")
const ZOMBIE_BOMBER: PackedScene = preload("res://scenes/enemies/zombie_bomber.tscn")
const ZOMBIE_BLOATER: PackedScene = preload("res://scenes/enemies/zombie_bloater.tscn")
const WAVE_SHOP: PackedScene = preload("res://scenes/ui/wave_shop.tscn")
const MISSION_EVENT: PackedScene = preload("res://scenes/world/mission_event.tscn")

var spawn_points_nodes: Array[Node2D] = []
var time_elapsed: float = 0.0

var base_spawn_delay: float = 1.8
var min_spawn_delay: float = 0.35

const WAVE_DURATION: float = 30.0
const MAX_ACTIVE_ENEMIES: int = 220
const SPAWN_DISTANCE_MIN: float = 680.0
const SPAWN_DISTANCE_MAX: float = 920.0
var current_wave: int = 1
var last_announced_wave: int = 1

var spawn_debt: float = 0.0
var boss_spawned: bool = false
var boss_data_hacked: bool = false

func _ready() -> void:
	add_to_group("spawn_manager")
	get_tree().paused = false # Absolute guarantee on map load
	var pool_parent := get_tree().current_scene
	if not is_instance_valid(pool_parent):
		pool_parent = get_parent()

	for path in spawn_points:
		var node := get_node(path) as Node2D
		if node:
			spawn_points_nodes.append(node)

	# Register definitions immediately so auto-fire can acquire objects on the
	# first physics tick. Heavy pre-warming is deferred until the parent is ready.
	_register_pools(pool_parent)
	_ensure_wave_shop(pool_parent)
	_ensure_mission_event(pool_parent)
	call_deferred("_warm_pools")

func _ensure_mission_event(scene_root: Node) -> void:
	var mission := MISSION_EVENT.instantiate()
	scene_root.call_deferred("add_child", mission)
	mission.call_deferred("configure_for_map", RunStats.map_id)

func spawn_event_enemy(pool_id: String, spawn_position: Vector2) -> Node:
	var enemy = ObjectPoolManager.acquire(pool_id, spawn_position)
	if enemy:
		enemy.set_meta("pool_id", pool_id)
	return enemy

func _ensure_wave_shop(scene_root: Node) -> void:
	if get_tree().get_first_node_in_group("wave_shop"):
		return
	var shop := WAVE_SHOP.instantiate()
	scene_root.call_deferred("add_child", shop)

func _register_pools(pool_parent: Node) -> void:
	ObjectPoolManager.register_pool("zombie_base", ZOMBIE_BASE, pool_parent)
	ObjectPoolManager.register_pool("zombie_runner", ZOMBIE_RUNNER, pool_parent)
	ObjectPoolManager.register_pool("zombie_tank", ZOMBIE_TANK, pool_parent)
	ObjectPoolManager.register_pool("zombie_spitter", ZOMBIE_SPITTER, pool_parent)
	ObjectPoolManager.register_pool("zombie_bomber", ZOMBIE_BOMBER, pool_parent)
	ObjectPoolManager.register_pool("zombie_bloater", ZOMBIE_BLOATER, pool_parent)
	ObjectPoolManager.register_pool("exp_gem", preload("res://scenes/items/exp_gem.tscn"), pool_parent)
	ObjectPoolManager.register_pool("bullet", preload("res://scenes/weapons/bullet.tscn"), pool_parent)
	ObjectPoolManager.register_pool("acid_projectile", preload("res://scenes/weapons/acid_projectile.tscn"), pool_parent)
	ObjectPoolManager.register_pool("damage_number", preload("res://scenes/ui/effects/damage_number.tscn"), pool_parent)
	ObjectPoolManager.register_pool("blood_impact", preload("res://scenes/effects/blood_impact.tscn"), pool_parent)
	ObjectPoolManager.register_pool("player_hit", preload("res://scenes/effects/player_hit.tscn"), pool_parent)

func _warm_pools() -> void:
	ObjectPoolManager.warm_pool("zombie_base", 200)
	ObjectPoolManager.warm_pool("zombie_runner", 100)
	ObjectPoolManager.warm_pool("zombie_tank", 50)
	ObjectPoolManager.warm_pool("zombie_spitter", 50)
	ObjectPoolManager.warm_pool("zombie_bomber", 50)
	ObjectPoolManager.warm_pool("zombie_bloater", 50)
	ObjectPoolManager.warm_pool("exp_gem", 300)
	ObjectPoolManager.warm_pool("bullet", 50)
	ObjectPoolManager.warm_pool("acid_projectile", 50)
	ObjectPoolManager.warm_pool("damage_number", 100)
	ObjectPoolManager.warm_pool("blood_impact", 100)
	ObjectPoolManager.warm_pool("player_hit", 40)

func _process(delta: float) -> void:
	time_elapsed += delta
	current_wave = int(time_elapsed / WAVE_DURATION) + 1
	if current_wave > last_announced_wave:
		last_announced_wave = current_wave
		RunStats.add_scrap(8 + current_wave * 2)
		EventBus.wave_shop_requested.emit(current_wave)
		if current_wave > 2:
			SaveManager.add_gold(5 + current_wave * 2)

	if time_elapsed >= 300.0 and not boss_spawned: # 5 Minutes
		_spawn_boss()
		return

	if boss_spawned:
		return # Stop normal spawns during boss fight

	var speed_up_factor = clampf(time_elapsed / 300.0, 0.0, 1.0)
	var current_delay = lerpf(base_spawn_delay, min_spawn_delay, speed_up_factor)
	var wave_spawn_multiplier = 1.0 + float(current_wave - 1) * 0.10

	# Spawn debt allows us to spawn multiple per frame if delay < delta
	var spawn_rate = (1.0 / current_delay) * wave_spawn_multiplier
	spawn_debt += spawn_rate * delta

	var spawns_this_frame: int = 0
	const MAX_SPAWNS_PER_FRAME: int = 8

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
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return
	# Bosses enter from outside the player's current view even on the expanded maps.
	var boss_position := _get_player_spawn_position(player, 760.0, 920.0)
	var boss = ObjectPoolManager.acquire("zombie_tank", boss_position)
	if boss:
		boss.set_meta("pool_id", "zombie_tank")
		boss.set_meta("is_boss", true)
		boss.set_scaled_max_health(38.0 if boss_data_hacked else 50.0)
		boss.scale = Vector2(3.0, 3.0)
		boss.modulate = Color.RED
		boss.set_meta("boss_data_hacked", boss_data_hacked)

func _spawn_zombie() -> bool:
	if _get_active_enemy_count() >= MAX_ACTIVE_ENEMIES:
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return false

	var pool_id: String = "zombie_base"
	var hp_multiplier: float = 1.0 + (time_elapsed / 60.0) * 0.65

	if current_wave >= 7:
		var r := randf()
		if r < 0.10:
			pool_id = "zombie_bomber"
		elif r < 0.18:
			pool_id = "zombie_bloater"
		elif r < 0.30:
			pool_id = "zombie_tank"
		elif r < 0.50:
			pool_id = "zombie_spitter"
		elif r < 0.75:
			pool_id = "zombie_runner"
	elif current_wave >= 4:
		var r := randf()
		if r < 0.08:
			pool_id = "zombie_bomber"
		elif r < 0.14:
			pool_id = "zombie_bloater"
		elif r < 0.24:
			pool_id = "zombie_spitter"
		elif r < 0.48:
			pool_id = "zombie_runner"

	# Large maps still need constant pressure. Enemies now emerge just outside
	# the visible play space around the player rather than walking from a corner.
	var final_pos := _get_player_spawn_position(player, SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)
	var zombie = ObjectPoolManager.acquire(pool_id, final_pos)
	if not zombie:
		return false

	zombie.set_meta("pool_id", pool_id)
	if zombie.has_method("set_scaled_max_health"):
		zombie.set_scaled_max_health(hp_multiplier)
	if current_wave >= 5 and randf() < clampf(float(current_wave - 4) * 0.04, 0.0, 0.22):
		zombie.set_elite()

	return true

func _get_player_spawn_position(player: Node2D, min_distance: float, max_distance: float) -> Vector2:
	var safe_left := spawn_bounds.position.x + 120.0
	var safe_top := spawn_bounds.position.y + 120.0
	var safe_right := spawn_bounds.position.x + spawn_bounds.size.x - 120.0
	var safe_bottom := spawn_bounds.position.y + spawn_bounds.size.y - 120.0
	for _attempt in range(8):
		var angle := randf() * TAU
		var distance := randf_range(min_distance, max_distance)
		var candidate := player.global_position + Vector2.RIGHT.rotated(angle) * distance
		candidate.x = clampf(candidate.x, safe_left, safe_right)
		candidate.y = clampf(candidate.y, safe_top, safe_bottom)
		if candidate.distance_to(player.global_position) >= min_distance * 0.72:
			return candidate
	return Vector2(
		clampf(player.global_position.x + min_distance, safe_left, safe_right),
		clampf(player.global_position.y, safe_top, safe_bottom)
	)

func _get_active_enemy_count() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is CanvasItem and is_instance_valid(enemy) and enemy.process_mode != Node.PROCESS_MODE_DISABLED and enemy.visible:
			count += 1
	return count
