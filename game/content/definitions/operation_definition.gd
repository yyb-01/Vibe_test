class_name OperationDefinition
extends ContentDefinition

@export var terrain_id: StringName
@export var starting_item_ids: Array = []
@export var seed: int = 1
@export var map_size: Vector2 = Vector2(640, 360)
@export var player_spawn: Vector2 = Vector2(-180, 0)
@export var core_position: Vector2 = Vector2.ZERO
@export_range(1.0, 1000.0) var player_speed: float = 160.0
@export_range(1, 9999) var player_pack_capacity: int = 8
@export_range(1, 9999) var core_storage_capacity: int = 64
@export_range(1, 9999) var core_max_health: int = 10
@export var enemy_definition_id: StringName = &"enemy_scavenger"
@export var enemy_spawn_cell: Vector2i = Vector2i(-8, 0)
@export var enemy_spawn_entries: Array = []
@export var enemy_spawn_waves: Array = []
@export var objective_id: StringName = &"secure_wood"
@export var objective_fact_type: StringName = &"ITEM_SECURED"
@export var objective_item_id: StringName = &"wood"
@export_range(1, 9999) var objective_amount: int = 1
@export var threat_fact_types: Array = [&"ITEM_ACQUIRED", &"ITEM_SECURED", &"STRUCTURE_COMPLETED"]
@export_range(1, 9999) var threat_pressure_per_action: int = 1
@export_range(1, 9999) var threat_pressure_threshold: int = 2
@export_range(1, 9999) var threat_event_duration_ticks: int = 10
@export var pickup_entries: Array = []
