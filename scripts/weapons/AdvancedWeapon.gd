class_name AdvancedWeapon
extends "res://scripts/weapons/weapon.gd"

const PISTOL: PackedScene = preload("res://scenes/weapons/advanced/pistol_bullet.tscn")
const DUAL: PackedScene = preload("res://scenes/weapons/advanced/dual_beretta.tscn")
const SHOTGUN: PackedScene = preload("res://scenes/weapons/advanced/shotgun_pellet.tscn")
const DRAGON: PackedScene = preload("res://scenes/weapons/advanced/dragons_breath.tscn")
const REVOLVER: PackedScene = preload("res://scenes/weapons/advanced/revolver_bullet.tscn")
const MAGNUM: PackedScene = preload("res://scenes/weapons/advanced/magnum_opus.tscn")
const FLAME: PackedScene = preload("res://scenes/weapons/advanced/flame_stream.tscn")
const INFERNAL: PackedScene = preload("res://scenes/weapons/advanced/infernal_sonata.tscn")
const ROCKET: PackedScene = preload("res://scenes/weapons/advanced/rocket_missile.tscn")
const CLUSTER: PackedScene = preload("res://scenes/weapons/advanced/cluster_nebula.tscn")
const TESLA: PackedScene = preload("res://scenes/weapons/advanced/tesla_bolt.tscn")
const THOR: PackedScene = preload("res://scenes/weapons/advanced/thors_smite.tscn")
const EFFECT_SCENES: Array[PackedScene] = [
	preload("res://scenes/weapons/advanced/fire_zone.tscn"),
	preload("res://scenes/weapons/advanced/explosion.tscn"),
	preload("res://scenes/weapons/advanced/shrapnel_bullet.tscn"),
	preload("res://scenes/weapons/advanced/cluster_bomblet.tscn"),
	preload("res://scenes/weapons/advanced/electric_beam.tscn"),
	preload("res://scenes/weapons/advanced/lightning_strike.tscn")
]

var _dual_side: int = 0

func _ready() -> void:
	super._ready()
	var parent := get_tree().current_scene
	if not is_instance_valid(parent):
		parent = get_parent()
	if data != null and is_instance_valid(parent):
		ObjectPoolManager.configure_pool(_scene_for(data.get_id(), PISTOL), 96, 2048, parent)
		for effect_scene in EFFECT_SCENES:
			ObjectPoolManager.configure_pool(effect_scene, 12, 512, parent)

func fire(player: Player, target_pos: Vector2) -> bool:
	if not super.fire(player, target_pos) or data == null:
		return false
	var weapon_id := data.get_id()
	var damage_value := data.damage * (1.0 + 0.12 * float(current_level - 1)) * player.damage_mult
	var pierce_count := data.pierce + player.pierce_add
	match weapon_id:
		"pistol":
			_fire_single(PISTOL, player, target_pos, damage_value, pierce_count)
		"dual_beretta":
			_fire_dual(player, target_pos, damage_value, pierce_count)
		"shotgun":
			_fire_spread(SHOTGUN, player, target_pos, damage_value, pierce_count, data.projectile_count)
		"dragons_breath":
			_fire_spread(DRAGON, player, target_pos, damage_value, 999, data.projectile_count, {"spawn_zone": true})
		"heavy_revolver":
			_fire_single(REVOLVER, player, target_pos, damage_value, maxi(3, pierce_count))
		"magnum_opus":
			_fire_single(MAGNUM, player, target_pos, damage_value, maxi(4, pierce_count), {"crit_chance": 0.25 + player.critical_chance_add})
		"flamethrower":
			_fire_single(FLAME, player, target_pos, damage_value, 999)
		"infernal_sonata":
			_fire_single(INFERNAL, player, target_pos, damage_value, 999)
		"rpg":
			_fire_single(ROCKET, player, target_pos, damage_value, 0, {"target_position": target_pos})
		"cluster_nebula":
			_fire_single(CLUSTER, player, target_pos, damage_value, 0, {"target_position": target_pos})
		"tesla_cannon":
			_fire_single(TESLA, player, target_pos, damage_value, pierce_count)
		"thors_smite":
			_fire_thor(player, damage_value)
		_:
			_fire_single(data.projectile_scene, player, target_pos, damage_value, pierce_count)
	return true

func _fire_dual(player: Player, target_pos: Vector2, damage_value: float, pierce_count: int) -> void:
	var aim_pos := player.get_muzzle_global_position()
	var direction := aim_pos.direction_to(target_pos)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var side_offset := direction.orthogonal() * (10.0 if _dual_side == 0 else -10.0)
	_dual_side = 1 - _dual_side
	_spawn(DUAL, aim_pos + side_offset, direction, damage_value, pierce_count)
	var base_speed := float(player.get_meta("base_move_speed", 200.0))
	var excess_speed := maxf(player.move_speed - base_speed, 0.0)
	cooldown_timer = maxf(0.03, cooldown_timer / (1.0 + excess_speed / maxf(1.0, base_speed)))

func _fire_single(scene: PackedScene, player: Player, target_pos: Vector2, damage_value: float,
		pierce_count: int, extras: Dictionary = {}) -> void:
	if scene == null:
		return
	var muzzle := player.get_muzzle_global_position()
	var direction := muzzle.direction_to(target_pos)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	_spawn(scene, muzzle, direction, damage_value, pierce_count, extras)

func _fire_spread(scene: PackedScene, player: Player, target_pos: Vector2, damage_value: float,
		pierce_count: int, count: int, extras: Dictionary = {}) -> void:
	if scene == null:
		return
	var muzzle := player.get_muzzle_global_position()
	var direction := muzzle.direction_to(target_pos)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var shot_count := maxi(1, count)
	var spread := deg_to_rad(data.spread_angle)
	for index in range(shot_count):
		var ratio := 0.0 if shot_count == 1 else float(index) / float(shot_count - 1) - 0.5
		var shot_extra := extras.duplicate()
		if data.get_id() == "dragons_breath":
			shot_extra["spawn_zone"] = index == 0
		_spawn(scene, muzzle, direction.rotated(ratio * spread), damage_value, pierce_count, shot_extra)

func _fire_thor(player: Player, damage_value: float) -> void:
	ObjectPoolManager.spawn(THOR, player.global_position, 0.0,
		[player, damage_value, mini(5, maxi(1, data.projectile_count)), {"weapon_id": data.get_id()}])

func _spawn(scene: PackedScene, position: Vector2, direction: Vector2, damage_value: float,
		pierce_count: int, extras: Dictionary = {}) -> Node2D:
	if scene == null:
		return null
	var payload := extras.duplicate()
	payload["weapon_id"] = data.get_id()
	var owner := get_parent()
	var area_multiplier := float(owner.get_meta("advanced_area_mult", 1.0)) if owner is Node else 1.0
	payload["area_scale"] = data.area_scale * area_multiplier
	payload["knockback"] = data.knockback
	payload["fan_angle"] = data.spread_angle
	if data.get_id() == "shotgun":
		payload["max_distance"] = 420.0
	var projectile := ObjectPoolManager.spawn(scene, position, direction.angle(),
		[direction, damage_value, get_parent(), pierce_count, payload])
	if projectile != null and projectile.get("speed") != null and data.get_speed() > 0.0:
		projectile.set("speed", data.get_speed())
	return projectile

func _scene_for(id: String, fallback: PackedScene) -> PackedScene:
	if data != null and data.projectile_scene != null:
		return data.projectile_scene
	return fallback
