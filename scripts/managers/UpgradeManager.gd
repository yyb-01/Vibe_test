extends Node

const ADVANCED_WEAPON_SCRIPT: Script = preload("res://scripts/weapons/AdvancedWeapon.gd")
const CATALOG: Script = preload("res://scripts/resources/advanced_weapon_catalog.gd")

@export_range(3, 4, 1) var choices_per_level: int = 3
@export var weapon_pool: Array[WeaponData] = []
@export var passive_pool: Array[Resource] = []
@export var recipe_pool: Array[Resource] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if weapon_pool.is_empty():
		weapon_pool = CATALOG.get_weapons()
	if passive_pool.is_empty():
		passive_pool = CATALOG.get_passives()
	if recipe_pool.is_empty():
		recipe_pool = CATALOG.get_recipes()

func get_level_up_choices(player: Node, count: int = 0) -> Array[Dictionary]:
	if not is_instance_valid(player):
		return [] as Array[Dictionary]
	var amount := clampi(count if count > 0 else choices_per_level, 3, 4)
	var weapons: Array = player.get("weapons") if player.get("weapons") is Array else []
	var passives: Array = player.get("passives") if player.get("passives") is Array else []
	var choices: Array[Dictionary] = []
	for recipe in EvolutionManager.get_available_evolutions(weapons, passives, recipe_pool):
		var result_data := recipe.get("result_weapon_data") as WeaponData
		if result_data == null:
			continue
		choices.append({"kind": "evolution", "recipe": recipe, "data": result_data,
			"label": "진화", "display_name": result_data.get_display_name(),
			"description": result_data.description})
		if choices.size() >= amount:
			return choices

	var candidates: Array[Dictionary] = []
	for weapon_data in weapon_pool:
		if weapon_data == null or weapon_data.is_evolution:
			continue
		var owned = _find_weapon(weapons, weapon_data.get_id())
		if owned == null and weapons.size() < int(player.get("max_weapons")):
			candidates.append(_choice("weapon_new", weapon_data, "신규 무기"))
		elif owned != null and owned.current_level < weapon_data.max_level:
			candidates.append({"kind": "weapon_upgrade", "weapon": owned, "data": weapon_data,
				"display_name": weapon_data.get_display_name(), "description": "무기 레벨 상승"})
	for passive_data in passive_pool:
		if passive_data == null:
			continue
		var owned_passive := _find_passive(passives, passive_data.id)
		if owned_passive == null and passives.size() < int(player.get("max_passives")):
			candidates.append(_choice("passive_new", passive_data, "신규 패시브"))
		elif owned_passive != null and _passive_level(owned_passive) < passive_data.max_level:
			candidates.append({"kind": "passive_upgrade", "passive": owned_passive, "data": passive_data,
				"display_name": passive_data.display_name, "description": "패시브 레벨 상승"})
	candidates.shuffle()
	for candidate in candidates:
		if choices.size() >= amount:
			break
		choices.append(candidate)
	return choices

func apply_choice(player: Node, choice: Dictionary) -> bool:
	if not is_instance_valid(player):
		return false
	match String(choice.get("kind", "")):
		"evolution":
			var recipe := choice.get("recipe") as Resource
			return EvolutionManager.try_evolve(player, recipe)
		"weapon_new":
			return bool(player.call("add_weapon", ADVANCED_WEAPON_SCRIPT, choice.get("data")))
		"weapon_upgrade":
			var weapon := choice.get("weapon") as Weapon
			return weapon != null and weapon.upgrade()
		"passive_new", "passive_upgrade":
			if player.has_method("apply_passive_data"):
				return bool(player.call("apply_passive_data", choice.get("data")))
	return false

func _choice(kind: String, data: Resource, label: String) -> Dictionary:
	return {"kind": kind, "data": data, "label": label, "display_name": data.display_name,
		"description": data.description}

func _find_weapon(weapons: Array, id: String) -> Weapon:
	for weapon in weapons:
		if EvolutionManager.get_weapon_id(weapon) == id:
			return weapon as Weapon
	return null

func _find_passive(passives: Array, id: String) -> Object:
	for passive in passives:
		var passive_id = passive.get("id") if passive is Object else null
		if String(passive_id) == id:
			return passive as Object
	return null

func _passive_level(passive: Object) -> int:
	var value = passive.get("level")
	return maxi(1, int(value) if value != null else 1)
