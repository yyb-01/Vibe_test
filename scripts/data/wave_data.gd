class_name WaveData
extends Resource

# res://scripts/data/wave_data.gd
# Night wave definition per Section C.5 of game_system_architecture.md

@export_range(1, 10000) var day: int = 1
@export var entries: Array = [] # Array of WaveSpawnEntryData
@export_range(0.0, 3600.0) var completion_delay: float = 3.0

func get_total_zombies_count() -> int:
	var total: int = 0
	for entry in entries:
		if entry != null and "count" in entry:
			total += int(entry.count)
	return total
