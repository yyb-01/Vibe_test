class_name ItemData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_range(1, 99, 1) var max_level: int = 5

