class_name ProjectilePool
extends Node2D

const ProjectileScene = preload("res://entities/combat/projectile.tscn")

@export_range(8, 256) var prewarm_size: int = 48
@export_range(16, 512) var max_size: int = 192

var _free_projectiles: Array[Projectile] = []

func _ready() -> void:
	add_to_group("projectile_pool")
	for _i in range(prewarm_size):
		_free_projectiles.append(_make_projectile())

func spawn(world_position: Vector2, direction: Vector2, damage: float, speed: float, shooter: Node, critical: bool = false) -> Projectile:
	var projectile: Projectile = _free_projectiles.pop_back() if not _free_projectiles.is_empty() else null
	if projectile == null:
		if get_child_count() >= max_size:
			return null
		projectile = _make_projectile()
	projectile.setup(world_position, direction, damage, speed, shooter, critical)
	return projectile

func release(projectile: Projectile) -> void:
	if projectile == null or projectile in _free_projectiles:
		return
	projectile.deactivate()
	_free_projectiles.append(projectile)

func _make_projectile() -> Projectile:
	var projectile := ProjectileScene.instantiate() as Projectile
	projectile.pool = self
	add_child(projectile)
	projectile.deactivate()
	return projectile
