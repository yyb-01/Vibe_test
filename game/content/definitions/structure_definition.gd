class_name StructureDefinition
extends ContentDefinition

@export var footprint: Array = [Vector2i.ZERO]
@export var occupied_channels: Array = [&"SOLID"]
@export var connection_group: StringName = &"wall"
@export var compatible_groups: Array = [&"wall"]
@export var cost_item_id: StringName = &"wood"
@export_range(1, 9999) var cost_amount: int = 1
@export_range(1, 9999) var max_health: int = 5
@export var blocks_player: bool = true
@export var blocks_enemy: bool = true
