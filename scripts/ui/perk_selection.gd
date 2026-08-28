class_name PerkSelection
extends CanvasLayer

@onready var container: HBoxContainer = $CenterContainer/VBoxContainer/HBoxContainer
@onready var label: Label = $CenterContainer/VBoxContainer/TitleLabel

var available_passives: Array[PerkData] = [
	preload("res://data/perks/fast_hands.tres"),
	preload("res://data/perks/hollow_point.tres"),
	preload("res://data/perks/light_foot.tres"),
	preload("res://data/perks/piercing_rounds.tres"),
	preload("res://data/perks/heavy_caliber.tres")
]

var available_weapons: Array[WeaponUpgradeData] = [
	preload("res://data/perks/weap_pistol.tres"),
	preload("res://data/perks/weap_shotgun.tres"),
	preload("res://data/perks/weap_orbital.tres"),
	preload("res://data/perks/weap_lightning.tres")
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.level_up.connect(_on_level_up)

func _on_level_up() -> void:
	# Pause game
	get_tree().paused = true
	visible = true

	# Clear existing children
	for child in container.get_children():
		child.queue_free()

	AudioManager.play_sfx(null) # Play level up sound

	var player = get_tree().get_first_node_in_group("player") as Player
	if not player: return

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

func _create_upgrade_button(item: Variant) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(200, 300)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if item is PerkData:
		btn.text = "[패시브] " + item.perk_name + "\n\n" + item.description
	elif item is WeaponUpgradeData:
		btn.text = "[신규 무기] " + item.weapon_name + "\n\n" + item.description
	elif item is Weapon:
		btn.text = "[무기 강화] " + item.data.weapon_name + " Lv " + str(item.current_level + 1) + "\n\n피해량 증가 및 성능 강화"

	btn.pressed.connect(func() -> void: _on_upgrade_selected(item))
	container.add_child(btn)

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
