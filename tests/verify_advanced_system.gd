extends Node

const CATALOG: Script = preload("res://scripts/resources/advanced_weapon_catalog.gd")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ADVANCED_WEAPON_SCRIPT: Script = preload("res://scripts/weapons/AdvancedWeapon.gd")
const PROJECTILE_SCENES: Array[PackedScene] = [
	preload("res://scenes/weapons/advanced/pistol_bullet.tscn"),
	preload("res://scenes/weapons/advanced/dual_beretta.tscn"),
	preload("res://scenes/weapons/advanced/shotgun_pellet.tscn"),
	preload("res://scenes/weapons/advanced/dragons_breath.tscn"),
	preload("res://scenes/weapons/advanced/revolver_bullet.tscn"),
	preload("res://scenes/weapons/advanced/magnum_opus.tscn"),
	preload("res://scenes/weapons/advanced/flame_stream.tscn"),
	preload("res://scenes/weapons/advanced/infernal_sonata.tscn"),
	preload("res://scenes/weapons/advanced/rocket_missile.tscn"),
	preload("res://scenes/weapons/advanced/cluster_nebula.tscn"),
	preload("res://scenes/weapons/advanced/tesla_bolt.tscn"),
	preload("res://scenes/weapons/advanced/thors_smite.tscn")
]

class MockPlayer extends Node:
	var weapons: Array = []
	var passives: Array = []
	var max_weapons: int = 6
	var max_passives: int = 6

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var weapons: Array = CATALOG.get_weapons()
	var passives: Array = CATALOG.get_passives()
	var recipes: Array = CATALOG.get_recipes()
	assert(weapons.size() == 12)
	assert(passives.size() == 6)
	assert(recipes.size() == 6)
	var base := Weapon.new()
	base.data = weapons[0]
	base.current_level = base.data.max_level
	assert(EvolutionManager.can_evolve(base, [passives[0]], recipes[0]))
	for scene in PROJECTILE_SCENES:
		var instance := scene.instantiate()
		assert(instance != null)
		instance.free()
		ObjectPoolManager.configure_pool(scene, 1, 64, self)
		var payload: Array = [Vector2.RIGHT, 10.0, null, 0, {}]
		if scene.resource_path.ends_with("thors_smite.tscn"):
			payload = [null, 10.0, 5, {}]
		var pooled := ObjectPoolManager.spawn(scene, Vector2.ZERO, 0.0, payload)
		if pooled != null:
			ObjectPoolManager.despawn(pooled)
	var mock := MockPlayer.new()
	mock.weapons.append(base)
	mock.passives.append(passives[0])
	add_child(mock)
	var choices: Array[Dictionary] = UpgradeManager.get_level_up_choices(mock, 4)
	assert(not choices.is_empty())
	assert(String(choices[0].get("kind")) == "evolution")
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	for data in weapons:
		var weapon := ADVANCED_WEAPON_SCRIPT.new() as Weapon
		weapon.data = data
		player.add_child(weapon)
		assert(weapon.fire(player, player.global_position + Vector2(320.0, 0.0)))
	ObjectPoolManager.clear()
	print("Advanced weapon self-check passed: 12 scenes, 6 recipes, evolution priority.")
	get_tree().quit(0)
