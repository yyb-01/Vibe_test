class_name OperationState
extends RefCounted

enum Lifecycle { CREATING, INSERTION, ACTIVE, EXTRACTION, RESOLVING, CLOSED }
enum EndReason { NONE, COMPLETED, ABANDONED, PLAYER_DISABLED, CORE_DESTROYED }

signal lifecycle_changed(previous: int, current: int)

var operation_id: StringName
var definition_id: StringName
var lifecycle_state: Lifecycle = Lifecycle.CREATING
var logical_tick: int = 0
var seed: int = 0
var end_reason: EndReason = EndReason.NONE
var revision: int = 0
var inventory_state
var build_state
var combat_state
var objective_state
var threat_state
var extraction_eligible: bool = false

func _init(next_operation_id: StringName, next_definition_id: StringName, next_seed: int) -> void:
	operation_id = next_operation_id
	definition_id = next_definition_id
	seed = next_seed

func transition_to(next: int) -> bool:
	if not _can_transition_to(next):
		return false
	var previous := lifecycle_state
	lifecycle_state = next
	revision += 1
	lifecycle_changed.emit(previous, next)
	return true

func _can_transition_to(next: int) -> bool:
	match lifecycle_state:
		Lifecycle.CREATING:
			return next == Lifecycle.INSERTION
		Lifecycle.INSERTION:
			return next == Lifecycle.ACTIVE
		Lifecycle.ACTIVE:
			return next == Lifecycle.EXTRACTION or next == Lifecycle.RESOLVING
		Lifecycle.EXTRACTION:
			return next == Lifecycle.RESOLVING
		Lifecycle.RESOLVING:
			return next == Lifecycle.CLOSED

	return false
