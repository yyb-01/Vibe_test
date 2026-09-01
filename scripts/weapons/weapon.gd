class_name Weapon
extends Node

const MAX_LEVEL: int = 5
const EVOLUTION_CATALOG := [
	{"weapon": "Pistol", "display": "권총 (Pistol)", "id": "deadeye_revolver", "name": "데드아이 리볼버", "requirements": ["heavy_caliber", "piercing_rounds"], "description": "피해량 35% 증가, 관통 +1의 정밀 사격입니다."},
	{"weapon": "Shotgun", "display": "산탄총 (Shotgun)", "id": "breacher_cannon", "name": "브리처 캐논", "requirements": ["reinforced_vest", "field_rations"], "description": "산탄 +2, 피해량 20% 증가로 좁은 길을 뚫습니다."},
	{"weapon": "SMG", "display": "기관단총 (SMG)", "id": "overload_smg", "name": "탄막 과부하", "requirements": ["fast_hands", "scavenged_ammo"], "description": "피해량 25% 증가, 관통 +1의 탄막 무기입니다."},
	{"weapon": "Burst Rifle", "display": "점사 소총 (Burst)", "id": "triad_breaker", "name": "트라이어드 브레이커", "requirements": ["stabilizer", "executioner"], "description": "점사 +1, 피해량 15% 증가의 정밀 사격입니다."},
	{"weapon": "Railgun", "display": "레일건 (Railgun)", "id": "rail_lance", "name": "레일 랜스", "requirements": ["heavy_caliber", "hollow_point"], "description": "피해량 50% 증가, 추가 관통 +2를 얻습니다."},
	{"weapon": "Lightning", "display": "체인 라이트닝 (Lightning)", "id": "storm_runner", "name": "스톰 러너", "requirements": ["adrenaline", "momentum"], "description": "연쇄 횟수 +2, 피해량 25% 증가의 번개입니다."},
	{"weapon": "Shock Nova", "display": "충격파 발생기 (Nova)", "id": "bunker_pulse", "name": "벙커 펄스", "requirements": ["trauma_kit", "field_rations"], "description": "투사체 +4, 피해량 30% 증가, 관통 +1을 얻습니다."},
	{"weapon": "Orbital", "display": "보호막 (Orbital)", "id": "guardian_orbital", "name": "가디언 오비탈", "requirements": ["medic_kit", "reinforced_vest"], "description": "회전 반경 +30, 피해량 40% 증가의 방패입니다."}
]

@export var data: WeaponData
var current_level: int = 1

var cooldown_timer: float = 0.0
var reload_timer: float = 0.0
var ammo_in_magazine: int = 0
var evolved: bool = false
var evolution_id: String = ""
var evolution_name: String = ""

func _ready() -> void:
	if data:
		ammo_in_magazine = data.magazine_size

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta
	if reload_timer > 0:
		reload_timer -= delta
		if reload_timer <= 0 and data:
			reload_timer = 0
			ammo_in_magazine = data.magazine_size

func fire(player: Player, target_pos: Vector2) -> bool:
	if not data or cooldown_timer > 0 or reload_timer > 0:
		return false
	if data.magazine_size > 0 and ammo_in_magazine <= 0:
		reload(player)
		return false

	# Apply player modifiers
	var actual_fire_rate = data.fire_rate * player.reload_mult
	cooldown_timer = actual_fire_rate
	if data.magazine_size > 0:
		ammo_in_magazine -= 1
	player.play_weapon_feedback(data.weapon_name, target_pos)
	return true

func reload(player: Player) -> void:
	if not data or data.magazine_size <= 0 or reload_timer > 0:
		return
	if ammo_in_magazine >= data.magazine_size:
		return
	reload_timer = data.reload_time * player.reload_mult
	if reload_timer <= 0:
		ammo_in_magazine = data.magazine_size

func upgrade() -> void:
	if current_level >= MAX_LEVEL:
		return
	current_level += 1

func can_evolve(player: Player) -> bool:
	if current_level < MAX_LEVEL or evolved or not is_instance_valid(player):
		return false
	var owned_perks: Array[String] = []
	for perk in player.passives:
		owned_perks.append(perk.id)
	for perk_id in get_evolution_requirements():
		if perk_id not in owned_perks:
			return false
	return true

func evolve(player: Player) -> bool:
	if not can_evolve(player):
		return false
	evolved = true
	evolution_id = _get_evolution_id()
	evolution_name = _get_evolution_name()
	return true

func get_display_name() -> String:
	if evolved:
		return evolution_name + " ★"
	return String(_get_evolution().get("display", data.weapon_name))

func get_evolution_description() -> String:
	return String(_get_evolution().get("description", "무기의 공격 방식과 피해량이 크게 강화됩니다."))

func get_evolution_requirements() -> Array[String]:
	var requirements: Array[String] = []
	requirements.assign(_get_evolution().get("requirements", []))
	return requirements

func get_evolution_requirement_text() -> String:
	var labels: Array[String] = []
	for perk_id in get_evolution_requirements():
		labels.append(get_perk_label(perk_id))
	return " + ".join(labels)

static func get_perk_label(perk_id: String) -> String:
	match perk_id:
		"heavy_caliber": return "대구경 탄환"
		"piercing_rounds": return "철갑탄"
		"reinforced_vest": return "복합 장갑"
		"field_rations": return "야전 식량"
		"fast_hands": return "빠른 손놀림"
		"scavenged_ammo": return "회수 탄약"
		"stabilizer": return "반동 제어기"
		"executioner": return "처형 프로토콜"
		"hollow_point": return "할로우 포인트"
		"adrenaline": return "아드레날린"
		"momentum": return "가속 전술"
		"trauma_kit": return "외상 키트"
		"medic_kit": return "응급 키트"
		_: return perk_id

func _get_evolution_id() -> String:
	return String(_get_evolution().get("id", "unknown_evolution"))

func _get_evolution_name() -> String:
	return String(_get_evolution().get("name", data.weapon_name if data else "알 수 없음"))

func _get_evolution() -> Dictionary:
	if data:
		for entry in EVOLUTION_CATALOG:
			if String(entry["weapon"]) == data.weapon_name:
				return entry
	return {}

static func get_evolution_catalog() -> Array:
	return EVOLUTION_CATALOG.duplicate(true)
