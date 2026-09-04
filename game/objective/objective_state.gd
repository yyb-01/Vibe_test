class_name ObjectiveState
extends RefCounted

enum Lifecycle { LOCKED, AVAILABLE, ACTIVE, COMPLETED, FAILED }

var objectives: Dictionary = {}
var completed_objective_ids: Array = []
var active_objective_id: StringName = &""
var revision: int = 0
