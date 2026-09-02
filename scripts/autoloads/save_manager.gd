extends Node

const SAVE_PATH = "user://save_data.cfg"
const DEFAULT_PETS: Array[String] = ["rescue_hound", "toxic_crow", "lab_drone"]
const VALID_CHARACTERS: Array[String] = ["scavenger", "medic", "ranger", "bulwark", "pyro", "engineer", "reaper", "chronomancer"]
const VALID_DIFFICULTIES: Array[String] = ["easy", "normal", "hard", "nightmare"]
const VALID_CHALLENGES: Array[String] = ["none", "untouchable", "elite_hunter", "mission_master", "endless_15"]
const VALID_COMPLETED_CHALLENGES: Array[String] = ["untouchable", "elite_hunter", "mission_master", "endless_15"]

var gold: int = 0

const UPGRADE_DEFINITIONS := {
	"max_hp": {"category": "survival", "name": "강화 장갑", "max": 5, "base_cost": 100, "effect": "최대 체력 +15", "description": "기본 생존 체력 증가"},
	"health_regen": {"category": "survival", "name": "나노 재생기", "max": 3, "base_cost": 200, "effect": "5초당 체력 +1", "description": "초반 유지력 제공"},
	"i_frames": {"category": "survival", "name": "비상 회피막", "max": 3, "base_cost": 150, "effect": "피격 무적 +0.05초", "description": "다단히트 즉사 방지"},
	"revive": {"category": "survival", "name": "최후의 심폐소생", "max": 1, "base_cost": 1000, "effect": "런당 1회 부활", "description": "HP 30% 부활 + 충격파"},
	"damage": {"category": "combat", "name": "고화력 화약", "max": 5, "base_cost": 100, "effect": "모든 피해 +6%", "description": "기본 피해량 증가"},
	"crit_chance": {"category": "combat", "name": "정밀 조준경", "max": 5, "base_cost": 150, "effect": "치명타 확률 +3%", "description": "치명타 빌드 기반"},
	"crit_damage": {"category": "combat", "name": "대구경 탄두", "max": 3, "base_cost": 200, "effect": "치명타 피해 +15%", "description": "치명타 폭딜 강화"},
	"fire_rate": {"category": "combat", "name": "급탄 모듈", "max": 4, "base_cost": 150, "effect": "공격/재장전 +4%", "description": "DPS 및 연사 강화"},
	"piercing": {"category": "combat", "name": "철갑탄", "max": 1, "base_cost": 800, "effect": "기본 관통 +1", "description": "웨이브 돌파력 강화"},
	"speed": {"category": "utility", "name": "경량화 부츠", "max": 5, "base_cost": 100, "effect": "이동 속도 +4%", "description": "카이팅 능력 강화"},
	"dash_cooldown": {"category": "utility", "name": "오버클럭 슬라이드", "max": 3, "base_cost": 150, "effect": "대시 쿨타임 -8%", "description": "기동 및 탈출 주기 단축"},
	"magnet_radius": {"category": "utility", "name": "자력 코일", "max": 5, "base_cost": 100, "effect": "흡수 반경 +20%", "description": "파밍 편의성 강화"},
	"exp_gain": {"category": "utility", "name": "데이터 분석기", "max": 4, "base_cost": 150, "effect": "경험치 +5%", "description": "레벨업 가속"},
	"start_gold": {"category": "economy", "name": "긴급 지원금", "max": 5, "base_cost": 80, "effect": "시작 스크랩 +40", "description": "초반 상점 자금 확보"},
	"shop_discount": {"category": "economy", "name": "암시장 할인", "max": 3, "base_cost": 150, "effect": "상점 가격 -6%", "description": "구매 효율 강화"},
	"reroll_count": {"category": "economy", "name": "작전 재검토", "max": 3, "base_cost": 250, "effect": "무료 리롤 +1", "description": "빌드 완성도 향상"},
	"banish_count": {"category": "economy", "name": "불량품 폐기", "max": 2, "base_cost": 350, "effect": "카드 제외 +1", "description": "덱 압축 및 진화 지원"},
	"start_passive": {"category": "economy", "name": "조달 패키지", "max": 1, "base_cost": 1200, "effect": "무작위 패시브 +1", "description": "런 시작 변수 창출"}
}
var upgrades: Dictionary = {}

# Permanent Upgrade Levels
var upgrade_max_hp: int = 0
var upgrade_speed: int = 0
var upgrade_damage: int = 0
var total_runs: int = 0
var best_time: float = 0.0
var highest_wave: int = 0
var pet_blueprints: Array[String] = ["rescue_hound", "toxic_crow", "lab_drone"]
var selected_pet: String = ""
var selected_character: String = "scavenger"
var selected_difficulty: String = "normal"
var endless_mode: bool = false
var selected_challenge: String = "none"
var completed_challenges: Array[String] = []
var screen_shake_enabled: bool = true
var master_volume: float = 0.8
var ui_scale: float = 1.0
var weapon_stats: Dictionary = {}

func _ready() -> void:
	for upgrade_id in UPGRADE_DEFINITIONS:
		upgrades[upgrade_id] = 0
	load_data()
	apply_ui_scale()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Flush the latest gold and permanent upgrades before the executable closes.
		save_data()
		get_tree().quit()

func _safe_int(value, default_value: int, min_value: int, max_value: int) -> int:
	if value is int or value is float:
		return clampi(int(value), min_value, max_value)
	return default_value

func _safe_float(value, default_value: float, min_value: float, max_value: float) -> float:
	if value is int or value is float:
		return clampf(float(value), min_value, max_value)
	return default_value

func _read_int(config: ConfigFile, section: String, key: String, default_value: int, min_value: int, max_value: int) -> int:
	return _safe_int(config.get_value(section, key, default_value), default_value, min_value, max_value)

func _read_float(config: ConfigFile, section: String, key: String, default_value: float, min_value: float, max_value: float) -> float:
	return _safe_float(config.get_value(section, key, default_value), default_value, min_value, max_value)

func _read_bool(config: ConfigFile, section: String, key: String, default_value: bool) -> bool:
	var value = config.get_value(section, key, default_value)
	return value if value is bool else default_value

func _read_allowed_string(config: ConfigFile, section: String, key: String, default_value: String, allowed: Array[String]) -> String:
	var value = config.get_value(section, key, default_value)
	return value if value is String and value in allowed else default_value

func _read_string_array(value, allowed: Array[String] = []) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item in value:
		if item is String and (allowed.is_empty() or item in allowed) and item not in result:
			result.append(item)
	return result

func _sanitize_weapon_stats(value) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	for weapon_id in value:
		if not weapon_id is String or not value[weapon_id] is Dictionary:
			continue
		var raw_stats: Dictionary = value[weapon_id]
		result[weapon_id] = {
			"damage": _safe_int(raw_stats.get("damage", 0), 0, 0, 2147483647),
			"runs": _safe_int(raw_stats.get("runs", 0), 0, 0, 2147483647),
			"evolutions": _safe_int(raw_stats.get("evolutions", 0), 0, 0, 2147483647)
		}
	return result

func _sync_legacy_upgrades() -> void:
	upgrade_max_hp = get_upgrade_level("max_hp")
	upgrade_speed = get_upgrade_level("speed")
	upgrade_damage = get_upgrade_level("damage")

func save_data() -> void:
	_sync_legacy_upgrades()
	gold = maxi(0, gold)
	var config = ConfigFile.new()
	config.set_value("Meta", "gold", gold)
	config.set_value("Upgrades", "max_hp", upgrade_max_hp)
	config.set_value("Upgrades", "speed", upgrade_speed)
	config.set_value("Upgrades", "damage", upgrade_damage)
	config.set_value("Upgrades", "levels", upgrades)
	config.set_value("Progress", "total_runs", total_runs)
	config.set_value("Progress", "best_time", best_time)
	config.set_value("Progress", "highest_wave", highest_wave)
	config.set_value("Progress", "pet_blueprints", pet_blueprints)
	config.set_value("Progress", "selected_pet", selected_pet)
	config.set_value("Settings", "screen_shake_enabled", screen_shake_enabled)
	config.set_value("Settings", "selected_character", selected_character)
	config.set_value("Settings", "selected_difficulty", selected_difficulty)
	config.set_value("Settings", "endless_mode", endless_mode)
	config.set_value("Settings", "selected_challenge", selected_challenge)
	config.set_value("Progress", "completed_challenges", completed_challenges)
	config.set_value("Settings", "master_volume", master_volume)
	config.set_value("Settings", "ui_scale", ui_scale)
	config.set_value("Statistics", "weapons", weapon_stats)
	var error: Error = config.save(SAVE_PATH)
	if error != OK:
		push_error("SaveManager: Failed to save data: %s" % error)

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return # Safe fallback to default values

	var config = ConfigFile.new()
	var error: Error = config.load(SAVE_PATH)
	if error != OK:
		push_error("SaveManager: Failed to load data: %s" % error)
		return

	gold = _read_int(config, "Meta", "gold", 0, 0, 2147483647)
	upgrade_max_hp = _read_int(config, "Upgrades", "max_hp", 0, 0, 5)
	upgrade_speed = _read_int(config, "Upgrades", "speed", 0, 0, 5)
	upgrade_damage = _read_int(config, "Upgrades", "damage", 0, 0, 5)
	var saved_upgrades = config.get_value("Upgrades", "levels", {})
	if saved_upgrades is Dictionary and not saved_upgrades.is_empty():
		for upgrade_id in UPGRADE_DEFINITIONS:
			var definition: Dictionary = UPGRADE_DEFINITIONS[upgrade_id]
			upgrades[upgrade_id] = _safe_int(saved_upgrades.get(upgrade_id, 0), 0, 0, int(definition.get("max", 0)))
	else:
		upgrades["max_hp"] = upgrade_max_hp
		upgrades["speed"] = upgrade_speed
		upgrades["damage"] = upgrade_damage
	_sync_legacy_upgrades()
	total_runs = _read_int(config, "Progress", "total_runs", 0, 0, 2147483647)
	best_time = _read_float(config, "Progress", "best_time", 0.0, 0.0, 1.0e9)
	highest_wave = _read_int(config, "Progress", "highest_wave", 0, 0, 2147483647)
	pet_blueprints = _read_string_array(config.get_value("Progress", "pet_blueprints", DEFAULT_PETS), DEFAULT_PETS)
	for default_pet in DEFAULT_PETS:
		if default_pet not in pet_blueprints:
			pet_blueprints.append(default_pet)
	var saved_pet = config.get_value("Progress", "selected_pet", "")
	selected_pet = saved_pet if saved_pet is String and saved_pet in pet_blueprints else ""
	screen_shake_enabled = _read_bool(config, "Settings", "screen_shake_enabled", true)
	selected_character = _read_allowed_string(config, "Settings", "selected_character", "scavenger", VALID_CHARACTERS)
	selected_difficulty = _read_allowed_string(config, "Settings", "selected_difficulty", "normal", VALID_DIFFICULTIES)
	endless_mode = _read_bool(config, "Settings", "endless_mode", false)
	selected_challenge = _read_allowed_string(config, "Settings", "selected_challenge", "none", VALID_CHALLENGES)
	completed_challenges = _read_string_array(config.get_value("Progress", "completed_challenges", []), VALID_COMPLETED_CHALLENGES)
	master_volume = _read_float(config, "Settings", "master_volume", 0.8, 0.0, 1.0)
	ui_scale = _read_float(config, "Settings", "ui_scale", 1.0, 0.8, 1.25)
	weapon_stats = _sanitize_weapon_stats(config.get_value("Statistics", "weapons", {}))

func apply_ui_scale() -> void:
	ui_scale = clampf(ui_scale, 0.8, 1.25)
	ThemeDB.fallback_base_scale = ui_scale

func record_run(summary: Dictionary) -> void:
	total_runs += 1
	highest_wave = maxi(highest_wave, _safe_int(summary.get("wave", 1), 1, 1, 2147483647))
	var run_time := _safe_float(summary.get("time", 0.0), 0.0, 0.0, 1.0e9)
	if run_time > best_time:
		best_time = run_time
	var used_weapons = summary.get("used_weapons", [])
	var weapon_damage = summary.get("weapon_damage", {})
	var evolved_weapons = summary.get("evolved_weapons", [])
	if used_weapons is Array and weapon_damage is Dictionary and evolved_weapons is Array:
		for weapon_id in used_weapons:
			if not weapon_id is String or weapon_id.is_empty():
				continue
			var stats_value = weapon_stats.get(weapon_id, {})
			var stats: Dictionary = stats_value if stats_value is Dictionary else {}
			stats["runs"] = _safe_int(stats.get("runs", 0), 0, 0, 2147483647) + 1
			stats["damage"] = _safe_int(stats.get("damage", 0), 0, 0, 2147483647) + _safe_int(weapon_damage.get(weapon_id, 0), 0, 0, 2147483647)
			if weapon_id in evolved_weapons:
				stats["evolutions"] = _safe_int(stats.get("evolutions", 0), 0, 0, 2147483647) + 1
			weapon_stats[weapon_id] = stats
	save_data()

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	EventBus.gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if amount <= 0 or gold < amount:
		return false
	gold -= amount
	EventBus.gold_changed.emit(gold)
	return true

func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))

func get_upgrade_cost(upgrade_id: String) -> int:
	var definition: Dictionary = UPGRADE_DEFINITIONS.get(upgrade_id, {})
	return int(definition.get("base_cost", 0)) * (get_upgrade_level(upgrade_id) + 1)

func buy_upgrade(upgrade_id: String) -> bool:
	if not UPGRADE_DEFINITIONS.has(upgrade_id):
		return false
	var definition: Dictionary = UPGRADE_DEFINITIONS[upgrade_id]
	var level := get_upgrade_level(upgrade_id)
	if level >= int(definition.max) or not spend_gold(get_upgrade_cost(upgrade_id)):
		return false
	upgrades[upgrade_id] = level + 1
	save_data()
	return true

func reset_all_upgrades() -> int:
	var refund := 0
	for upgrade_id in upgrades:
		var base_cost := int(UPGRADE_DEFINITIONS[upgrade_id].base_cost)
		for level in range(int(upgrades[upgrade_id])):
			refund += base_cost * (level + 1)
		upgrades[upgrade_id] = 0
	add_gold(refund)
	save_data()
	return refund

func get_upgrade_progress() -> float:
	var bought := 0
	var maximum := 0
	for upgrade_id in UPGRADE_DEFINITIONS:
		bought += get_upgrade_level(upgrade_id)
		maximum += int(UPGRADE_DEFINITIONS[upgrade_id].max)
	return float(bought) / float(maxi(1, maximum))

func unlock_pet_blueprint(blueprint_id: String) -> void:
	if blueprint_id not in DEFAULT_PETS or blueprint_id in pet_blueprints:
		return
	pet_blueprints.append(blueprint_id)
	save_data()

func complete_challenge(challenge_id: String, reward: int) -> bool:
	if challenge_id not in VALID_COMPLETED_CHALLENGES or reward <= 0 or challenge_id in completed_challenges:
		return false
	completed_challenges.append(challenge_id)
	add_gold(reward)
	save_data()
	return true
