class_name ElectricBeam
extends Line2D

var _age: float = 0.0
var _duration: float = 0.25
var _tick: float = 0.0
var _damage: float = 0.0
var _target: Node2D
var _source: Node

func on_spawn(start: Vector2 = Vector2.ZERO, finish: Vector2 = Vector2.RIGHT,
		init_duration: float = 0.25, init_damage: float = 0.0,
		init_target: Node2D = null, init_source: Node = null) -> void:
	_age = 0.0
	_tick = 0.0
	_duration = maxf(0.01, init_duration)
	_damage = maxf(0.0, init_damage)
	_target = init_target
	_source = init_source
	global_position = start
	points = PackedVector2Array([Vector2.ZERO, finish - start])
	width = 5.0
	default_color = Color(0.35, 0.9, 1.0, 0.95)
	z_index = 18
	modulate.a = 1.0

func _process(delta: float) -> void:
	if get_meta("_pool_release_pending", false):
		return
	_age += delta
	_tick -= delta
	if _damage > 0.0 and _tick <= 0.0 and is_instance_valid(_target) and _is_live_enemy(_target):
		_tick += 0.2
		_target.call("take_damage", maxi(1, roundi(_damage)), Vector2.ZERO, "lightning", "전도 피해")
	modulate.a = 1.0 - clampf(_age / _duration, 0.0, 1.0)
	if _age >= _duration:
		ObjectPoolManager.despawn(self)

func _is_live_enemy(target: Node2D) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	var health = target.get("health")
	return target.is_in_group("enemies") and health != null \
		and int(health) > 0 and not bool(target.get("is_dying"))

func on_despawn() -> void:
	points = PackedVector2Array()
	_target = null
	_source = null
	_age = 0.0
	modulate.a = 0.0
	set_process(false)
