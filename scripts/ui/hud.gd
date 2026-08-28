class_name HUD
extends CanvasLayer

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HBoxContainer/HPBar
@onready var exp_bar: ProgressBar = $MarginContainer/VBoxContainer/HBoxContainer/ExpBar
@onready var time_label: Label = $MarginContainer/VBoxContainer/WaveInfoBox/TimeLabel
@onready var weapons_label: Label = $MarginContainer/VBoxContainer/InventoryBox/WeaponsLabel
@onready var passives_label: Label = $MarginContainer/VBoxContainer/InventoryBox/PassivesLabel

var time_elapsed: float = 0.0

func _ready() -> void:
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.exp_changed.connect(_on_exp_changed)
	EventBus.inventory_updated.connect(_on_inventory_updated)

func _process(delta: float) -> void:
	time_elapsed += delta
	var minutes := int(time_elapsed) / 60
	var seconds := int(time_elapsed) % 60
	time_label.text = "Time: %02d:%02d" % [minutes, seconds]

func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp

func _on_exp_changed(current_exp: int, required_exp: int, level: int) -> void:
	exp_bar.max_value = required_exp
	exp_bar.value = current_exp
	exp_bar.get_node("LevelLabel").text = "Lv " + str(level)

func _on_inventory_updated(weapons: Array, passives: Array) -> void:
	var w_text = "Weapons: "
	for w in weapons:
		w_text += w.data.weapon_name + " (Lv " + str(w.current_level) + "), "
	weapons_label.text = w_text

	var p_text = "Passives: "
	for p in passives:
		p_text += p.perk_name + ", "
	passives_label.text = p_text

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().paused = false
		ObjectPoolManager.clear()
		SpatialGrid.clear()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
