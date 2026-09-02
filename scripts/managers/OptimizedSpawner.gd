class_name OptimizedSpawner
extends Node

const DEFAULT_ZOMBIE_SCENE: PackedScene = preload("res://scenes/enemies/optimized_zombie.tscn")

@export var zombie_scene: PackedScene = DEFAULT_ZOMBIE_SCENE
@export var target_player: Node2D
@export var pool_size: int = 1024
@export var max_size: int = 1200
@export var max_active: int = 1200
@export var spawn_per_frame: int = 8
@export var spawn_rate: float = 30.0
@export var initial_wave_size: int = 0
@export_enum("Circle ring", "Rectangle ring") var ring_shape: int = 0
@export var ring_margin: float = 96.0
@export var ring_width: float = 180.0
@export var spawn_bounds: Rect2
@export var zombie_hp: int = 30
@export var zombie_speed: float = 100.0

var _spawn_remaining: int = 0
var _spawn_debt: float = 0.0

func _ready() -> void:
	if not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as Node2D
	var parent := get_tree().current_scene if is_instance_valid(get_tree().current_scene) else get_parent()
	ObjectPoolManager.configure_pool(zombie_scene, pool_size, max_size, parent)
	if initial_wave_size > 0:
		queue_wave(initial_wave_size)

func queue_wave(count: int, hp: int = -1, speed: float = -1.0) -> void:
	_spawn_remaining += maxi(0, count)
	if hp > 0:
		zombie_hp = hp
	if speed > 0.0:
		zombie_speed = speed

func _process(delta: float) -> void:
	if _spawn_remaining <= 0 or not is_instance_valid(target_player):
		return
	var active := ObjectPoolManager.get_active_count(zombie_scene)
	if active >= max_active:
		return
	_spawn_debt = minf(_spawn_debt + spawn_rate * delta, float(maxi(1, spawn_per_frame) * 2))
	var budget := mini(maxi(0, spawn_per_frame), _spawn_remaining)
	var spawned := 0
	while _spawn_debt >= 1.0 and spawned < budget and active + spawned < max_active:
		var zombie := _spawn_one()
		if zombie == null:
			break
		_spawn_debt -= 1.0
		_spawn_remaining -= 1
		spawned += 1

func _spawn_one() -> Node2D:
	var position := _get_ring_position()
	return ObjectPoolManager.spawn(zombie_scene, position, 0.0,
		[zombie_hp, zombie_speed, target_player])

func _get_ring_position() -> Vector2:
	var center := target_player.global_position
	var half_view := _get_view_half_extents()
	var margin := maxf(32.0, ring_margin)
	var candidate := center
	if ring_shape == 0:
		var radius := maxf(half_view.x, half_view.y) + margin + randf_range(0.0, ring_width)
		candidate = center + Vector2.RIGHT.rotated(randf() * TAU) * radius
	else:
		var outer := half_view + Vector2.ONE * margin
		match randi_range(0, 3):
			0: candidate = center + Vector2(-outer.x, randf_range(-outer.y, outer.y))
			1: candidate = center + Vector2(outer.x, randf_range(-outer.y, outer.y))
			2: candidate = center + Vector2(randf_range(-outer.x, outer.x), -outer.y)
			_: candidate = center + Vector2(randf_range(-outer.x, outer.x), outer.y)
	var spawn_manager := get_tree().get_first_node_in_group("spawn_manager")
	if is_instance_valid(spawn_manager) and spawn_manager.has_method("get_safe_spawn_position"):
		return spawn_manager.call("get_safe_spawn_position", candidate)
	return _clamp_to_spawn_bounds(candidate)

func _get_view_half_extents() -> Vector2:
	var viewport_size := Vector2(1280.0, 720.0)
	var viewport := get_viewport()
	if viewport:
		viewport_size = viewport.get_visible_rect().size
	var camera := viewport.get_camera_2d() if viewport else null
	if camera:
		var zoom := Vector2(maxf(absf(camera.zoom.x), 0.01), maxf(absf(camera.zoom.y), 0.01))
		return viewport_size * 0.5 / zoom
	return viewport_size * 0.5

func _clamp_to_spawn_bounds(position: Vector2) -> Vector2:
	if spawn_bounds.size.x <= 0.0 or spawn_bounds.size.y <= 0.0:
		return position
	return Vector2(
		clampf(position.x, spawn_bounds.position.x, spawn_bounds.end.x),
		clampf(position.y, spawn_bounds.position.y, spawn_bounds.end.y)
	)
