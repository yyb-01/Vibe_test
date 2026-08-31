class_name PerkSelection
extends CanvasLayer

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.level_up.connect(_on_level_up)
	reroll_button.pressed.connect(_on_reroll_pressed)
	skip_button.pressed.connect(_on_skip_pressed)

func _on_level_up() -> void:
	# Pause game
	get_tree().paused = true
	visible = true

	# Clear existing children
	for child in container.get_children():
		child.free()

	AudioManager.play_named("level_up", -2.0)

	var player = get_tree().get_first_node_in_group("player") as Player
	if not player:
		visible = false
		get_tree().paused = false
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

		if item_id in shown_ids: continue
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
	if item is WeaponUpgradeData or item is Weapon:
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
		kind_label.text = "패시브"
		name_label.text = item.perk_name
		description_label.text = item.description
	elif item is WeaponUpgradeData:
		kind_label.text = "신규 무기"
		name_label.text = item.weapon_name
		description_label.text = item.description
	elif item is Weapon:
		kind_label.text = "무기 강화"
		name_label.text = "%s  Lv %d → %d" % [item.data.weapon_name, item.current_level, item.current_level + 1]
		description_label.text = "피해량 증가 및 성능 강화\n다음 단계의 화력을 준비하세요."

	select_button.text = "이 강화 선택"
	select_button.pressed.connect(func() -> void: _on_upgrade_selected(item))
	container.add_child(card)

func _update_reroll_button() -> void:
	reroll_button.text = "카드 리롤  ·  %dG" % REROLL_COST
	reroll_button.disabled = SaveManager.gold < REROLL_COST

func _on_reroll_pressed() -> void:
	if SaveManager.spend_gold(REROLL_COST):
		_on_level_up()

func _on_skip_pressed() -> void:
	visible = false
	get_tree().paused = false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.add_exp(8)

func _on_upgrade_selected(item: Variant) -> void:
	visible = false
	get_tree().paused = false

	var player = get_tree().get_first_node_in_group("player") as Player
	if player:
		if item is PerkData:
			player.apply_perk(item)
		elif item is WeaponUpgradeData:
			player.add_weapon(item.weapon_script, item.weapon_data)
		elif item is Weapon:
			item.upgrade()
		EventBus.inventory_updated.emit(player.weapons, player.passives)
