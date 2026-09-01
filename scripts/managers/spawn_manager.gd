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
const MAP_BOSSES := {
	"map_1": preload("res://scenes/enemies/boss_quarantine_warden.tscn"),
	"map_2": preload("res://scenes/enemies/boss_foundry_juggernaut.tscn"),
	"map_3": preload("res://scenes/enemies/boss_mire_leviathan.tscn"),
	"map_4": preload("res://scenes/enemies/boss_director_null.tscn")
}
const WAVE_SHOP: PackedScene = preload("res://scenes/ui/wave_shop.tscn")
const MISSION_EVENT: PackedScene = preload("res://scenes/world/mission_event.tscn")
const SUPPLY_CACHE: PackedScene = preload("res://scenes/world/supply_cache.tscn")

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
var next_boss_time: float = 300.0
var bosses_defeated: int = 0
var next_miniboss_time: float = 90.0
var next_supply_time: float = 75.0
var active_modifier: String = "standard"
var modifier_spawn_mult: float = 1.0

func _ready() -> void:
	add_to_group("spawn_manager")
	AudioManager.play_wave_bgm()
	ModalManager.clear()
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
	if not EventBus.boss_defeated.is_connected(_on_boss_defeated):
		EventBus.boss_defeated.connect(_on_boss_defeated)
	call_deferred("_warm_pools")

func _ensure_mission_event(scene_root: Node) -> void:
	var mission := MISSION_EVENT.instantiate()
	scene_root.call_deferred("add_child", mission)
	mission.call_deferred("configure_for_map", RunStats.map_id)

func spawn_event_enemy(pool_id: String, spawn_position: Vector2) -> Node:
	var enemy = ObjectPoolManager.acquire(pool_id, spawn_position)
	if enemy:
		enemy.set_meta("pool_id", pool_id)
		_apply_difficulty(enemy, 1.0 + (time_elapsed / 60.0) * 0.4)
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
		_select_wave_modifier()
		RunStats.add_scrap(8 + current_wave * 2)
		EventBus.wave_shop_requested.emit(current_wave)
		if current_wave > 2:
			SaveManager.add_gold(5 + current_wave * 2)
		SaveManager.save_data() # One combat checkpoint per wave, not per reward pickup.

	if time_elapsed >= next_boss_time and not boss_spawned: # 5 Minutes
		_spawn_boss()
		return

	if boss_spawned:
		return # Stop normal spawns during boss fight

	if time_elapsed >= next_miniboss_time:
		next_miniboss_time += 90.0
		_spawn_miniboss()
	if time_elapsed >= next_supply_time:
		next_supply_time += 75.0
		_spawn_field_supply()

	var speed_up_factor = clampf(time_elapsed / 300.0, 0.0, 1.0)
	var current_delay = lerpf(base_spawn_delay, min_spawn_delay, speed_up_factor)
	var wave_spawn_multiplier = 1.0 + float(current_wave - 1) * 0.10

	# Spawn debt allows us to spawn multiple per frame if delay < delta
	var spawn_rate = (1.0 / current_delay) * wave_spawn_multiplier * RunStats.get_difficulty_spawn_mult() * modifier_spawn_mult
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
		boss_spawned = false
		return
	# Bosses enter from outside the player's current view even on the expanded maps.
	var boss_position := _get_player_spawn_position(player, 760.0, 920.0)
	var boss_scene := MAP_BOSSES.get(RunStats.map_id, MAP_BOSSES["map_1"]) as PackedScene
	var boss = boss_scene.instantiate()
	var scene_root := get_tree().current_scene
	if not is_instance_valid(scene_root):
		boss_spawned = false
		boss.queue_free()
		return
	scene_root.add_child(boss)
	boss.global_position = boss_position
	var endless_scale := 1.0 + float(bosses_defeated) * 0.35
	var health_scale := (38.0 if boss_data_hacked else 50.0) * RunStats.get_difficulty_health_mult() * endless_scale
	boss.configure(health_scale, RunStats.get_difficulty_damage_mult(), boss_data_hacked, bosses_defeated)

func _spawn_zombie() -> bool:
	if _get_active_enemy_count() >= MAX_ACTIVE_ENEMIES:
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return false

	var pool_id: String = "zombie_base"
	var hp_multiplier: float = 1.0 + (time_elapsed / 60.0) * 0.65

	if active_modifier == "runner_rush" and randf() < 0.72:
		pool_id = "zombie_runner"
	elif active_modifier == "toxic_front" and randf() < 0.68:
		pool_id = "zombie_spitter" if randf() < 0.65 else "zombie_bloater"
	elif active_modifier == "volatile_night" and randf() < 0.6:
		pool_id = "zombie_bomber"
	elif active_modifier == "armored_column" and randf() < 0.5:
		pool_id = "zombie_tank"
	elif current_wave >= 7:
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
	_apply_difficulty(zombie, hp_multiplier)
	var elite_bonus := 0.14 if active_modifier == "armored_column" else 0.0
	if current_wave >= 5 and randf() < clampf(float(current_wave - 4) * 0.04 + elite_bonus, 0.0, 0.36):
		zombie.set_elite()

	return true

func _select_wave_modifier() -> void:
	var cycle := current_wave % 6
	modifier_spawn_mult = 1.0
	match cycle:
		0:
			active_modifier = "breather"
			modifier_spawn_mult = 0.58
			EventBus.combat_modifier_changed.emit("숨 고르기", "적 밀도 감소 · 현장 보급 투하", WAVE_DURATION)
			_spawn_field_supply(false)
		1:
			active_modifier = "runner_rush"
			modifier_spawn_mult = 1.22
			EventBus.combat_modifier_changed.emit("질주 감염체 쇄도", "러너 비율과 등장 밀도 증가", WAVE_DURATION)
		2:
			active_modifier = "toxic_front"
			EventBus.combat_modifier_changed.emit("독성 전선", "스피터와 블로터 집중 출현", WAVE_DURATION)
		3:
			active_modifier = "armored_column"
			modifier_spawn_mult = 0.82
			EventBus.combat_modifier_changed.emit("장갑 행렬", "탱커와 정예 확률 증가", WAVE_DURATION)
		4:
			active_modifier = "volatile_night"
			modifier_spawn_mult = 1.08
			EventBus.combat_modifier_changed.emit("폭발성 야간", "폭발 감염체 집중 출현", WAVE_DURATION)
		_:
			active_modifier = "standard"
			EventBus.combat_modifier_changed.emit("혼성 군집", "다양한 감염체가 함께 접근", WAVE_DURATION)

func _spawn_miniboss() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player) or boss_spawned:
		return
	var pool_id := "zombie_tank" if int(time_elapsed / 90.0) % 2 == 1 else "zombie_bloater"
	var enemy = ObjectPoolManager.acquire(pool_id, _get_player_spawn_position(player, 720.0, 860.0))
	if not enemy:
		return
	enemy.set_meta("pool_id", pool_id)
	_apply_difficulty(enemy, 3.2 + float(current_wave) * 0.18)
	enemy.set_elite()
	enemy.scale *= 1.45
	enemy.modulate = Color(1.0, 0.48, 0.18, 1.0)
	EventBus.combat_modifier_changed.emit("정예 추적자 출현", "강화 개체를 처치하면 추가 스크랩을 획득합니다", 7.0)

func _spawn_field_supply(announce: bool = true) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var scene_root := get_tree().current_scene
	if not is_instance_valid(player) or not is_instance_valid(scene_root):
		return
	var cache := SUPPLY_CACHE.instantiate()
	cache.gold_reward = 20
	cache.heal_amount = 25
	cache.lifetime = 50.0
	var drop_position := player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(190.0, 310.0)
	drop_position.x = clampf(drop_position.x, spawn_bounds.position.x + 100.0, spawn_bounds.end.x - 100.0)
	drop_position.y = clampf(drop_position.y, spawn_bounds.position.y + 100.0, spawn_bounds.end.y - 100.0)
	cache.global_position = drop_position
	scene_root.add_child(cache)
	if announce:
		EventBus.combat_modifier_changed.emit("현장 보급 감지", "근처에 회복·골드 보급품이 투하되었습니다", 6.0)

func _apply_difficulty(enemy: Node, health_multiplier: float) -> void:
	if enemy.has_method("set_scaled_max_health"):
		enemy.set_scaled_max_health(health_multiplier * RunStats.get_difficulty_health_mult())
	_apply_enemy_damage(enemy)

func _apply_enemy_damage(enemy: Node) -> void:
	var damage_mult := RunStats.get_difficulty_damage_mult()
	var attack_value = enemy.get("attack_damage")
	if attack_value != null:
		enemy.set("attack_damage", maxi(1, roundi(float(attack_value) * damage_mult)))
	var projectile_value = enemy.get("projectile_damage")
	if projectile_value != null:
		enemy.set("projectile_damage", maxi(1, roundi(float(projectile_value) * damage_mult)))

func _on_boss_defeated() -> void:
	bosses_defeated += 1
	if RunStats.endless_mode:
		boss_spawned = false
		next_boss_time += 300.0

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
