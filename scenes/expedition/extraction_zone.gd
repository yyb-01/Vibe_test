class_name ExtractionZone
extends Area2D

# res://scenes/expedition/extraction_zone.gd
# Extraction zone trigger per Section E.4 of game_system_architecture.md

signal extraction_started()
signal extraction_progress(current_time: float, total_time: float)
signal extraction_completed()
signal extraction_canceled()

@export var required_interaction_time: float = 2.0

var player_inside: bool = false
var is_extracting: bool = false
var current_hold_time: float = 0.0
var extraction_done: bool = false

func _ready() -> void:
	collision_layer = 128 # Layer 8: Trigger
	collision_mask = 2    # Layer 2: Player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if extraction_done or not player_inside:
		return
		
	# Check if player is holding interaction key (interact action, E or Space/Accept)
	var holding: bool = Input.is_action_pressed("interact") or Input.is_key_pressed(KEY_E) or Input.is_action_pressed("ui_accept")
	if holding:
		if not is_extracting:
			is_extracting = true
			extraction_started.emit()
		current_hold_time += delta
		extraction_progress.emit(current_hold_time, required_interaction_time)
		
		if current_hold_time >= required_interaction_time:
			_complete_extraction()
	else:
		if is_extracting:
			is_extracting = false
			current_hold_time = 0.0
			extraction_canceled.emit()

func _complete_extraction() -> void:
	if extraction_done:
		return
	extraction_done = true
	is_extracting = false
	extraction_completed.emit()
	GameManager.complete_expedition(true)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_inside = false
		if is_extracting:
			is_extracting = false
			current_hold_time = 0.0
			extraction_canceled.emit()
