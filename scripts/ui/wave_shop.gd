class_name WaveShop
extends CanvasLayer

const PASSIVES: Array[PerkData] = [
	preload("res://data/perks/fast_hands.tres"),
	preload("res://data/perks/hollow_point.tres"),
	preload("res://data/perks/light_foot.tres"),
	preload("res://data/perks/piercing_rounds.tres"),
	preload("res://data/perks/heavy_caliber.tres"),
	preload("res://data/perks/medic_kit.tres"),
	preload("res://data/perks/adrenaline.tres"),
	preload("res://data/perks/scavenged_ammo.tres"),
	preload("res://data/perks/bloodlust.tres"),
	preload("res://data/perks/reinforced_vest.tres"),
	preload("res://data/perks/stabilizer.tres"),
	preload("res://data/perks/field_rations.tres"),
	preload("res://data/perks/momentum.tres"),
	preload("res://data/perks/executioner.tres"),
	preload("res://data/perks/trauma_kit.tres")
]

const WEAPON_PATHS = [
	"res://data/perks/weap_pistol.tres",
	"res://data/perks/weap_shotgun.tres",
	"res://data/perks/weap_orbital.tres",
	"res://data/perks/weap_lightning.tres",
	"res://data/perks/weap_smg.tres",
	"res://data/perks/weap_burst.tres",
	"res://data/perks/weap_railgun.tres",
	"res://data/perks/weap_nova.tres"
]

const OFFER_COUNT := 5
const BASE_REROLL_COST := 8

var offers: Array[Dictionary] = []
var current_wave := 1
var reroll_cost := BASE_REROLL_COST

var overlay: ColorRect
var title_label: Label
var scrap_label: Label
var offer_row: HBoxContainer
var reroll_button: Button
var leave_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_interface()
	EventBus.wave_shop_requested.connect(open_shop)
	get_viewport().size_changed.connect(_on_viewport_resized)

func open_shop(wave: int) -> void:
	if visible:
		return
	ModalManager.request(self, _open_shop.bind(wave))

func _open_shop(wave: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if not RunStats.run_active or not is_instance_valid(player) or player.dead or player.health <= 0:
		ModalManager.release(self)
		return
	current_wave = wave
	reroll_cost = BASE_REROLL_COST
	offers.clear()
	_roll_offers(player)
	for index in offers.size():
		offers[index] = _apply_discount(offers[index])
	visible = true
	_render()

func _build_interface() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.004, 0.012, 0.018, 0.9)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.02
	panel.anchor_top = 0.04
	panel.anchor_right = 0.98
	panel.anchor_bottom = 0.96
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.92, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)

	scrap_label = Label.new()
	scrap_label.add_theme_font_size_override("font_size", 18)
	scrap_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 1.0))
	scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(scrap_label)

	offer_row = HBoxContainer.new()
	offer_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	offer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	offer_row.add_theme_constant_override("separation", 10)
	content.add_child(offer_row)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	content.add_child(actions)

	reroll_button = _make_action_button("진열 새로고침", Color(0.18, 0.58, 0.7, 1.0))
	reroll_button.pressed.connect(_reroll)
	actions.add_child(reroll_button)

	leave_button = _make_action_button("다음 웨이브 시작", Color(0.28, 0.72, 0.46, 1.0))
	leave_button.pressed.connect(_close_shop)
	actions.add_child(leave_button)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.048, 0.06, 0.99)
	style.border_color = Color(0.2, 0.78, 0.72, 0.82)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	return style

func _make_action_button(button_text: String, color: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(250, 52)
	button.text = button_text
	button.add_theme_font_size_override("font_size", 19)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color, 0.26)
	normal.border_color = color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(7)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(color, 0.48)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	return button

func _roll_offers(player: Player) -> void:
	var used_ids: Array[String] = []
	while offers.size() < OFFER_COUNT:
		var offer := _make_unique_offer(player, used_ids)
		if offer.is_empty():
			break
		offers.append(offer)
		used_ids.append(String(offer.get("id", "supply_%d" % offers.size())))

func _make_unique_offer(player: Player, used_ids: Array[String]) -> Dictionary:
	for _attempt in range(20):
		var offer := _make_offer(player, used_ids)
		if not offer.is_empty():
			var offer_id := String(offer.get("id", ""))
			if not offer_id.is_empty() and offer_id not in used_ids and offer_id not in RunStats.banished_ids:
				return offer
	return {}

func _make_offer(player: Player, used_ids: Array[String]) -> Dictionary:
	var evolution_candidates: Array[Weapon] = []
	for weapon in player.weapons:
		if weapon.can_evolve(player):
			evolution_candidates.append(weapon)
	if current_wave >= 3 and not evolution_candidates.is_empty() and randf() < 0.2:
		var evolution_weapon: Weapon = evolution_candidates.pick_random()
		var evolution_id := "evolution_" + evolution_weapon.data.weapon_name
		if evolution_id not in used_ids and evolution_id not in RunStats.banished_ids:
			return {"kind": "evolution", "id": evolution_id, "item": evolution_weapon, "cost": 52, "locked": false}

	var roll := randf()
	if current_wave >= 2 and roll < 0.18:
		return _make_contract_offer(used_ids)
	if roll < 0.34:
		return _make_supply_offer(used_ids)
	if roll < 0.70:
		var passive_offer := _make_passive_offer(player, used_ids)
		if not passive_offer.is_empty():
			return passive_offer
	return _make_weapon_offer(player, used_ids)

func _make_contract_offer(used_ids: Array[String]) -> Dictionary:
	var contracts := [
		{"kind": "contract", "id": "volatile_ammo", "name": "불안정 탄약 계약", "description": "모든 피해 +22%\n대신 받는 피해 +18%", "cost": 18},
		{"kind": "contract", "id": "scavenger_route", "name": "회수꾼 경로", "description": "스크랩 획득량 +45%\n대신 최대 체력 -15", "cost": 16},
		{"kind": "contract", "id": "last_stand", "name": "최후의 저항", "description": "최대 체력 -25\n모든 피해 +35%, 이동 속도 +12%", "cost": 24}
	]
	var candidates: Array[Dictionary] = []
	for contract in contracts:
		if String(contract.id) not in used_ids and String(contract.id) not in RunStats.banished_ids:
			contract["locked"] = false
			candidates.append(contract)
	return _make_supply_offer(used_ids) if candidates.is_empty() else candidates.pick_random()

func _make_passive_offer(player: Player, used_ids: Array[String]) -> Dictionary:
	if player.passives.size() >= player.max_passives:
		return {}
	var owned_ids: Array[String] = []
	for passive in player.passives:
		owned_ids.append(passive.id)
	var candidates: Array[PerkData] = []
	for passive in PASSIVES:
		if passive.id not in owned_ids and passive.id not in used_ids and passive.id not in RunStats.banished_ids:
			candidates.append(passive)
	if candidates.is_empty():
		return {}
	var picked: PerkData = candidates.pick_random()
	return {"kind": "passive", "id": picked.id, "item": picked, "cost": 28, "locked": false}

func _make_weapon_offer(player: Player, used_ids: Array[String]) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for weapon in player.weapons:
		var upgrade_id := "upgrade_" + weapon.data.weapon_name
		if weapon.current_level < Weapon.MAX_LEVEL and upgrade_id not in used_ids and upgrade_id not in RunStats.banished_ids:
			candidates.append({"kind": "weapon_upgrade", "id": upgrade_id, "item": weapon, "cost": 22, "locked": false})
	if player.weapons.size() < player.max_weapons:
		for weapon_path in WEAPON_PATHS:
			var weapon_data: WeaponUpgradeData = load(weapon_path) as WeaponUpgradeData
			if not is_instance_valid(weapon_data) or not is_instance_valid(weapon_data.weapon_data) or weapon_data.weapon_script == null:
				continue
			var has_weapon := false
			for owned_weapon in player.weapons:
				if owned_weapon.data.weapon_name == weapon_data.weapon_data.weapon_name:
					has_weapon = true
					break
			if not has_weapon and weapon_data.weapon_id not in used_ids and weapon_data.weapon_id not in RunStats.banished_ids:
				candidates.append({"kind": "weapon_new", "id": weapon_data.weapon_id, "item": weapon_data, "cost": 34, "locked": false})
	if candidates.is_empty():
		return _make_supply_offer(used_ids)
	return candidates.pick_random()

func _make_supply_offer(used_ids: Array[String]) -> Dictionary:
	var supplies := [
		{"kind": "repair", "id": "repair", "name": "응급 수리", "description": "체력을 35 회복합니다.", "cost": 14},
		{"kind": "plating", "id": "plating", "name": "세라믹 플레이트", "description": "최대 체력 +20, 즉시 회복 +20", "cost": 24},
		{"kind": "amplifier", "id": "amplifier", "name": "화력 증폭기", "description": "모든 피해량 +10%", "cost": 26},
		{"kind": "boots", "id": "boots", "name": "전술 부츠", "description": "이동 속도 +8%", "cost": 20}
	]
	var candidates: Array[Dictionary] = []
	for supply in supplies:
		if String(supply.id) not in used_ids and String(supply.id) not in RunStats.banished_ids:
			supply["locked"] = false
			candidates.append(supply)
	if candidates.is_empty():
		for supply in supplies:
			if String(supply.id) not in RunStats.banished_ids:
				var fallback: Dictionary = supply.duplicate()
				var fallback_index := used_ids.size()
				var fallback_id := "supply_fallback_%d" % fallback_index
				while fallback_id in used_ids or fallback_id in RunStats.banished_ids:
					fallback_index += 1
					fallback_id = "supply_fallback_%d" % fallback_index
				fallback["id"] = fallback_id
				fallback["locked"] = false
				return fallback
		return {}
	return candidates.pick_random()

func _render() -> void:
	title_label.text = "파동 %02d 종료  ·  야전 상점" % current_wave
	scrap_label.text = "보유 스크랩  %d   ·   처치 보상과 웨이브 보너스로 획득" % RunStats.scrap
	reroll_button.text = "무료 진열 새로고침  ·  %d회" % RunStats.rerolls_remaining if RunStats.rerolls_remaining > 0 else "진열 새로고침  ·  %d 스크랩" % reroll_cost
	reroll_button.disabled = RunStats.rerolls_remaining <= 0 and RunStats.scrap < reroll_cost
	for child in offer_row.get_children():
		child.free()
	for index in offers.size():
		offer_row.add_child(_create_offer_card(index, offers[index]))

func _create_offer_card(index: int, offer: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var compact := get_viewport().get_visible_rect().size.y < 650.0
	card.custom_minimum_size = Vector2(0.0, 300.0 if compact else 390.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var accent := _offer_color(String(offer.kind))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.07, 0.08, 0.98)
	normal.border_color = Color(accent, 0.8)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(10.0)
	card.add_theme_stylebox_override("panel", normal)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	card.add_child(content)

	var tools := HBoxContainer.new()
	var shortcut := Label.new()
	shortcut.text = "[%d]" % (index + 1)
	shortcut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcut.add_theme_color_override("font_color", accent)
	tools.add_child(shortcut)
	var lock_button := Button.new()
	lock_button.custom_minimum_size = Vector2(34, 30)
	lock_button.text = "🔓" if bool(offer.get("locked", false)) else "🔒"
	lock_button.tooltip_text = "잠금: 새로고침 때 이 카드를 유지"
	lock_button.disabled = bool(offer.get("purchased", false))
	lock_button.pressed.connect(func() -> void: _toggle_lock(index))
	tools.add_child(lock_button)
	if RunStats.banishes_remaining > 0 and not bool(offer.get("purchased", false)):
		var banish_button := Button.new()
		banish_button.custom_minimum_size = Vector2(34, 30)
		banish_button.text = "🗑"
		banish_button.tooltip_text = "이번 런에서 폐기 · %d회 남음" % RunStats.banishes_remaining
		banish_button.pressed.connect(func() -> void: _banish_offer(index))
		tools.add_child(banish_button)
	content.add_child(tools)

	var kind_label := Label.new()
	kind_label.text = _offer_kind_label(String(offer.kind))
	kind_label.add_theme_font_size_override("font_size", 14)
	kind_label.add_theme_color_override("font_color", accent)
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(kind_label)
	var visual := Label.new()
	visual.text = _offer_icon(String(offer.kind))
	visual.custom_minimum_size = Vector2(0, 58.0 if compact else 72.0)
	visual.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visual.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visual.add_theme_font_size_override("font_size", 42)
	visual.add_theme_color_override("font_color", accent)
	content.add_child(visual)

	var name_label := Label.new()
	name_label.text = _offer_name(offer)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 38.0 if compact else 46.0)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.98, 0.96, 1.0))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(name_label)

	var description_label := Label.new()
	description_label.text = _offer_description(offer)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(0, 64.0 if compact else 105.0)
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.add_theme_font_size_override("font_size", 14)
	description_label.add_theme_color_override("font_color", Color(0.72, 0.86, 0.84, 1.0))
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	content.add_child(description_label)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(0, 42.0 if compact else 46.0)
	var free_evolution := String(offer.kind) == "evolution" and RunStats.evolution_cores > 0
	buy_button.text = "구매 완료" if bool(offer.get("purchased", false)) else ("[%d] 진화 코어 사용" % (index + 1) if free_evolution else "[%d] 구매 · %d 스크랩" % [index + 1, int(offer.cost)])
	buy_button.add_theme_font_size_override("font_size", 16)
	buy_button.add_theme_color_override("font_color", Color(0.9, 1.0, 0.97, 1.0))
	var buy_normal := StyleBoxFlat.new()
	buy_normal.bg_color = Color(accent, 0.2)
	buy_normal.border_color = accent
	buy_normal.set_border_width_all(2)
	buy_normal.set_corner_radius_all(6)
	var buy_hover := buy_normal.duplicate() as StyleBoxFlat
	buy_hover.bg_color = Color(accent, 0.44)
	buy_button.add_theme_stylebox_override("normal", buy_normal)
	buy_button.add_theme_stylebox_override("hover", buy_hover)
	buy_button.add_theme_stylebox_override("focus", buy_hover)
	buy_button.disabled = bool(offer.get("purchased", false)) or (not free_evolution and RunStats.scrap < int(offer.cost))
	buy_button.pressed.connect(func() -> void: _buy_offer(index))
	content.add_child(buy_button)
	if buy_button.disabled and not bool(offer.get("purchased", false)):
		card.modulate = Color(0.58, 0.62, 0.64, 0.72)
	return card

func _offer_icon(kind: String) -> String:
	match kind:
		"weapon_new", "weapon_upgrade": return "⚔"
		"evolution": return "✦"
		"passive": return "◆"
		"contract": return "⚠"
		_: return "+"

func _offer_kind_label(kind: String) -> String:
	match kind:
		"passive": return "패시브"
		"weapon_new": return "신규 무기"
		"weapon_upgrade": return "무기 강화"
		"evolution": return "변이 코어"
		"contract": return "위험 계약"
		_: return "보급품"

func _offer_name(offer: Dictionary) -> String:
	match String(offer.kind):
		"passive": return (offer.item as PerkData).perk_name
		"weapon_new": return (offer.item as WeaponUpgradeData).weapon_name
		"weapon_upgrade":
			var weapon := offer.item as Weapon
			return "%s\nLv %d → %d" % [weapon.data.weapon_name, weapon.current_level, weapon.current_level + 1]
		"evolution": return (offer.item as Weapon).get_display_name()
		"contract": return String(offer.name)
		_: return String(offer.name)

func _offer_description(offer: Dictionary) -> String:
	match String(offer.kind):
		"passive": return (offer.item as PerkData).description
		"weapon_new": return (offer.item as WeaponUpgradeData).description
		"weapon_upgrade": return "피해량과 성능을 강화합니다.\n다음 단계의 화력을 준비하세요."
		"evolution": return "%s\n진화 코어가 있으면 무료로 진화합니다." % (offer.item as Weapon).get_evolution_description()
		"contract": return String(offer.description)
		_: return String(offer.description)

func _offer_text(offer: Dictionary) -> String:
	if bool(offer.get("purchased", false)):
		return "구매 완료"
	match String(offer.kind):
		"passive":
			var passive := offer.item as PerkData
			return "[패시브]\n%s\n\n%s\n\n%d 스크랩" % [passive.perk_name, passive.description, offer.cost]
		"weapon_new":
			var weapon_data := offer.item as WeaponUpgradeData
			return "[신규 무기]\n%s\n\n%s\n\n%d 스크랩" % [weapon_data.weapon_name, weapon_data.description, offer.cost]
		"weapon_upgrade":
			var weapon := offer.item as Weapon
			return "[무기 강화]\n%s  Lv %d → %d\n\n피해량과 성능을 강화합니다.\n\n%d 스크랩" % [weapon.data.weapon_name, weapon.current_level, weapon.current_level + 1, offer.cost]
		"evolution":
			var evolution_weapon := offer.item as Weapon
			var evolution_cost: String = "진화 코어 1개" if RunStats.evolution_cores > 0 else "%d 스크랩" % offer.cost
			return "[무기 진화]\n%s\n\n%s\n\n비용: %s" % [evolution_weapon.get_display_name(), evolution_weapon.get_evolution_description(), evolution_cost]
		_:
			return "[보급]\n%s\n\n%s\n\n%d 스크랩" % [offer.name, offer.description, offer.cost]

func _offer_color(kind: String) -> Color:
	match kind:
		"weapon_new", "weapon_upgrade": return Color(1.0, 0.58, 0.28, 1.0)
		"evolution": return Color(0.88, 0.42, 1.0, 1.0)
		"contract": return Color(1.0, 0.3, 0.28, 1.0)
		"passive": return Color(0.3, 0.9, 0.78, 1.0)
		_: return Color(0.42, 0.78, 1.0, 1.0)

func _toggle_lock(index: int) -> void:
	if not visible or index < 0 or index >= offers.size():
		return
	var offer := offers[index]
	offer["locked"] = not bool(offer.get("locked", false))
	offers[index] = offer
	_render()

func _reroll() -> void:
	if not visible:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if not RunStats.run_active or not is_instance_valid(player) or player.dead or player.health <= 0:
		return
	if RunStats.rerolls_remaining > 0:
		RunStats.rerolls_remaining -= 1
	else:
		if not RunStats.spend_scrap(reroll_cost):
			return
		reroll_cost += 5
	var used_ids: Array[String] = []
	for offer in offers:
		if bool(offer.get("locked", false)) or bool(offer.get("purchased", false)):
			used_ids.append(String(offer.get("id", "")))
	for index in offers.size():
		if not bool(offers[index].get("locked", false)) and not bool(offers[index].get("purchased", false)):
			var replacement := _make_unique_offer(player, used_ids)
			if not replacement.is_empty():
				offers[index] = _apply_discount(replacement)
				used_ids.append(String(replacement.get("id", "")))
	_render()

func _banish_offer(index: int) -> void:
	if not visible or index < 0 or index >= offers.size() or RunStats.banishes_remaining <= 0:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if not RunStats.run_active or not is_instance_valid(player) or player.dead or player.health <= 0:
		return
	var old_id := String(offers[index].get("id", ""))
	if old_id.is_empty():
		return
	RunStats.banished_ids.append(old_id)
	RunStats.banishes_remaining -= 1
	var used_ids: Array[String] = []
	for other_index in offers.size():
		if other_index != index:
			used_ids.append(String(offers[other_index].get("id", "")))
	var replacement := _make_unique_offer(player, used_ids)
	if not replacement.is_empty():
		offers[index] = _apply_discount(replacement)
	else:
		offers.remove_at(index)
	_render()

func _apply_discount(offer: Dictionary) -> Dictionary:
	if offer.is_empty():
		return offer
	var discount := SaveManager.get_upgrade_level("shop_discount") * 0.06
	offer["cost"] = maxi(1, ceili(int(offer.get("cost", 0)) * (1.0 - discount)))
	return offer

func _buy_offer(index: int) -> void:
	if not visible or index < 0 or index >= offers.size():
		return
	var offer := offers[index]
	var free_evolution := String(offer.kind) == "evolution" and RunStats.evolution_cores > 0
	if bool(offer.get("purchased", false)):
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if not RunStats.run_active or not is_instance_valid(player) or player.dead or player.health <= 0:
		return
	var cost := int(offer.get("cost", 0))
	if not free_evolution and not RunStats.spend_scrap(cost):
		return
	if not _apply_offer(player, offer, free_evolution):
		if not free_evolution:
			RunStats.add_scrap(cost)
		return
	offer["purchased"] = true
	offers[index] = offer
	EventBus.inventory_updated.emit(player.weapons, player.passives)
	_render()

func _apply_offer(player: Player, offer: Dictionary, free_evolution: bool) -> bool:
	match String(offer.get("kind", "")):
		"passive":
			var passive := offer.get("item") as PerkData
			return player.apply_perk(passive) if is_instance_valid(passive) else false
		"weapon_new":
			var weapon_data := offer.get("item") as WeaponUpgradeData
			return player.add_weapon(weapon_data.weapon_script, weapon_data.weapon_data) if is_instance_valid(weapon_data) else false
		"weapon_upgrade":
			var weapon := offer.get("item") as Weapon
			return is_instance_valid(weapon) and weapon.get_parent() == player and weapon.upgrade()
		"evolution":
			var evolution_weapon := offer.get("item") as Weapon
			if not is_instance_valid(evolution_weapon) or not evolution_weapon.evolve(player):
				return false
			if free_evolution:
				return RunStats.consume_evolution_core()
			return true
		"repair":
			player.heal(35)
			return true
		"plating":
			player.max_health += 20
			player.heal(20)
			EventBus.player_health_changed.emit(player.health, player.max_health)
			return true
		"amplifier":
			player.damage_mult *= 1.1
			return true
		"boots":
			player.speed_mult *= 1.08
			return true
		"contract":
			return _apply_contract(player, String(offer.get("id", "")))
	return false

func _close_shop() -> void:
	if not visible:
		return
	visible = false
	ModalManager.release(self)
	EventBus.wave_started.emit(current_wave)

func _on_viewport_resized() -> void:
	if visible:
		_render()

func _apply_contract(player: Player, contract_id: String) -> bool:
	match contract_id:
		"volatile_ammo":
			player.damage_mult *= 1.22
			player.incoming_damage_mult *= 1.18
			return true
		"scavenger_route":
			RunStats.scrap_multiplier *= 1.45
			player.max_health = maxi(35, player.max_health - 15)
			player.health = mini(player.health, player.max_health)
			EventBus.player_health_changed.emit(player.health, player.max_health)
			return true
		"last_stand":
			player.max_health = maxi(35, player.max_health - 25)
			player.health = mini(player.health, player.max_health)
			player.damage_mult *= 1.35
			player.speed_mult *= 1.12
			EventBus.player_health_changed.emit(player.health, player.max_health)
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_shop()
	elif event is InputEventKey and event.keycode >= KEY_1 and event.keycode <= KEY_5:
		var index := int(event.keycode - KEY_1)
		if index < offers.size():
			get_viewport().set_input_as_handled()
			_buy_offer(index)
