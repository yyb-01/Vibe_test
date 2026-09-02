class_name TeslaBolt
extends "res://scripts/weapons/BaseProjectile.gd"

const BEAM: PackedScene = preload("res://scenes/weapons/advanced/electric_beam.tscn")
var _chain_radius: float = 120.0
var _chain_count: int = 2
var _chained: bool = false

func on_spawn(init_direction: Vector2 = Vector2.RIGHT, init_damage: float = 1.0,
		init_source: Node = null, init_pierce: int = 2, extras: Dictionary = {}) -> void:
	super.on_spawn(init_direction, init_damage, init_source, init_pierce, extras)
	_chain_radius = maxf(float(extras.get("chain_radius", 120.0)), 1.0)
	_chain_count = maxi(1, int(extras.get("chain_count", 2)))
	_chained = false
	speed = maxf(speed, 1000.0)

func _on_body_entered(body: Node2D) -> void:
	if _chained or not _can_hit(body):
		return
	if not body.is_in_group("enemies"):
		despawn()
		return
	_chained = true
	hit_targets[body] = true
	var first_position := body.global_position
	_apply_damage(body, damage, direction, "lightning")
	_chain_from(first_position, body)
	despawn()

func _chain_from(first_position: Vector2, first: Node2D) -> void:
	var candidates := get_nearby_enemies(first_position, _chain_radius)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return first_position.distance_squared_to(a.global_position) < first_position.distance_squared_to(b.global_position))
	var previous_position := first_position
	var chained := 0
	for target in candidates:
		if chained >= _chain_count or target == first or hit_targets.has(target):
			continue
		var target_position := target.global_position
		if not _clear_line(previous_position, target_position):
			continue
		hit_targets[target] = true
		var chain_direction := previous_position.direction_to(target_position)
		_apply_damage(target, damage * 0.7, chain_direction, "lightning")
		spawn_effect(BEAM, previous_position, [previous_position, target_position, 0.28, damage * 0.15, target, source])
		previous_position = target_position
		chained += 1

func _clear_line(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 2)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func on_despawn() -> void:
	_chained = false
	super.on_despawn()
