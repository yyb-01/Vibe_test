class_name Weapon
extends Node

const MAX_LEVEL: int = 5

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
	player.trigger_weapon_recoil()
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

func can_evolve() -> bool:
	return current_level >= MAX_LEVEL and not evolved

func evolve() -> bool:
	if not can_evolve():
		return false
	evolved = true
	evolution_id = _get_evolution_id()
	evolution_name = _get_evolution_name()
	return true

func get_display_name() -> String:
	if evolved:
		return evolution_name + " ★"
	return data.weapon_name

func get_evolution_description() -> String:
	match _get_evolution_id():
		"deadeye_revolver": return "장거리 치명타와 관통탄으로 단일 대상을 제압합니다."
		"breacher_cannon": return "관통 산탄과 넉백으로 좁은 길을 뚫습니다."
		"overload_smg": return "연속 처치가 탄창과 연사력을 되돌리는 탄막 무기입니다."
		"triad_breaker": return "점사의 마지막 탄환이 강화되어 정밀 사격 보상이 커집니다."
		"rail_lance": return "관통할수록 강해지고 마지막 적에게 전기 충격을 줍니다."
		"storm_runner": return "이동하며 충전한 번개가 더 많은 적에게 연쇄됩니다."
		"bunker_pulse": return "포위될수록 커지는 충격파와 보호막을 생성합니다."
		"guardian_orbital": return "회전 방패가 투사체를 튕겨내고 주기적으로 보호합니다."
		_: return "무기의 공격 방식과 피해량이 크게 강화됩니다."

func _get_evolution_id() -> String:
	if not data:
		return "unknown_evolution"
	match data.weapon_name:
		"권총 (Pistol)": return "deadeye_revolver"
		"산탄총 (Shotgun)": return "breacher_cannon"
		"기관단총 (SMG)": return "overload_smg"
		"점사 소총 (Burst)": return "triad_breaker"
		"레일건 (Railgun)": return "rail_lance"
		"체인 라이트닝 (Lightning)": return "storm_runner"
		"충격파 발생기 (Nova)": return "bunker_pulse"
		"보호막 (Orbital)": return "guardian_orbital"
		_: return data.weapon_name + "_evolution"

func _get_evolution_name() -> String:
	match _get_evolution_id():
		"deadeye_revolver": return "데드아이 리볼버"
		"breacher_cannon": return "브리처 캐논"
		"overload_smg": return "탄막 과부하"
		"triad_breaker": return "트라이어드 브레이커"
		"rail_lance": return "레일 랜스"
		"storm_runner": return "스톰 러너"
		"bunker_pulse": return "벙커 펄스"
		"guardian_orbital": return "가디언 오비탈"
		_: return data.weapon_name
