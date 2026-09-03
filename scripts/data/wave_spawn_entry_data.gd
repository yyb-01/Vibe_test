class_name WaveSpawnEntryData
extends Resource

# res://scripts/data/wave_spawn_entry_data.gd
# Spawn entry definition for waves per Section C.5 of game_system_architecture.md

enum EntryDirection { NORTH, EAST, SOUTH, WEST, RANDOM }

@export var zombie_id: StringName = &"zombie_basic"
@export_range(1, 10000) var count: int = 1
@export_range(0.05, 60.0) var spawn_interval: float = 1.0
@export var entry_direction: EntryDirection = EntryDirection.RANDOM
@export_range(0.0, 3600.0) var start_delay: float = 0.0
