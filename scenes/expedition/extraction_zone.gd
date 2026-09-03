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
@onready var floating_label: Label = get_node_or_null("FloatingLabel")
@onready var world_progress_bar: ProgressBar = get_node_or_null("WorldProgressBar")

var is_extracting: bool = false
var current_hold_time: float = 0.0
var extraction_done: bool = false

func _ready() -> void:
	collision_layer = 128 # Layer 8: Trigger
	collision_mask = 2    # Layer 2: Player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_ui_state()

func _process(delta: float) -> void:
	if extraction_done or not player_inside:
		return
		
	# Space belongs to the dash action; extraction deliberately remains hold-E.
	var holding: bool = Input.is_action_pressed("interact") or Input.is_key_pressed(KEY_E)
	if holding:
		if not is_extracting:
			is_extracting = true
			extraction_started.emit()
			if world_progress_bar != null:
				world_progress_bar.visible = true
		current_hold_time += delta
		var ratio: float = clampf(current_hold_time / required_interaction_time, 0.0, 1.0)
		if world_progress_bar != null:
			world_progress_bar.value = ratio * 100.0
		if floating_label != null:
			floating_label.text = "RETURNING... (%.1fs / %.1fs)" % [current_hold_time, required_interaction_time]
			
		extraction_progress.emit(current_hold_time, required_interaction_time)
		
		if current_hold_time >= required_interaction_time:
			_complete_extraction()
	else:
		if is_extracting:
			is_extracting = false
			current_hold_time = 0.0
			_update_ui_state()
			extraction_canceled.emit()

func _complete_extraction() -> void:
	if extraction_done:
		return
	extraction_done = true
	is_extracting = false
	if floating_label != null:
		floating_label.text = "EXTRACTION SUCCESS!"
	extraction_completed.emit()
	var gm = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.complete_expedition(true)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_inside = true
		_update_ui_state()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_inside = false
		if is_extracting:
			is_extracting = false
			current_hold_time = 0.0
			extraction_canceled.emit()
		_update_ui_state()

func _update_ui_state() -> void:
	if world_progress_bar != null:
		world_progress_bar.visible = is_extracting
		world_progress_bar.value = 0.0
	if floating_label != null:
		if player_inside:
			floating_label.text = "[ EXTRACTION POINT ]\n>> HOLD [E] TO RETURN <<"
			floating_label.modulate = Color(1.0, 1.0, 0.2)
		else:
			floating_label.text = "[ EXTRACTION POINT ]\nHold [E] to Return to Base"
			floating_label.modulate = Color(0.2, 1.0, 0.5)
