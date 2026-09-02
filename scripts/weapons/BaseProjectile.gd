class_name BaseProjectile
extends Area2D

@export var speed: float = 720.0
@export var max_lifetime: float = 2.0
@export var max_distance: float = 1400.0
@export var max_pierce: int = 0

var direction: Vector2 = Vector2.RIGHT
var damage: float = 1.0
var lifetime: float = 0.0
var distance_traveled: float = 0.0
var remaining_pierce: int = 0
var source: Node
var source_weapon_id: String = ""
var hit_targets: Dictionary = {}
var _default_speed: float
var _default_max_lifetime: float
var _default_max_distance: float
var _default_max_pierce: int

func _ready() -> void:
	_default_speed = speed
	_default_max_lifetime = maxf(max_lifetime, 0.01)
	_default_max_distance = maxf(max_distance, 1.0)
	_default_max_pierce = maxi(max_pierce, 0)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	reset_base()

func on_spawn(init_direction: Vector2 = Vector2.RIGHT, init_damage: float = 1.0,
		init_source: Node = null, init_pierce: int = -1, extras: Dictionary = {}) -> void:
	reset_base()
	direction = init_direction.normalized() if init_direction.length_squared() > 0.001 else Vector2.RIGHT
	damage = maxf(0.0, init_damage)
	source = init_source
	remaining_pierce = max_pierce if init_pierce < 0 else maxi(0, init_pierce)
	source_weapon_id = String(extras.get("weapon_id", ""))
	collision_layer = 8
	collision_mask = 2 | 4

func reset_base() -> void:
	speed = _default_speed if _default_speed > 0.0 else speed
	max_lifetime = _default_max_lifetime if _default_max_lifetime > 0.0 else maxf(max_lifetime, 0.01)
	max_distance = _default_max_distance if _default_max_distance > 0.0 else maxf(max_distance, 1.0)
	max_pierce = _default_max_pierce
	direction = Vector2.RIGHT
	damage = 1.0
	lifetime = 0.0
	distance_traveled = 0.0
	remaining_pierce = 0
	source = null
	source_weapon_id = ""
	hit_targets.clear()
	rotation = 0.0

func on_despawn() -> void:
	reset_base()
	collision_layer = 0
	collision_mask = 0

func _physics_process(delta: float) -> void:
	if get_meta("_pool_release_pending", false):
		return
	lifetime += delta
	if lifetime >= max_lifetime or distance_traveled >= max_distance:
		despawn()
		return
	var step := speed * delta
	global_position += direction * step
	distance_traveled += step
	rotation = direction.angle()
	if distance_traveled >= max_distance:
		despawn()

func _on_body_entered(body: Node2D) -> void:
	if not _can_hit(body):
		return
	if not body.is_in_group("enemies"):
		despawn()
		return
	hit_targets[body] = true
	_apply_damage(body, damage, direction)
	remaining_pierce -= 1
	if remaining_pierce < 0:
		despawn()

func _can_hit(body: Node2D) -> bool:
	return not get_meta("_pool_release_pending", false) and is_instance_valid(body) \
		and not body.is_queued_for_deletion() and not body.is_in_group("player") \
		and not hit_targets.has(body)

func _apply_damage(target: Node2D, amount: float, hit_direction: Vector2,
		hit_kind: String = "normal") -> void:
	if is_instance_valid(target) and not target.is_queued_for_deletion() and target.has_method("take_damage"):
		target.call("take_damage", maxi(1, roundi(amount)), hit_direction, hit_kind, source_weapon_id)

func get_nearby_enemies(position: Vector2, radius: float) -> Array[Node2D]:
	var candidates: Array = []
	var grid := get_node_or_null("/root/SpatialGrid")
	if is_instance_valid(grid) and grid.has_method("get_nearby_entities"):
		var nearby = grid.call("get_nearby_entities", position, radius)
		if nearby is Array:
			candidates = nearby
	else:
		# ponytail: rare effect fallback is O(n); add a spatial query if this path becomes hot.
		candidates = get_tree().get_nodes_in_group("enemies")
	var result: Array[Node2D] = []
	var radius_sq := radius * radius
	for candidate in candidates:
		if not candidate is Node2D or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		var health = candidate.get("health")
		if candidate.is_in_group("enemies") \
				and health != null and not candidate.get("is_dying") and int(health) > 0 \
				and position.distance_squared_to(candidate.global_position) <= radius_sq:
			result.append(candidate as Node2D)
	return result

func spawn_effect(scene: PackedScene, position: Vector2, args: Array = [],
		rot: float = 0.0) -> Node2D:
	return ObjectPoolManager.spawn(scene, position, rot, args)

func add_knockback(target: Node2D, force: float, hit_direction: Vector2) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or force <= 0.0:
		return
	if target.has_method("apply_knockback"):
		target.call("apply_knockback", hit_direction * force)
		return
	var current = target.get("knockback")
	if current is Vector2:
		target.set("knockback", current + hit_direction.normalized() * force)

func despawn() -> void:
	ObjectPoolManager.despawn(self)
