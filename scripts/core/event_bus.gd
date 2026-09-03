extends Node

# Autoload: EventBus
# res://scripts/core/event_bus.gd

signal game_state_changed(previous, current)
signal day_changed(day: int)
signal inventory_changed(container: StringName)
signal health_changed(entity: Node, current: float, maximum: float)
signal structure_placed(structure: Node, cells: Array[Vector2i])
signal structure_removed(structure: Node, cells: Array[Vector2i])
signal wave_started(day: int)
signal wave_progress(spawned: int, total: int, alive: int)
signal wave_completed(day: int)
signal meta_progress_changed(level: int, xp: int, legacy_scrap: int)
