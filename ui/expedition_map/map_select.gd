class_name MapSelect
extends Control

# res://ui/expedition_map/map_select.gd
# Map selection UI allowing player to choose between Forest and City expeditions

@onready var forest_button: Button = $Panel/VBoxContainer/ForestButton
@onready var city_button: Button = $Panel/VBoxContainer/CityButton

func _ready() -> void:
	if forest_button != null:
		forest_button.pressed.connect(_on_forest_selected)
	if city_button != null:
		city_button.pressed.connect(_on_city_selected)

func _on_forest_selected() -> void:
	_select_map(&"forest")

func _on_city_selected() -> void:
	_select_map(&"city")

func _select_map(map_id: StringName) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.request_expedition(map_id)
