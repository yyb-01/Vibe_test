class_name AdvancedWeaponCatalog
extends RefCounted

const PASSIVE_DATA_SCRIPT: Script = preload("res://scripts/resources/passive_data.gd")
const EVOLUTION_RECIPE_SCRIPT: Script = preload("res://scripts/resources/evolution_recipe.gd")

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

static func _weapon(id: String, title: String, text: String, scene: PackedScene,
		damage_value: float, shot_cooldown: float, count: int, pierce_count: int,
		projectile_speed_value: float, spread: float, radius_scale: float,
		knockback_force: float, evolution: bool = false) -> WeaponData:
	var data := WeaponData.new()
	data.id = id
	data.display_name = title
	data.weapon_name = title
	data.description = text
	data.max_level = 5
	data.damage = damage_value
	data.cooldown = shot_cooldown
	data.fire_rate = shot_cooldown
	data.projectile_count = count
	data.pierce = pierce_count
	data.speed = projectile_speed_value
	data.projectile_speed = projectile_speed_value
	data.spread_angle = spread
	data.area_scale = radius_scale
	data.knockback = knockback_force
	data.projectile_scene = scene
	data.magazine_size = 0
	data.reload_time = 0.0
	data.is_evolution = evolution
	return data

static func get_weapons() -> Array[WeaponData]:
	return [
		_weapon("pistol", "권총", "빠르고 정확한 단발 탄환.", PISTOL, 18.0, 0.24, 1, 0, 900.0, 0.0, 1.0, 20.0),
		_weapon("dual_beretta", "듀얼 베레타", "좌우 총구를 번갈아 쓰는 고속 연사.", DUAL, 14.0, 0.18, 1, 0, 980.0, 0.0, 1.0, 18.0, true),
		_weapon("shotgun", "산탄총", "강한 넉백의 부채꼴 산탄.", SHOTGUN, 12.0, 0.72, 7, 0, 720.0, 34.0, 1.0, 180.0),
		_weapon("dragons_breath", "드래곤 브레스", "모든 적을 관통하고 화염 장판을 남긴다.", DRAGON, 16.0, 0.68, 9, 999999, 650.0, 58.0, 1.15, 100.0, true),
		_weapon("heavy_revolver", "헤비 리볼버", "고속·고관통 중화기 탄환.", REVOLVER, 42.0, 0.9, 1, 3, 1250.0, 0.0, 1.0, 60.0),
		_weapon("magnum_opus", "매그넘 오퍼스", "치명타가 8방향 파편으로 분열된다.", MAGNUM, 58.0, 1.05, 1, 4, 1180.0, 0.0, 1.0, 80.0, true),
		_weapon("flamethrower", "화염방사기", "짧은 사거리의 성장형 화염 부채.", FLAME, 9.0, 0.12, 1, 999, 340.0, 42.0, 1.0, 0.0),
		_weapon("infernal_sonata", "지옥불 소나타", "푸른 불꽃이 사망 시 주변을 폭발시킨다.", INFERNAL, 13.0, 0.12, 1, 999, 360.0, 48.0, 1.2, 0.0, true),
		_weapon("rpg", "로켓 런처", "첫 충돌에서 멈추는 광역 폭발 로켓.", ROCKET, 80.0, 1.35, 1, 0, 570.0, 0.0, 1.25, 260.0),
		_weapon("cluster_nebula", "클러스터 네뷸라", "주 폭발 뒤 6개의 지연 자탄을 흩뿌린다.", CLUSTER, 92.0, 1.5, 1, 0, 540.0, 0.0, 1.35, 230.0, true),
		_weapon("tesla_cannon", "테슬라 건", "가까운 적 둘에게 연쇄 방전한다.", TESLA, 46.0, 0.8, 1, 2, 1100.0, 0.0, 1.0, 40.0),
		_weapon("thors_smite", "토르의 벼락", "화면 내 최대 5체를 무작위로 벼락 처형한다.", THOR, 74.0, 2.2, 5, 0, 0.0, 0.0, 1.0, 120.0, true)
	] as Array[WeaponData]

static func get_passives() -> Array[Resource]:
	var result: Array[Resource] = []
	result.append(_passive("quick_hands", "빠른 손", "fire_rate", 0.08))
	result.append(_passive("oil_reservoir", "연료 탱크", "area", 0.12))
	result.append(_passive("crit_core", "크리티컬 코어", "crit_chance", 0.08))
	result.append(_passive("blue_catalyst", "청염 촉매", "fire_damage", 0.12))
	result.append(_passive("fragmentation", "분열 장약", "fire_damage", 0.1))
	result.append(_passive("storm_core", "폭풍 코어", "cooldown", 0.08))
	return result

static func _passive(id: String, title: String, stat: String, value: float) -> Resource:
	var data: Resource = PASSIVE_DATA_SCRIPT.new()
	data.set("id", id)
	data.set("display_name", title)
	data.set("description", "%s +%.0f%% / 레벨" % [stat, value * 100.0])
	data.set("stat_type", stat)
	data.set("value_per_level", value)
	data.set("max_level", 5)
	return data

static func get_recipes() -> Array[Resource]:
	var weapons := get_weapons()
	var result: Array[Resource] = []
	result.append(_recipe("pistol", "quick_hands", _find(weapons, "dual_beretta")))
	result.append(_recipe("shotgun", "oil_reservoir", _find(weapons, "dragons_breath")))
	result.append(_recipe("heavy_revolver", "crit_core", _find(weapons, "magnum_opus")))
	result.append(_recipe("flamethrower", "blue_catalyst", _find(weapons, "infernal_sonata")))
	result.append(_recipe("rpg", "fragmentation", _find(weapons, "cluster_nebula")))
	result.append(_recipe("tesla_cannon", "storm_core", _find(weapons, "thors_smite")))
	return result

static func _find(weapons: Array[WeaponData], id: String) -> WeaponData:
	for weapon in weapons:
		if weapon.id == id:
			return weapon
	return null

static func _recipe(base_id: String, passive_id: String, result_data: WeaponData) -> Resource:
	var recipe: Resource = EVOLUTION_RECIPE_SCRIPT.new()
	recipe.set("base_weapon_id", base_id)
	recipe.set("required_passive_id", passive_id)
	recipe.set("result_weapon_data", result_data)
	return recipe
