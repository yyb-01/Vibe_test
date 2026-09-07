class_name WaveShop
extends CanvasLayer

const OFFER_COUNT := 5
const BASE_REROLL_COST := 8

const MEDICAL_OFFERS := [
	{
		"kind": "medical",
		"id": "field_repair",
		"name": "야전 응급 수리",
		"description": "체력을 40 회복합니다.\n위급 상황에서 생존을 보장합니다.",
		"cost": 14
	},
	{
		"kind": "medical",
		"id": "ceramic_plating",
		"name": "세라믹 복합 플레이트",
		"description": "최대 체력 +25 영구 증가 및\n즉시 체력 25를 회복합니다.",
		"cost": 24
	},
	{
		"kind": "medical",
		"id": "trauma_patch",
		"name": "외상 봉합 패치",
		"description": "체력을 65 대폭 회복합니다.\n치명상을 입었을 때 유용합니다.",
		"cost": 22
	},
	{
		"kind": "medical",
		"id": "adrenaline_shot",
		"name": "전술 아드레날린 주사",
		"description": "이동 속도 +10% 영구 강화,\n긴급 회피(대시) 쿨타임 -0.2초 단축.",
		"cost": 24
	}
]

const TACTICAL_OFFERS := [
	{
		"kind": "tactical",
		"id": "evolution_core",
		"name": "진화 코어 조달",
		"description": "진화 코어 1개를 획득합니다.\n레벨업이나 상점에서 무료 승급 가능.",
		"cost": 45
	},
	{
		"kind": "tactical",
		"id": "reroll_pack",
		"name": "작전 재검토서",
		"description": "무료 리롤 +2회를 즉시 충전합니다.\n(레벨업 및 상점 공용)",
		"cost": 16
	},
	{
		"kind": "tactical",
		"id": "banish_protocol",
		"name": "불량품 폐기 인가서",
		"description": "카드 영구 제외(Banish) +1회를\n즉시 충전합니다.",
		"cost": 20
	},
	{
		"kind": "tactical",
		"id": "magnet_drone",
		"name": "자력 견인 모듈",
		"description": "경험치 젬 및 보급품 흡수 반경이\n+60px 대폭 증가합니다.",
		"cost": 18
	},
	{
		"kind": "tactical",
		"id": "tungsten_core",
		"name": "텅스텐 철갑 탄심",
		"description": "모든 탄환/발사체의 관통력이\n+1 영구 증가합니다.",
		"cost": 32
	},
	{
		"kind": "tactical",
		"id": "overclock_loader",
		"name": "오버클럭 급탄 모듈",
		"description": "모든 무기의 재장전 및 연사 속도가\n+18% 빨라집니다.",
		"cost": 28
	},
	{
		"kind": "tactical",
		"id": "hollow_point_kit",
		"name": "특수 작열탄 키트",
		"description": "치명타 확률 +6% 증가,\n치명타 피해량 +25% 증폭.",
		"cost": 26
	}
]

const CONTRACT_OFFERS := [
	{
		"kind": "contract",
		"id": "volatile_ammo",
		"name": "불안정 탄약 계약",
		"description": "모든 피해량 +25% 대폭 증가\n대신 받는 피해량 +15% 증가",
		"cost": 15
	},
	{
		"kind": "contract",
		"id": "scavenger_route",
		"name": "회수꾼 위험 경로",
		"description": "스크랩 획득량 +40% 증가\n대신 최대 체력 -15 감소",
		"cost": 15
	},
	{
		"kind": "contract",
		"id": "last_stand",
		"name": "배수의 진 계약",
		"description": "모든 피해 +35%, 이동 속도 +12%\n대신 최대 체력 -25 감소",
		"cost": 20
	},
	{
		"kind": "contract",
		"id": "bounty_hunt",
		"name": "현상금 추적 계약",
		"description": "스크랩 획득 배율 +15% 증가\n즉시 영구 골드 +20 획득",
		"cost": 18
	}
]

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
	overlay.color = Color(0.005, 0.014, 0.02, 0.94)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.02
	panel.anchor_top = 0.03
	panel.anchor_right = 0.98
	panel.anchor_bottom = 0.97
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.94, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)

	scrap_label = Label.new()
	scrap_label.add_theme_font_size_override("font_size", 16)
	scrap_label.add_theme_color_override("font_color", Color(0.42, 0.92, 1.0, 1.0))
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

	leave_button = _make_action_button("다음 웨이브 출동", Color(0.28, 0.75, 0.46, 1.0))
	leave_button.pressed.connect(_close_shop)
	actions.add_child(leave_button)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.038, 0.05, 0.99)
	style.border_color = Color(0.2, 0.8, 0.74, 0.85)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	return style

func _make_action_button(button_text: String, color: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(240, 48)
	button.text = button_text
	button.add_theme_font_size_override("font_size", 17)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color, 0.25)
	normal.border_color = color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(7)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(color, 0.5)
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
		used_ids.append(String(offer.get("id", "depot_%d" % offers.size())))

func _make_unique_offer(player: Player, used_ids: Array[String]) -> Dictionary:
	for _attempt in range(25):
		var offer := _make_offer(player, used_ids)
		if not offer.is_empty():
			var offer_id := String(offer.get("id", ""))
			if not offer_id.is_empty() and offer_id not in used_ids and offer_id not in RunStats.banished_ids:
				return offer
	for supply in MEDICAL_OFFERS:
		if String(supply.get("id", "")) not in RunStats.banished_ids:
			var copy: Dictionary = supply.duplicate()
			copy["locked"] = false
			return copy
	return {}

func _make_offer(player: Player, used_ids: Array[String]) -> Dictionary:
	var evolution_candidates: Array[Weapon] = []
	for weapon in player.weapons:
		if is_instance_valid(weapon) and weapon.can_evolve(player):
			evolution_candidates.append(weapon)
	if current_wave >= 3 and not evolution_candidates.is_empty() and randf() < 0.22:
		var evolution_weapon: Weapon = evolution_candidates.pick_random()
		var evolution_id := "evolution_" + evolution_weapon.data.weapon_name
		if evolution_id not in used_ids and evolution_id not in RunStats.banished_ids:
			return {
				"kind": "evolution",
				"id": evolution_id,
				"item": evolution_weapon,
				"cost": 48,
				"locked": false
			}

	var roll := randf()
	if current_wave >= 2 and roll < 0.30:
		return _make_contract_offer(used_ids)
	elif roll < 0.65:
		return _make_tactical_offer(used_ids)
	return _make_medical_offer(used_ids)

func _make_contract_offer(used_ids: Array[String]) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for contract in CONTRACT_OFFERS:
		var c_id := String(contract.get("id", ""))
		if c_id not in used_ids and c_id not in RunStats.banished_ids:
			var item: Dictionary = contract.duplicate()
			item["locked"] = false
			candidates.append(item)
	return _make_medical_offer(used_ids) if candidates.is_empty() else candidates.pick_random()

func _make_medical_offer(used_ids: Array[String]) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for med in MEDICAL_OFFERS:
		var m_id := String(med.get("id", ""))
		if m_id not in used_ids and m_id not in RunStats.banished_ids:
			var item: Dictionary = med.duplicate()
			item["locked"] = false
			candidates.append(item)
	if candidates.is_empty():
		return _make_tactical_offer(used_ids)
	return candidates.pick_random()

func _make_tactical_offer(used_ids: Array[String]) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for tac in TACTICAL_OFFERS:
		var t_id := String(tac.get("id", ""))
		if t_id not in used_ids and t_id not in RunStats.banished_ids:
			var item: Dictionary = tac.duplicate()
			item["locked"] = false
			candidates.append(item)
	if candidates.is_empty():
		var fallback: Dictionary = MEDICAL_OFFERS[0].duplicate()
		fallback["locked"] = false
		return fallback
	return candidates.pick_random()

func _render() -> void:
	title_label.text = "파동 %02d 방어 완료  ·  야전 전술 보급소 (Tactical Depot)" % current_wave
	scrap_label.text = "보유 스크랩  %d   ·   응급 의료, 전술 조달 및 작전 계약을 선택하세요" % RunStats.scrap
	reroll_button.text = "무료 작전 재검토  ·  %d회" % RunStats.rerolls_remaining if RunStats.rerolls_remaining > 0 else "진열 새로고침  ·  %d 스크랩" % reroll_cost
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

	var kind := String(offer.get("kind", ""))
	var is_evolution := (kind == "evolution")
	var is_contract := (kind == "contract")

	var accent := _offer_color(kind)
	var bg_color := Color(0.02, 0.058, 0.07, 0.98)
	var border_width := 2

	if is_evolution:
		bg_color = Color(0.09, 0.035, 0.15, 0.98)
		border_width = 3
	elif is_contract:
		bg_color = Color(0.08, 0.025, 0.025, 0.98)

	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_color = Color(accent, 0.85)
	normal.set_border_width_all(border_width)
	normal.set_corner_radius_all(10)
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
	lock_button.tooltip_text = "잠금: 새로고침 시 이 카드를 유지합니다."
	lock_button.disabled = bool(offer.get("purchased", false))
	lock_button.pressed.connect(func() -> void: _toggle_lock(index))
	tools.add_child(lock_button)

	if RunStats.banishes_remaining > 0 and not bool(offer.get("purchased", false)):
		var banish_button := Button.new()
		banish_button.custom_minimum_size = Vector2(34, 30)
		banish_button.text = "🗑"
		banish_button.tooltip_text = "이번 런에서 폐기(제외) · %d회 남음" % RunStats.banishes_remaining
		banish_button.pressed.connect(func() -> void: _banish_offer(index))
		tools.add_child(banish_button)
	content.add_child(tools)

	var kind_label := Label.new()
	kind_label.text = _offer_kind_label(kind)
	kind_label.add_theme_font_size_override("font_size", 13)
	kind_label.add_theme_color_override("font_color", accent)
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(kind_label)

	var visual := Label.new()
	visual.text = _offer_icon(kind)
	visual.custom_minimum_size = Vector2(0, 52.0 if compact else 64.0)
	visual.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visual.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visual.add_theme_font_size_override("font_size", 36)
	visual.add_theme_color_override("font_color", accent)
	content.add_child(visual)

	var name_label := Label.new()
	name_label.text = _offer_name(offer)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 36.0 if compact else 44.0)
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0) if is_evolution else Color(0.92, 0.98, 0.96, 1.0))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(name_label)

	var description_label := Label.new()
	description_label.text = _offer_description(offer)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(0, 64.0 if compact else 105.0)
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.add_theme_font_size_override("font_size", 13)
	description_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.65, 1.0) if is_evolution else Color(0.72, 0.86, 0.84, 1.0))
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	content.add_child(description_label)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(0, 42.0 if compact else 46.0)
	var free_evolution := is_evolution and RunStats.evolution_cores > 0
	var cost := int(offer.get("cost", 0))

	if bool(offer.get("purchased", false)):
		buy_button.text = "조달 완료"
	elif free_evolution:
		buy_button.text = "[%d] 코어 1개로 진화" % (index + 1)
	else:
		buy_button.text = "[%d] 조달 · %d 스크랩" % [index + 1, cost]

	buy_button.add_theme_font_size_override("font_size", 15)
	buy_button.add_theme_color_override("font_color", Color(0.95, 1.0, 0.98, 1.0))

	var buy_normal := StyleBoxFlat.new()
	buy_normal.bg_color = Color(accent, 0.28 if is_evolution else 0.22)
	buy_normal.border_color = accent
	buy_normal.set_border_width_all(2)
	buy_normal.set_corner_radius_all(6)
	var buy_hover := buy_normal.duplicate() as StyleBoxFlat
	buy_hover.bg_color = Color(accent, 0.48)
	buy_button.add_theme_stylebox_override("normal", buy_normal)
	buy_button.add_theme_stylebox_override("hover", buy_hover)
	buy_button.add_theme_stylebox_override("focus", buy_hover)

	buy_button.disabled = bool(offer.get("purchased", false)) or (not free_evolution and RunStats.scrap < cost)
	buy_button.pressed.connect(func() -> void: _buy_offer(index))
	content.add_child(buy_button)

	if buy_button.disabled and not bool(offer.get("purchased", false)):
		card.modulate = Color(0.58, 0.62, 0.64, 0.72)
	return card

func _offer_icon(kind: String) -> String:
	match kind:
		"medical": return "✚"
		"tactical": return "⚙"
		"contract": return "⚠"
		"evolution": return "⚡ ★ ⚡"
		_: return "★"

func _offer_kind_label(kind: String) -> String:
	match kind:
		"medical": return "[✚ 응급 의료]"
		"tactical": return "[⚙ 전술 조달]"
		"contract": return "[⚠ 위험 작전 계약]"
		"evolution": return "[★ 전설 무기 진화]"
		_: return "[야전 보급]"

func _offer_name(offer: Dictionary) -> String:
	var kind := String(offer.get("kind", ""))
	if kind == "evolution":
		var w = offer.get("item")
		return "★ " + (w.get_display_name() if is_instance_valid(w) and w.has_method("get_display_name") else "전설 무기")
	return String(offer.get("name", "보급품"))

func _offer_description(offer: Dictionary) -> String:
	var kind := String(offer.get("kind", ""))
	if kind == "evolution":
		var w = offer.get("item")
		var evo_desc: String = w.get_evolution_description() if is_instance_valid(w) and w.has_method("get_evolution_description") else ""
		return "%s\n(진화 코어 보유 시 무료로 즉시 승급)" % evo_desc
	return String(offer.get("description", ""))

func _offer_color(kind: String) -> Color:
	match kind:
		"medical": return Color(0.28, 0.95, 0.65, 1.0)
		"tactical": return Color(0.28, 0.88, 1.0, 1.0)
		"contract": return Color(1.0, 0.35, 0.28, 1.0)
		"evolution": return Color(1.0, 0.84, 0.18, 1.0)
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
	var free_evolution := String(offer.get("kind", "")) == "evolution" and RunStats.evolution_cores > 0
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
	AudioManager.play_named("pickup", -2.0, 1.2)
	EventBus.inventory_updated.emit(player.weapons, player.passives)
	_render()

func _apply_offer(player: Player, offer: Dictionary, free_evolution: bool) -> bool:
	if not is_instance_valid(player):
		return false
	var offer_id := String(offer.get("id", ""))
	match String(offer.get("kind", "")):
		"evolution":
			var evolution_weapon := offer.get("item") as Weapon
			if not is_instance_valid(evolution_weapon) or not evolution_weapon.evolve(player):
				return false
			if free_evolution:
				return RunStats.consume_evolution_core()
			return true
		"medical":
			match offer_id:
				"field_repair":
					player.heal(40)
					return true
				"ceramic_plating":
					player.max_health += 25
					player.heal(25)
					EventBus.player_health_changed.emit(player.health, player.max_health)
					return true
				"trauma_patch":
					player.heal(65)
					return true
				"adrenaline_shot":
					player.speed_mult *= 1.10
					player.dash_cooldown = maxf(0.0, player.dash_cooldown - 0.2)
					return true
		"tactical":
			match offer_id:
				"evolution_core":
					RunStats.add_evolution_core(1)
					return true
				"reroll_pack":
					RunStats.add_rerolls(2)
					return true
				"banish_protocol":
					RunStats.add_banishes(1)
					return true
				"magnet_drone":
					player.magnet_bonus += 60.0
					return true
				"tungsten_core":
					player.pierce_add += 1
					return true
				"overclock_loader":
					player.reload_mult *= 0.82
					return true
				"hollow_point_kit":
					player.critical_chance_add += 0.06
					player.critical_damage_mult += 0.25
					return true
		"contract":
			return _apply_contract(player, offer_id)
	return false

func _apply_contract(player: Player, contract_id: String) -> bool:
	if not is_instance_valid(player) or player.dead:
		return false
	match contract_id:
		"volatile_ammo":
			player.damage_mult *= 1.25
			player.incoming_damage_mult *= 1.15
			return true
		"scavenger_route":
			RunStats.scrap_multiplier *= 1.40
			player.max_health = maxi(25, player.max_health - 15)
			player.health = clampi(player.health, 1, player.max_health)
			EventBus.player_health_changed.emit(player.health, player.max_health)
			return true
		"last_stand":
			player.max_health = maxi(25, player.max_health - 25)
			player.health = clampi(player.health, 1, player.max_health)
			player.damage_mult *= 1.35
			player.speed_mult *= 1.12
			EventBus.player_health_changed.emit(player.health, player.max_health)
			return true
		"bounty_hunt":
			RunStats.scrap_multiplier *= 1.15
			SaveManager.add_gold(20)
			return true
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
