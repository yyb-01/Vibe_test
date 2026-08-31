class_name MainMenu
extends CanvasLayer

@onready var map_1_btn: Button = $TabContainer/PlayTab/VBoxContainer/Map1Button
@onready var map_2_btn: Button = $TabContainer/PlayTab/VBoxContainer/Map2Button
@onready var map_3_btn: Button = $TabContainer/PlayTab/VBoxContainer/Map3Button
@onready var map_4_btn: Button = $TabContainer/PlayTab/VBoxContainer/Map4Button

@onready var hp_upgrade_btn: Button = $TabContainer/ShopTab/VBoxContainer/HPUpgradeBtn
@onready var dmg_upgrade_btn: Button = $TabContainer/ShopTab/VBoxContainer/DmgUpgradeBtn
@onready var spd_upgrade_btn: Button = $TabContainer/ShopTab/VBoxContainer/SpdUpgradeBtn
@onready var gold_label: Label = $GoldLabel
@onready var progress_label: Label = $ProgressLabel
@onready var character_select: OptionButton = $TabContainer/PlayTab/VBoxContainer/CharacterSelect
@onready var character_info_label: Label = $TabContainer/PlayTab/VBoxContainer/CharacterInfoLabel
@onready var screen_shake_toggle: CheckButton = $TabContainer/ShopTab/VBoxContainer/ScreenShakeToggle
@onready var volume_slider: HSlider = $TabContainer/ShopTab/VBoxContainer/VolumeSlider

const CHARACTER_IDS := ["scavenger", "medic", "ranger"]
const CHARACTER_NAMES := ["Scavenger · 공격형", "Medic · 생존형", "Ranger · 기동형"]
const CHARACTER_DESCRIPTIONS := [
	"폐허의 약탈자 · 최대 HP +10 · 피해량 +8%",
	"응급 구조 전문가 · 최대 HP +35 · 피해량 -10%",
	"기동 정찰병 · 이동 속도 +35 · 피해량 +10% · 사격/재장전 10% 단축"
]

func _ready() -> void:
	map_1_btn.pressed.connect(func() -> void: _load_map("res://scenes/maps/map_1.tscn"))
	map_2_btn.pressed.connect(func() -> void: _load_map("res://scenes/maps/map_2.tscn"))
	map_3_btn.pressed.connect(func() -> void: _load_map("res://scenes/maps/map_3.tscn"))
	map_4_btn.pressed.connect(func() -> void: _load_map("res://scenes/maps/map_4.tscn"))

	hp_upgrade_btn.pressed.connect(func(): _buy_upgrade("max_hp"))
	dmg_upgrade_btn.pressed.connect(func(): _buy_upgrade("damage"))
	spd_upgrade_btn.pressed.connect(func(): _buy_upgrade("speed"))
	character_select.item_selected.connect(_on_character_selected)
	screen_shake_toggle.toggled.connect(_on_screen_shake_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	for character_name in CHARACTER_NAMES:
		character_select.add_item(character_name)
	var selected_character_index := maxi(0, CHARACTER_IDS.find(SaveManager.selected_character))
	character_select.select(selected_character_index)
	_update_character_info(selected_character_index)
	screen_shake_toggle.button_pressed = SaveManager.screen_shake_enabled
	volume_slider.value = SaveManager.master_volume
	AudioManager.set_master_volume(SaveManager.master_volume)

	EventBus.gold_changed.connect(_on_gold_changed)
	_update_shop_ui()
	_update_progress_ui()
	map_1_btn.grab_focus()

func _on_gold_changed(_new_gold: int) -> void:
	_update_shop_ui()
	_update_progress_ui()

func _update_progress_ui() -> void:
	var best_seconds := int(SaveManager.best_time)
	progress_label.text = "런 %d회  ·  최고 웨이브 %02d  ·  최고 생존 %02d:%02d" % [SaveManager.total_runs, SaveManager.highest_wave, best_seconds / 60, best_seconds % 60]

func _on_character_selected(index: int) -> void:
	if index >= 0 and index < CHARACTER_IDS.size():
		SaveManager.selected_character = CHARACTER_IDS[index]
		_update_character_info(index)
		SaveManager.save_data()

func _update_character_info(index: int) -> void:
	if index >= 0 and index < CHARACTER_DESCRIPTIONS.size():
		character_info_label.text = CHARACTER_DESCRIPTIONS[index]

func _on_screen_shake_toggled(enabled: bool) -> void:
	SaveManager.screen_shake_enabled = enabled
	SaveManager.save_data()

func _on_volume_changed(value: float) -> void:
	SaveManager.master_volume = value
	AudioManager.set_master_volume(value)
	SaveManager.save_data()

func _update_shop_ui() -> void:
	gold_label.text = "골드  " + str(SaveManager.gold)

	var hp_cost = (SaveManager.upgrade_max_hp + 1) * 100
	var dmg_cost = (SaveManager.upgrade_damage + 1) * 100
	var spd_cost = (SaveManager.upgrade_speed + 1) * 100

	hp_upgrade_btn.text = "응급 장갑  ·  Lv %d  ·  %d G" % [SaveManager.upgrade_max_hp, hp_cost]
	dmg_upgrade_btn.text = "탄약 개조  ·  Lv %d  ·  %d G" % [SaveManager.upgrade_damage, dmg_cost]
	spd_upgrade_btn.text = "기동 부츠  ·  Lv %d  ·  %d G" % [SaveManager.upgrade_speed, spd_cost]

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
	RunStats.start_run(path.get_file().get_basename())

	# Clear Autoload states before launching a new game
	ObjectPoolManager.clear()
	SpatialGrid.clear()

	get_tree().change_scene_to_file(path)
