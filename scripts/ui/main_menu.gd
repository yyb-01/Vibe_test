class_name MainMenu
extends CanvasLayer

@onready var map_1_btn: Button = $TabContainer/PlayTab/VBoxContainer/Map1Button
@onready var map_2_btn: Button = $TabContainer/PlayTab/VBoxContainer/Map2Button

@onready var hp_upgrade_btn: Button = $TabContainer/ShopTab/VBoxContainer/HPUpgradeBtn
@onready var dmg_upgrade_btn: Button = $TabContainer/ShopTab/VBoxContainer/DmgUpgradeBtn
@onready var spd_upgrade_btn: Button = $TabContainer/ShopTab/VBoxContainer/SpdUpgradeBtn
@onready var gold_label: Label = $GoldLabel

func _ready() -> void:
	map_1_btn.pressed.connect(func() -> void: _load_map("res://scenes/maps/map_1.tscn"))
	map_2_btn.pressed.connect(func() -> void: _load_map("res://scenes/maps/map_2.tscn"))

	hp_upgrade_btn.pressed.connect(func(): _buy_upgrade("max_hp"))
	dmg_upgrade_btn.pressed.connect(func(): _buy_upgrade("damage"))
	spd_upgrade_btn.pressed.connect(func(): _buy_upgrade("speed"))

	EventBus.gold_changed.connect(_on_gold_changed)
	_update_shop_ui()

func _on_gold_changed(_new_gold: int) -> void:
	_update_shop_ui()

func _update_shop_ui() -> void:
	gold_label.text = "Gold: " + str(SaveManager.gold)

	var hp_cost = (SaveManager.upgrade_max_hp + 1) * 100
	var dmg_cost = (SaveManager.upgrade_damage + 1) * 100
	var spd_cost = (SaveManager.upgrade_speed + 1) * 100

	hp_upgrade_btn.text = "Upgrade Max HP (Lv %d) - %d G" % [SaveManager.upgrade_max_hp, hp_cost]
	dmg_upgrade_btn.text = "Upgrade Damage (Lv %d) - %d G" % [SaveManager.upgrade_damage, dmg_cost]
	spd_upgrade_btn.text = "Upgrade Speed (Lv %d) - %d G" % [SaveManager.upgrade_speed, spd_cost]

	hp_upgrade_btn.disabled = SaveManager.gold < hp_cost
	dmg_upgrade_btn.disabled = SaveManager.gold < dmg_cost
	spd_upgrade_btn.disabled = SaveManager.gold < spd_cost

func _buy_upgrade(stat: String) -> void:
	var cost = 0
	if stat == "max_hp":
		cost = (SaveManager.upgrade_max_hp + 1) * 100
		if SaveManager.spend_gold(cost): SaveManager.upgrade_max_hp += 1
	elif stat == "damage":
		cost = (SaveManager.upgrade_damage + 1) * 100
		if SaveManager.spend_gold(cost): SaveManager.upgrade_damage += 1
	elif stat == "speed":
		cost = (SaveManager.upgrade_speed + 1) * 100
		if SaveManager.spend_gold(cost): SaveManager.upgrade_speed += 1

	SaveManager.save_data()
	_update_shop_ui()

func _load_map(path: String) -> void:
	get_tree().paused = false

	# Clear Autoload states before launching a new game
	ObjectPoolManager.clear()
	SpatialGrid.clear()

	get_tree().change_scene_to_file(path)
