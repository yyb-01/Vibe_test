extends Node

# Autoload: EventBus
# res://scripts/core/event_bus.gd
# Presentation-level event bus bridging authoritative domain events to Node signals.

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

# New DTO signal for multiplayer/loopback presentation presenters
signal domain_event_dispatched(event_dto: Dictionary)

func bridge_domain_event(ev: Dictionary) -> void:
	domain_event_dispatched.emit(ev)
	var ev_type: int = int(ev.get("event_type", 0))
	var payload: Dictionary = ev.get("payload", {})

	match ev_type:
		2007: # STRUCTURE_PLACED
			var cells_arr = payload.get("cells", [])
			var cells: Array[Vector2i] = []
			for c in cells_arr:
				cells.append(Vector2i(c[0], c[1]))
			structure_placed.emit(null, cells)

		2008: # STRUCTURE_REMOVED
			var cells_arr = payload.get("cells", [])
			var cells: Array[Vector2i] = []
			for c in cells_arr:
				cells.append(Vector2i(c[0], c[1]))
			structure_removed.emit(null, cells)

		2009: # INVENTORY_COMMITTED
			var cont := StringName(payload.get("container", "storage"))
			inventory_changed.emit(cont)

		2010: # PHASE_CHANGED
			var prev: int = int(payload.get("previous_phase", 0))
			var curr: int = int(payload.get("current_phase", 0))
			game_state_changed.emit(prev, curr)
			day_changed.emit(int(payload.get("day", 1)))

		2011: # WAVE_STARTED
			wave_started.emit(int(payload.get("day", 1)))

		2012: # WAVE_PROGRESS
			wave_progress.emit(
				int(payload.get("spawned", 0)),
				int(payload.get("total", 0)),
				int(payload.get("alive", 0))
			)

		2013: # WAVE_COMPLETED
			wave_completed.emit(int(payload.get("day", 1)))
