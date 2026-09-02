extends Node

const ADVANCED_WEAPON_SCRIPT: Script = preload("res://scripts/weapons/AdvancedWeapon.gd")
const CATALOG: Script = preload("res://scripts/resources/advanced_weapon_catalog.gd")

func get_available_evolutions(weapons: Array, passives: Array, recipes: Array = []) -> Array[Resource]:
	var source_recipes: Array = recipes if not recipes.is_empty() else CATALOG.get_recipes()
	var result: Array[Resource] = []
	for recipe_variant in source_recipes:
		if not recipe_variant is Resource or recipe_variant.get("result_weapon_data") == null:
			continue
		var recipe: Resource = recipe_variant
		for weapon in weapons:
			if not can_evolve(weapon, passives, recipe):
				continue
			result.append(recipe)
			break
	return result

func can_evolve(weapon: Variant, passives: Array, recipe: Resource) -> bool:
	if recipe == null or recipe.get("result_weapon_data") == null:
		return false
	if get_weapon_id(weapon) != String(recipe.get("base_weapon_id")):
		return false
	if _weapon_level(weapon) != _weapon_max_level(weapon):
		return false
	for passive in passives:
		if _item_id(passive) == String(recipe.get("required_passive_id")) and _item_level(passive) >= 1:
			return true
	return false

func try_evolve(player: Node, recipe: Resource) -> bool:
	if not is_instance_valid(player) or recipe == null:
		return false
	var weapons: Array = player.get("weapons") if player.get("weapons") is Array else []
	var passives: Array = player.get("passives") if player.get("passives") is Array else []
	for weapon in weapons:
		if can_evolve(weapon, passives, recipe):
			return swap_weapon(player, weapon as Node, recipe.get("result_weapon_data") as WeaponData) != null
	return false

func swap_weapon(player: Node, old_weapon: Node, result_data: WeaponData) -> Weapon:
	if not is_instance_valid(player) or not is_instance_valid(old_weapon) or result_data == null:
		return null
	var inventory_variant = player.get("weapons")
	if not inventory_variant is Array:
		return null
	var inventory: Array = inventory_variant
	var index := inventory.find(old_weapon)
	if index < 0:
		return null
	var old_id := get_weapon_id(old_weapon)
	var replacement := ADVANCED_WEAPON_SCRIPT.new() as Weapon
	if replacement == null:
		return null
	replacement.data = result_data
	replacement.current_level = result_data.max_level
	replacement.evolved = true
	replacement.evolution_id = result_data.id
	replacement.evolution_name = result_data.get_display_name()
	player.add_child(replacement)
	inventory[index] = replacement
	old_weapon.queue_free()
	if is_instance_valid(RunStats):
		RunStats.register_evolution(old_id)
	if is_instance_valid(EventBus):
		EventBus.inventory_updated.emit(inventory, player.get("passives"))
	return replacement

func get_weapon_id(value: Variant) -> String:
	if value is Weapon:
		var weapon_data := (value as Weapon).data
		return weapon_data.get_id() if weapon_data != null else ""
	if value is WeaponData:
		return (value as WeaponData).get_id()
	return _item_id(value)

func _item_id(value: Variant) -> String:
	if value is Object:
		var raw = (value as Object).get("id")
		return String(raw) if raw != null else ""
	return ""

func _item_level(value: Variant) -> int:
	if value is Object:
		var raw = (value as Object).get("level")
		return maxi(1, int(raw) if raw != null else 1)
	return 1

func _weapon_level(value: Variant) -> int:
	if value is Weapon:
		return (value as Weapon).current_level
	if value is Object:
		var raw = (value as Object).get("current_level")
		return maxi(1, int(raw) if raw != null else 1)
	return 1

func _weapon_max_level(value: Variant) -> int:
	if value is Weapon:
		var data := (value as Weapon).data
		return data.max_level if data != null else 5
	if value is Object:
		var raw = (value as Object).get("max_level")
		return maxi(1, int(raw) if raw != null else 5)
	return 5
