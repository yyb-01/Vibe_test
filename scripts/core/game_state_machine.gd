class_name GameStateMachine
extends RefCounted

# res://scripts/core/game_state_machine.gd
# Small state machine class managing allowed game state transitions

enum State {
	HUB,
	EXPEDITION,
	EVENING_PREP,
	NIGHT_DEFENSE,
	DAY_SUMMARY
}

const STATE_NAMES: Dictionary = {
	State.HUB: "HUB",
	State.EXPEDITION: "EXPEDITION",
	State.EVENING_PREP: "EVENING_PREP",
	State.NIGHT_DEFENSE: "NIGHT_DEFENSE",
	State.DAY_SUMMARY: "DAY_SUMMARY"
}

const VALID_TRANSITIONS: Dictionary = {
	State.HUB: [State.EXPEDITION],
	State.EXPEDITION: [State.EVENING_PREP, State.DAY_SUMMARY],
	State.EVENING_PREP: [State.NIGHT_DEFENSE],
	State.NIGHT_DEFENSE: [State.DAY_SUMMARY],
	State.DAY_SUMMARY: [State.HUB]
}

var current_state: State = State.HUB
var is_transitioning: bool = false

signal state_changed(from_state: State, to_state: State)

func can_transition_to(target_state: State) -> bool:
	if is_transitioning:
		return false
	if current_state == target_state:
		return false
	var allowed: Array = VALID_TRANSITIONS.get(current_state, [])
	return target_state in allowed

func begin_transition(target_state: State) -> bool:
	if not can_transition_to(target_state):
		return false
	is_transitioning = true
	return true

func finish_transition(target_state: State) -> void:
	if not is_transitioning:
		return
	var prev: State = current_state
	current_state = target_state
	is_transitioning = false
	state_changed.emit(prev, current_state)

func cancel_transition() -> void:
	is_transitioning = false

func transition_to(target_state: State) -> bool:
	if not begin_transition(target_state):
		return false
	finish_transition(target_state)
	return true
