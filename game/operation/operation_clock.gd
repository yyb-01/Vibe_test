class_name OperationClock
extends RefCounted

var logical_tick: int = 0

func reset() -> void:
	logical_tick = 0

func advance_tick() -> int:
	logical_tick += 1
	return logical_tick
