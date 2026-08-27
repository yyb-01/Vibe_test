class_name HUD
extends CanvasLayer

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HBoxContainer/HPBar
@onready var exp_bar: ProgressBar = $MarginContainer/VBoxContainer/HBoxContainer/ExpBar
@onready var time_label: Label = $MarginContainer/VBoxContainer/WaveInfoBox/TimeLabel

var time_elapsed: float = 0.0

func _ready() -> void:
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.exp_changed.connect(_on_exp_changed)

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
