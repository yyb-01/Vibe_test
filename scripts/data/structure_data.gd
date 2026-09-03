class_name StructureData
extends Resource

# res://scripts/data/structure_data.gd
# Data schema for base structures per Section C.4 of game_system_architecture.md

enum Kind { BARRICADE, BARBED_WIRE, TURRET, TRAP, CORE }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.BARRICADE
@export var scene: PackedScene
@export var footprint: Vector2i = Vector2i.ONE
@export var required_materials: Dictionary = {} # item_id: StringName -> amount: int
@export_range(1, 100000) var max_health: int = 100
@export_range(0.0, 4096.0) var attack_range: float = 0.0
@export_range(0.0, 100000.0) var attack_damage: float = 0.0
@export_range(0.0, 100.0) var attacks_per_second: float = 0.0
@export var blocks_navigation: bool = true
