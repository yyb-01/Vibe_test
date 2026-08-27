class_name HUD
extends CanvasLayer

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HBoxContainer/HPBar
@onready var ammo_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/AmmoLabel
@onready var wave_label: Label = $MarginContainer/VBoxContainer/WaveInfoBox/WaveLabel
@onready var zombie_count_label: Label = $MarginContainer/VBoxContainer/WaveInfoBox/ZombieCountLabel
@onready var countdown_label: Label = $CenterContainer/CountdownLabel

var countdown_timer: Timer

func _ready() -> void:
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.ammo_changed.connect(_on_ammo_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.zombie_count_changed.connect(_on_zombie_count_changed)

	countdown_timer = Timer.new()
	countdown_timer.one_shot = true
	add_child(countdown_timer)

	countdown_label.hide()

func _process(_delta: float) -> void:
	if not countdown_timer.is_stopped():
		countdown_label.text = "Next Wave in: %.1f" % countdown_timer.time_left

func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp

func _on_ammo_changed(current_mag: int, reserve_ammo: int) -> void:
	ammo_label.text = "Ammo: %d / %d" % [current_mag, reserve_ammo]

func _on_wave_started(wave_number: int) -> void:
	countdown_timer.stop()
	countdown_label.hide()
	wave_label.text = "Wave: %d" % wave_number

func _on_wave_cleared(next_wave_delay: float) -> void:
	countdown_label.show()
	countdown_timer.start(next_wave_delay)
	zombie_count_label.text = "Zombies: 0"

func _on_zombie_count_changed(remaining_zombies: int) -> void:
	zombie_count_label.text = "Zombies: %d" % remaining_zombies
