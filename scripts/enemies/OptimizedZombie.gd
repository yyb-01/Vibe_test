class_name OptimizedZombie
extends CharacterBody2D

const BLUE_FIRE_EXPLOSION: PackedScene = preload("res://scenes/weapons/advanced/explosion.tscn")

@export var max_health: int = 30
@export var move_speed: float = 100.0
@export var attack_range: float = 58.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var ai_interval_min: float = 0.10
@export var ai_interval_max: float = 0.30
@export var repulsion_radius: float = 58.0
@export var repulsion_strength: float = 0.85

@onready var sprite: Sprite2D = $Sprite2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var health: int
var target_player: Node2D
var _grid: Node
var _on_screen := true
var _ai_timer := 0.0
var _attack_timer := 0.0
var _visual_time := 0.0
var _hit_flash_time := 0.0
var _hit_tween: Tween
var _cached_direction := Vector2.ZERO
var _cached_repulsion := Vector2.ZERO
var _cached_distance_sq := INF
var _base_max_health := 30
var _base_speed := 100.0
var _spawn_speed := 100.0
var _slow_time := 0.0
var _world_bounds := Rect2()

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	safe_margin = 0.04
	collision_layer = 4
	collision_mask = 2
	_grid = get_node_or_null("/root/SpatialGrid")
	if not screen_notifier.screen_entered.is_connected(_on_screen_entered):
		screen_notifier.screen_entered.connect(_on_screen_entered)
	if not screen_notifier.screen_exited.is_connected(_on_screen_exited):
		screen_notifier.screen_exited.connect(_on_screen_exited)
	_base_max_health = max_health
	_base_speed = move_speed
	_spawn_speed = move_speed
	health = 0
	sprite.visible = false
	set_process(false)
	set_physics_process(false)
	_set_hit_shader(false)

func on_spawn(init_hp: int = -1, speed_override: float = -1.0,
		new_target_player: Node2D = null) -> void:
	health = maxi(1, init_hp if init_hp > 0 else _base_max_health)
	max_health = health
	move_speed = speed_override if speed_override > 0.0 else _base_speed
	_spawn_speed = move_speed
	_slow_time = 0.0
	target_player = new_target_player if is_instance_valid(new_target_player) and not new_target_player.is_queued_for_deletion() else _find_player()
	_world_bounds = _find_world_bounds()
	_ai_timer = randf_range(ai_interval_min, ai_interval_max)
	_attack_timer = 0.0
	_visual_time = randf() * TAU
	_hit_flash_time = 0.0
	_cached_direction = Vector2.ZERO
	_cached_repulsion = Vector2.ZERO
	_cached_distance_sq = INF
	velocity = Vector2.ZERO
	rotation = 0.0
	modulate = Color.WHITE
	collision_layer = 4
	collision_mask = 2
	sprite.visible = true
	_set_hit_shader(false)
	_on_screen = true
	set_meta("blue_fire", false)
	set_meta("blue_fire_damage", 0)
	set_process(true)
	set_physics_process(true)
	_grid = get_node_or_null("/root/SpatialGrid")
	if is_instance_valid(_grid):
		_grid.call("insert", self)

func on_despawn() -> void:
	_kill_tween()
	health = 0
	target_player = null
	velocity = Vector2.ZERO
	_cached_direction = Vector2.ZERO
	_cached_repulsion = Vector2.ZERO
	_cached_distance_sq = INF
	_slow_time = 0.0
	_spawn_speed = _base_speed
	set_meta("blue_fire", false)
	set_meta("blue_fire_damage", 0)
	_hit_flash_time = 0.0
	_set_hit_shader(false)
	sprite.visible = false
	set_process(false)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(_grid) and _grid.has_method("remove"):
		_grid.call("remove", self)

func set_scaled_max_health(multiplier: float) -> void:
	max_health = maxi(1, roundi(float(_base_max_health) * maxf(multiplier, 0.0)))
	health = max_health

func set_elite() -> void:
	max_health = roundi(float(max_health) * 1.8)
	health = max_health
	move_speed *= 1.12

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			move_speed = _spawn_speed
	_ai_timer -= delta
	if _ai_timer <= 0.0:
		_ai_timer = randf_range(ai_interval_min, ai_interval_max)
		_refresh_steering()
	_attack_timer = maxf(0.0, _attack_timer - delta)
	if _cached_direction == Vector2.ZERO:
		return

	var steering := (_cached_direction + _cached_repulsion * repulsion_strength).normalized()
	var old_position := global_position
	velocity = steering * move_speed
	if _on_screen:
		move_and_slide()
	else:
		# Keep the cheap off-screen path, but hand movement to physics when an
		# obstacle is directly ahead so walls cannot be crossed or escaped.
		if test_move(global_transform, velocity * delta):
			move_and_slide()
		else:
			global_position += velocity * delta
			if _world_bounds.size.x > 0.0 and _world_bounds.size.y > 0.0:
				global_position.x = clampf(global_position.x, _world_bounds.position.x, _world_bounds.end.x)
				global_position.y = clampf(global_position.y, _world_bounds.position.y, _world_bounds.end.y)
	_update_grid(old_position)
	if _attack_timer <= 0.0 and _cached_distance_sq <= attack_range * attack_range:
		_attack_player()

func _process(delta: float) -> void:
	_visual_time += delta
	if _hit_flash_time > 0.0:
		_hit_flash_time -= delta
		if _hit_flash_time <= 0.0:
			_set_hit_shader(false)
	if sprite.hframes > 1:
		sprite.frame = int(_visual_time * 8.0) % sprite.hframes
	else:
		sprite.rotation = sin(_visual_time * 6.0) * 0.02

func _refresh_steering() -> void:
	if not is_instance_valid(target_player) or target_player.is_queued_for_deletion():
		target_player = _find_player()
	if not is_instance_valid(target_player) or target_player.is_queued_for_deletion():
		_cached_direction = Vector2.ZERO
		_cached_repulsion = Vector2.ZERO
		_cached_distance_sq = INF
		return
	var offset := target_player.global_position - global_position
	_cached_distance_sq = offset.length_squared()
	_cached_direction = offset.normalized() if _cached_distance_sq > 0.01 else Vector2.ZERO
	_cached_repulsion = _calculate_repulsion()

func _calculate_repulsion() -> Vector2:
	if not is_instance_valid(_grid) or not _grid.has_method("get_nearby_entities"):
		# ponytail: the spatial grid is required; an O(n²) fallback is not viable at 1,000 entities.
		return Vector2.ZERO
	var result := Vector2.ZERO
	var radius_sq := repulsion_radius * repulsion_radius
	for neighbor in _grid.call("get_nearby_entities", global_position, repulsion_radius):
		if neighbor == self or not is_instance_valid(neighbor) or not neighbor is Node2D:
			continue
		var away := global_position - (neighbor as Node2D).global_position
		var distance_sq := away.length_squared()
		if distance_sq > 0.01 and distance_sq < radius_sq:
			var distance := sqrt(distance_sq)
			result += away / distance * (1.0 - distance / repulsion_radius)
	return result.limit_length(1.0)

func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO,
		_hit_kind: String = "normal", _weapon_id: String = "") -> void:
	if health <= 0 or amount <= 0:
		return
	var applied_damage := mini(amount, health)
	health -= applied_damage
	var damage_number := ObjectPoolManager.acquire("damage_number", global_position)
	if is_instance_valid(damage_number) and damage_number.has_method("configure"):
		damage_number.configure(applied_damage, _hit_kind)
	if hit_direction.length_squared() > 0.01:
		global_position += hit_direction.normalized() * 2.0
	if is_instance_valid(HitEffectManager):
		HitEffectManager.play_hit(applied_damage, _hit_kind, hit_direction.normalized())
	_set_hit_shader(true)
	_hit_flash_time = 0.06
	if health <= 0:
		die()

func die() -> void:
	if health > 0:
		health = 0
	if bool(get_meta("blue_fire", false)):
		ObjectPoolManager.spawn(BLUE_FIRE_EXPLOSION, global_position, 0.0,
			[80.0, float(get_meta("blue_fire_damage", 24.0)), null, 120.0, Color(0.15, 0.65, 1.0, 1.0)])
	ObjectPoolManager.despawn(self)

func apply_slow(multiplier: float, duration: float) -> void:
	_spawn_speed = maxf(_spawn_speed, 1.0)
	_slow_time = maxf(_slow_time, duration)
	move_speed = _spawn_speed * clampf(multiplier, 0.1, 1.0)

func _attack_player() -> void:
	if not is_instance_valid(target_player) or target_player.is_queued_for_deletion() or not target_player.has_method("take_damage"):
		return
	_attack_timer = attack_cooldown
	target_player.call("take_damage", attack_damage, global_position.direction_to(target_player.global_position))

func _find_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

func _find_world_bounds() -> Rect2:
	var manager := get_tree().get_first_node_in_group("spawn_manager")
	if is_instance_valid(manager):
		var bounds = manager.get("spawn_bounds")
		if bounds is Rect2:
			return bounds
	return Rect2()

func _update_grid(old_position: Vector2) -> void:
	if is_instance_valid(_grid) and _grid.has_method("update_entity"):
		_grid.call("update_entity", self, old_position, global_position)

func _on_screen_entered() -> void:
	_on_screen = true
	sprite.visible = true
	set_process(true)

func _on_screen_exited() -> void:
	_on_screen = false
	sprite.visible = false
	set_process(false)

func _set_hit_shader(active: bool) -> void:
	if sprite.material is ShaderMaterial:
		(sprite.material as ShaderMaterial).set_shader_parameter("active", active)

func _kill_tween() -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_tween = null
