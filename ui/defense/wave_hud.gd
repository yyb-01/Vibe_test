class_name WaveHUD
extends Control

# res://ui/defense/wave_hud.gd
# Real-time wave progress and zombie count display

@onready var wave_label: Label = $Panel/VBoxContainer/WaveLabel
@onready var progress_label: Label = $Panel/VBoxContainer/ProgressLabel

func _ready() -> void:
	var eb = get_node_or_null("/root/EventBus")
	if eb != null:
		eb.wave_started.connect(_on_wave_started)
		eb.wave_progress.connect(_on_wave_progress)
		eb.wave_completed.connect(_on_wave_completed)

func _on_wave_started(day: int) -> void:
	visible = true
	if wave_label != null:
		wave_label.text = "NIGHT DEFENSE: DAY %d" % day
	if progress_label != null:
		progress_label.text = "Zombies: Preparing..."

func _on_wave_progress(spawned: int, total: int, alive: int) -> void:
	if progress_label != null:
		progress_label.text = "Remaining: %d / %d (Alive: %d)" % [total - spawned + alive, total, alive]

func _on_wave_completed(_day: int) -> void:
	if progress_label != null:
		progress_label.text = "DEFENSE SUCCESSFUL!"
