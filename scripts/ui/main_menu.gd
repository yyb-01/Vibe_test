class_name MainMenu
extends CanvasLayer

@onready var map_1_btn: Button = $CenterContainer/VBoxContainer/Map1Button
@onready var map_2_btn: Button = $CenterContainer/VBoxContainer/Map2Button

func _ready() -> void:
	map_1_btn.pressed.connect(func() -> void: _load_map("res://scenes/maps/map_1.tscn"))
	map_2_btn.pressed.connect(func() -> void: _load_map("res://scenes/maps/map_2.tscn"))

func _load_map(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
