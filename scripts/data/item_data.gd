class_name ItemData
extends Resource

# res://scripts/data/item_data.gd
# Data schema for inventory and world items

enum Category { RESOURCE, MATERIAL, EQUIPMENT }
enum RegionTag { CITY, FOREST, BOTH }

@export var id: StringName
@export var display_name: String
@export var category: Category = Category.RESOURCE
@export_range(1, 999) var max_stack: int = 1
@export var icon: Texture2D
@export var region_tag: RegionTag = RegionTag.BOTH
@export_range(0, 1000) var meta_value: int = 1
