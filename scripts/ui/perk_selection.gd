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
	pool.append_array(available_passives)

	# Check weapons
	for w_data in available_weapons:
		var has_weapon = false
		for w in player.weapons:
			if w.data.weapon_name == w_data.weapon_data.weapon_name:
				has_weapon = true
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
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(200, 300)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_color_override("font_color", Color(0.86, 1.0, 0.94, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.86, 1.0))

	if item is PerkData:
		btn.text = "[패시브] " + item.perk_name + "\n\n" + item.description
	elif item is WeaponUpgradeData:
		btn.text = "[신규 무기] " + item.weapon_name + "\n\n" + item.description
	elif item is Weapon:
		btn.text = "[무기 강화] " + item.data.weapon_name + " Lv " + str(item.current_level + 1) + "\n\n피해량 증가 및 성능 강화"

	btn.pressed.connect(func() -> void: _on_upgrade_selected(item))
	container.add_child(btn)

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
