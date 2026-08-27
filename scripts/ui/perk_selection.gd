class_name PerkSelection
extends CanvasLayer

@onready var container: HBoxContainer = $CenterContainer/VBoxContainer/HBoxContainer
@onready var label: Label = $CenterContainer/VBoxContainer/TitleLabel

# Preload all perks
var available_perks: Array[PerkData] = [
	preload("res://data/perks/fast_hands.tres"),
	preload("res://data/perks/hollow_point.tres"),
	preload("res://data/perks/light_foot.tres"),
	preload("res://data/perks/piercing_rounds.tres"),
	preload("res://data/perks/heavy_caliber.tres")
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.perk_selection_requested.connect(_on_perk_selection_requested)

func _on_perk_selection_requested() -> void:
	# Pause game
	get_tree().paused = true
	visible = true

	# Clear existing children
	for child in container.get_children():
		child.queue_free()

	# Pick 3 unique random perks for this selection
	var shuffled := available_perks.duplicate()
	shuffled.shuffle()

	for i in range(3):
		if i < shuffled.size():
			_create_perk_button(shuffled[i])

func _create_perk_button(perk: PerkData) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(200, 300)
	btn.text = perk.perk_name + "\n\n" + perk.description
	# Enable rich text or just word wrap for description
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	btn.pressed.connect(func() -> void: _on_perk_selected(perk))
	container.add_child(btn)

func _on_perk_selected(perk: PerkData) -> void:
	visible = false
	get_tree().paused = false

	# Pass the perk back
	EventBus.perk_selected.emit(perk)
