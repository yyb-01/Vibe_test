class_name PerkSelection
extends CanvasLayer

const CATALOG: Script = preload("res://scripts/resources/advanced_weapon_catalog.gd")

@onready var container: HBoxContainer = $CenterContainer/VBoxContainer/HBoxContainer
@onready var label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var reroll_button: Button = $CenterContainer/VBoxContainer/ActionRow/RerollButton
@onready var skip_button: Button = $CenterContainer/VBoxContainer/ActionRow/SkipButton

const REROLL_COST: int = 25

var available_passives: Array[PerkData] = [
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

var available_weapons: Array[WeaponUpgradeData] = [
	preload("res://data/perks/weap_pistol.tres"),
	preload("res://data/perks/weap_shotgun.tres"),
	preload("res://data/perks/weap_orbital.tres"),
	preload("res://data/perks/weap_lightning.tres"),
	preload("res://data/perks/weap_smg.tres"),
	preload("res://data/perks/weap_burst.tres"),
	preload("res://data/perks/weap_railgun.tres"),
	preload("res://data/perks/weap_nova.tres")
]
var codex_dialog: AcceptDialog
var pending_level_ups: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.level_up.connect(_on_level_up)
	reroll_button.pressed.connect(_on_reroll_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	skip_button.text = "건너뛰기  ·  +10 골드"
	var codex_button := Button.new()
	codex_button.text = "★ 진화 도감 보기"
	codex_button.custom_minimum_size = Vector2(210, 48)
	$CenterContainer/VBoxContainer/ActionRow.add_child(codex_button)
	codex_dialog = AcceptDialog.new()
	codex_dialog.title = "무기 진화 도감"
	codex_dialog.dialog_text = _codex_text()
	codex_dialog.min_size = Vector2i(820, 580)
	add_child(codex_dialog)
	codex_button.pressed.connect(func() -> void: codex_dialog.popup_centered(Vector2i(820, 580)))

func _on_level_up() -> void:
	if not RunStats.run_active:
		return
	pending_level_ups += 1
	if visible:
		return
	ModalManager.request(self, _open_level_up)

func _open_level_up() -> void:
	if pending_level_ups <= 0:
		return
	pending_level_ups -= 1
	_show_level_up()

func _show_level_up() -> void:
	visible = true

	# Clear existing children
	for child in container.get_children():
		child.free()

	AudioManager.play_named("level_up", -2.0)

	var player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(player) or player.dead or player.health <= 0:
		pending_level_ups = 0
		visible = false
		ModalManager.release(self)
		return

	var advanced_choices: Array[Dictionary] = UpgradeManager.get_level_up_choices(player, 3)
	if not advanced_choices.is_empty():
		for choice in advanced_choices:
			_create_upgrade_button(choice)
		_update_reroll_button()
		return

	var pool = []
	var owned_passive_ids: Array[String] = []
	for passive in player.passives:
		owned_passive_ids.append(passive.id)
	if player.passives.size() < player.max_passives:
		for passive in available_passives:
			if passive.id not in owned_passive_ids:
				pool.append(passive)

	# Check weapons
	for w_data in available_weapons:
		var has_weapon = false
		for w in player.weapons:
			if w.data.weapon_name == w_data.weapon_data.weapon_name:
				has_weapon = true
				if w.current_level < Weapon.MAX_LEVEL:
					pool.append(w) # Can upgrade existing weapon
				break

		if not has_weapon and player.weapons.size() < player.max_weapons:
			pool.append(w_data) # Can buy new weapon

	pool.shuffle()

	var shown_ids = []
	var options_shown = 0

	for item in pool:
		if options_shown >= 3: break

		# Prevent duplicates of the same passive showing up in the same screen
		var item_id = ""
		if item is PerkData: item_id = item.id
		elif item is WeaponUpgradeData: item_id = item.weapon_id
		elif item is Weapon: item_id = item.data.weapon_name

		if item_id in shown_ids or item_id in RunStats.banished_ids: continue
		shown_ids.append(item_id)

		_create_upgrade_button(item)
		options_shown += 1
	_update_reroll_button()

func _create_upgrade_button(item: Variant) -> void:
	# Keep every level-up card identical in size. Long descriptions live in a
	# dedicated wrapped label instead of stretching a Button unpredictably.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 360)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var accent := Color(0.25, 0.88, 0.82, 1.0)
	if item is WeaponUpgradeData or item is Weapon or item is Dictionary and String(item.get("kind", "")) == "evolution":
		accent = Color(1.0, 0.57, 0.28, 1.0)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.025, 0.055, 0.07, 0.98)
	normal_style.border_color = Color(accent, 0.72)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	normal_style.set_content_margin_all(14.0)
	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.07, 0.13, 0.15, 1.0)
	hover_style.border_color = accent
	hover_style.set_border_width_all(3)
	card.add_theme_stylebox_override("panel", normal_style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	card.add_child(content)

	var kind_label := Label.new()
	kind_label.add_theme_font_size_override("font_size", 14)
	kind_label.add_theme_color_override("font_color", accent)
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(kind_label)
	var visual := Label.new()
	visual.text = "◆" if item is PerkData or (item is Dictionary and String(item.get("kind", "")).begins_with("passive")) else "⚔"
	visual.custom_minimum_size = Vector2(0, 64)
	visual.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visual.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visual.add_theme_font_size_override("font_size", 38)
	visual.add_theme_color_override("font_color", accent)
	content.add_child(visual)

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(0, 58)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.96, 1.0))
	content.add_child(name_label)

	var description_label := Label.new()
	description_label.custom_minimum_size = Vector2(0, 174)
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description_label.add_theme_font_size_override("font_size", 15)
	description_label.add_theme_color_override("font_color", Color(0.7, 0.86, 0.82, 1.0))
	content.add_child(description_label)

	var select_button := Button.new()
	select_button.custom_minimum_size = Vector2(0, 52)
	select_button.focus_mode = Control.FOCUS_ALL
	select_button.add_theme_font_size_override("font_size", 18)
	select_button.add_theme_color_override("font_color", Color(0.86, 1.0, 0.94, 1.0))
	select_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.86, 1.0))
	select_button.add_theme_stylebox_override("normal", normal_style)
	select_button.add_theme_stylebox_override("hover", hover_style)
	select_button.add_theme_stylebox_override("focus", hover_style)
	select_button.add_theme_stylebox_override("pressed", hover_style)
	content.add_child(select_button)

	if item is PerkData:
		var evolution_links := _get_weapon_evolution_links(item.id)
		kind_label.text = "[★ 진화 시너지]  ·  [NEW 신규]" if not evolution_links.is_empty() else "[NEW 신규]  ·  패시브"
		if not evolution_links.is_empty():
			kind_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.24, 1.0))
			var pulse := create_tween().set_loops()
			pulse.tween_property(kind_label, "modulate:a", 0.45, 0.55)
			pulse.tween_property(kind_label, "modulate:a", 1.0, 0.55)
		name_label.text = item.perk_name
		description_label.text = item.description + _get_build_recipe_hint(item.id)
		if not evolution_links.is_empty():
			var tip := "보유 무기 진화 연계\n" + "\n".join(evolution_links)
			card.tooltip_text = tip
			kind_label.tooltip_text = tip
			name_label.tooltip_text = tip
			description_label.tooltip_text = tip
			select_button.tooltip_text = tip
	elif item is WeaponUpgradeData:
		kind_label.text = "[NEW 신규]  ·  무기"
		name_label.text = item.weapon_name
		description_label.text = item.description
	elif item is Weapon:
		kind_label.text = "[Lv %d ➔ %d]  ·  무기 강화" % [item.current_level, item.current_level + 1]
		name_label.text = "%s  Lv %d → %d" % [item.data.weapon_name, item.current_level, item.current_level + 1]
		description_label.text = "피해량 증가 및 성능 강화\n다음 단계의 화력을 준비하세요."
	elif item is Dictionary:
		var choice_kind := String(item.get("kind", "upgrade"))
		kind_label.text = "[★ 진화]  ·  무기 교체" if choice_kind == "evolution" else "[%s]" % String(item.get("label", "성장"))
		name_label.text = String(item.get("display_name", "알 수 없음"))
		description_label.text = String(item.get("description", ""))

	select_button.text = "이 강화 선택"
	select_button.pressed.connect(func() -> void: _on_upgrade_selected(item))
	if RunStats.banishes_remaining > 0:
		var banish_button := Button.new()
		banish_button.text = "불량품 폐기  ·  %d회" % RunStats.banishes_remaining
		banish_button.pressed.connect(func() -> void: _on_banish_pressed(item))
		content.add_child(banish_button)
	container.add_child(card)

func _get_weapon_evolution_links(perk_id: String) -> Array[String]:
	var links: Array[String] = []
	var player := get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(player):
		return links
	for recipe in CATALOG.get_recipes():
		if String(recipe.get("required_passive_id")) == perk_id:
			var base_id := String(recipe.get("base_weapon_id"))
			var res_data = recipe.get("result_weapon_data")
			for weapon in player.weapons:
				if EvolutionManager.get_weapon_id(weapon) == base_id and not weapon.evolved:
					var res_name: String = res_data.get_display_name() if res_data else ""
					links.append("%s  Lv %d/5  →  ★ %s" % [weapon.get_display_name(), weapon.current_level, res_name])
	if links.is_empty():
		for weapon in player.weapons:
			if not weapon.evolved and perk_id in weapon.get_evolution_requirements():
				links.append("%s  Lv %d/5  ·  %s" % [weapon.get_display_name(), weapon.current_level, weapon.get_evolution_requirement_text()])
	return links

func _get_build_recipe_hint(perk_id: String) -> String:
	match perk_id:
		"heavy_caliber": return "\n\n[전투 교리] 철갑탄 → 장갑 파쇄자"
		"piercing_rounds": return "\n\n[전투 교리] 대구경 탄환 → 장갑 파쇄자"
		"hollow_point": return "\n\n[전투 교리] 처형 프로토콜 → 처형 교리"
		"executioner": return "\n\n[전투 교리] 할로우 포인트 → 처형 교리"
		"fast_hands": return "\n\n[전투 교리] 가속 전술 → 런 앤 건"
		"momentum": return "\n\n[전투 교리] 빠른 손놀림 → 런 앤 건"
		"adrenaline": return "\n\n[전투 교리] 반동 제어기 → 과부하 전술"
		"stabilizer": return "\n\n[전투 교리] 아드레날린 → 과부하 전술"
		"reinforced_vest": return "\n\n[전투 교리] 외상 키트 → 불굴의 생존자"
		"trauma_kit": return "\n\n[전투 교리] 복합 장갑 → 불굴의 생존자"
		"scavenged_ammo": return "\n\n[전투 교리] 야전 식량 → 폐허 경제"
		"medic_kit": return "\n\n[전투 교리] 가벼운 발걸음 → 기동 의무병"
		"light_foot": return "\n\n[전투 교리] 응급 키트 → 기동 의무병"
		"bloodlust": return "\n\n[전투 교리] 야전 식량 → 피의 엔진"
		"field_rations": return "\n\n[전투 교리] 회수 탄약 → 폐허 경제\n피의 굶주림 → 피의 엔진"
		_: return ""

func _update_reroll_button() -> void:
	reroll_button.text = "무료 카드 리롤  ·  %d회" % RunStats.rerolls_remaining if RunStats.rerolls_remaining > 0 else "카드 리롤  ·  %dG" % REROLL_COST
	reroll_button.disabled = RunStats.rerolls_remaining <= 0 and SaveManager.gold < REROLL_COST

func _on_reroll_pressed() -> void:
	if not visible:
		return
	if RunStats.rerolls_remaining > 0:
		RunStats.rerolls_remaining -= 1
		_show_level_up()
	elif SaveManager.spend_gold(REROLL_COST):
		_show_level_up()

func _on_banish_pressed(item: Variant) -> void:
	if not visible or RunStats.banishes_remaining <= 0:
		return
	var item_id := ""
	if item is PerkData:
		item_id = item.id
	elif item is WeaponUpgradeData:
		item_id = item.weapon_id
	elif item is Weapon:
		item_id = item.data.weapon_name
	elif item is Dictionary:
		var choice_data = item.get("data")
		item_id = String(choice_data.get("id") if choice_data is Object else item.get("kind", "choice"))
	RunStats.banished_ids.append(String(item_id))
	RunStats.banishes_remaining -= 1
	_show_level_up()

func _on_skip_pressed() -> void:
	_finish_level_up()
	SaveManager.add_gold(10)

func _finish_level_up() -> void:
	visible = false
	ModalManager.release(self)
	if pending_level_ups > 0:
		ModalManager.request(self, _open_level_up)

func _codex_text() -> String:
	var lines: Array[String] = []
	for recipe in CATALOG.get_recipes():
		var base_id := String(recipe.get("base_weapon_id"))
		var req_passive_id := String(recipe.get("required_passive_id"))
		var res_data = recipe.get("result_weapon_data")
		var base_name := _get_base_weapon_display_name(base_id)
		var passive_name := _get_advanced_passive_label(req_passive_id)
		var result_name := String(res_data.get_display_name()) if res_data else ""
		var desc := String(res_data.description) if res_data else ""
		lines.append("%s Lv5  +  %s\n→ ★ %s\n%s" % [base_name, passive_name, result_name, desc])
	return "\n\n".join(lines)

func _get_base_weapon_display_name(base_id: String) -> String:
	match base_id:
		"pistol": return "권총 (Pistol)"
		"shotgun": return "산탄총 (Shotgun)"
		"heavy_revolver": return "헤비 리볼버 (Heavy Revolver)"
		"flamethrower": return "화염방사기 (Flamethrower)"
		"rpg": return "로켓 런처 (RPG)"
		"tesla_cannon": return "테슬라 건 (Tesla Cannon)"
		_: return base_id

func _get_advanced_passive_label(passive_id: String) -> String:
	match passive_id:
		"quick_hands": return "빠른 손 (연사력 증가)"
		"oil_reservoir": return "연료 탱크 (범위 증가)"
		"crit_core": return "크리티컬 코어 (치명타율 증가)"
		"blue_catalyst": return "청염 촉매 (화염 피해 증가)"
		"fragmentation": return "분열 장약 (폭발 피해 증가)"
		"storm_core": return "폭풍 코어 (쿨다운 감소)"
		_: return Weapon.get_perk_label(passive_id)

func _on_upgrade_selected(item: Variant) -> void:
	if not visible:
		return

	var player = get_tree().get_first_node_in_group("player") as Player
	if is_instance_valid(player):
		if item is PerkData:
			player.apply_perk(item)
		elif item is WeaponUpgradeData:
			player.add_weapon(item.weapon_script, item.weapon_data)
		elif item is Weapon:
			item.upgrade()
		elif item is Dictionary:
			UpgradeManager.apply_choice(player, item)
		EventBus.inventory_updated.emit(player.weapons, player.passives)
	_finish_level_up()
