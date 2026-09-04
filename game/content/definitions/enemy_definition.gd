class_name EnemyDefinition
extends ContentDefinition

@export var presentation_id: StringName = &"scavenger"
@export_range(1, 9999) var max_health: int = 1
@export_range(1, 9999) var attack_damage: int = 1
@export_range(1, 9999) var attack_cooldown_ticks: int = 10
@export var drop_item_id: StringName = &""
@export_range(0, 9999) var drop_amount: int = 0
