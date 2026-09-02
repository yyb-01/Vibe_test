class_name ClusterNebula
extends "res://scripts/weapons/projectiles/RocketMissile.gd"

const BOMBLET: PackedScene = preload("res://scenes/weapons/advanced/cluster_bomblet.tscn")

func _explode() -> void:
	if _exploded or get_meta("_pool_release_pending", false):
		return
	_exploded = true
	var center := global_position
	spawn_effect(EXPLOSION, center,
		[96.0 * _area_scale, damage, source, _knockback, Color(0.65, 0.38, 1.0, 1.0)])
	for index in 6:
		var angle := randf() * TAU
		var distance := randf_range(30.0, 80.0)
		var fuse := randf_range(0.3, 0.5)
		var direction := Vector2.RIGHT.rotated(angle)
		spawn_effect(BOMBLET, center, [direction, damage * 0.38, source, 0, {
			"target_position": center + direction * distance,
			"fuse": fuse,
			"knockback": _knockback * 0.7,
			"weapon_id": source_weapon_id
		}])
	despawn()

