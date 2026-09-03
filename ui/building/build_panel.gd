class_name BuildPanel
extends Control

# res://ui/building/build_panel.gd
# UI for selecting structures to place during EVENING_PREP

@export var building_system: IsometricGridBuildingSystem

@onready var wood_barricade_btn: Button = $Panel/VBoxContainer/WoodBarricadeBtn
@onready var metal_barricade_btn: Button = $Panel/VBoxContainer/MetalBarricadeBtn
@onready var turret_btn: Button = $Panel/VBoxContainer/TurretBtn
@onready var cancel_btn: Button = $Panel/VBoxContainer/CancelBtn

var _barricade_wood_data: StructureData
var _barricade_metal_data: StructureData
var _turret_basic_data: StructureData

func _ready() -> void:
	_barricade_wood_data = load("res://data/structures/barricade_wood.tres")
	_barricade_metal_data = load("res://data/structures/barricade_metal.tres")
	_turret_basic_data = load("res://data/structures/turret_basic.tres")
	
	if wood_barricade_btn != null:
		wood_barricade_btn.pressed.connect(func(): _select(_barricade_wood_data))
	if metal_barricade_btn != null:
		metal_barricade_btn.pressed.connect(func(): _select(_barricade_metal_data))
	if turret_btn != null:
		turret_btn.pressed.connect(func(): _select(_turret_basic_data))
	if cancel_btn != null:
		cancel_btn.pressed.connect(_cancel)

func _select(data: StructureData) -> void:
	if building_system != null and data != null:
		building_system.select_structure(data)

func _cancel() -> void:
	if building_system != null:
		building_system.clear_selection()
