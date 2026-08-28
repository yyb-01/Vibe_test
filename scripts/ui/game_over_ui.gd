class_name GameOverUI
extends CanvasLayer

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var gold_label: Label = $CenterContainer/VBoxContainer/GoldLabel
@onready var return_btn: Button = $CenterContainer/VBoxContainer/ReturnButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.game_over.connect(_on_game_over)
	return_btn.pressed.connect(_on_return_pressed)

func _on_game_over(is_victory: bool) -> void:
	get_tree().paused = true
	visible = true

	if is_victory:
		title_label.text = "VICTORY"
		title_label.add_theme_color_override("font_color", Color.GOLD)
		# Save gold state automatically triggered during boss death logic
	else:
		title_label.text = "GAME OVER"
		title_label.add_theme_color_override("font_color", Color.RED)

	gold_label.text = "Total Gold: " + str(SaveManager.gold)
	SaveManager.save_data()

func _on_return_pressed() -> void:
	get_tree().paused = false
	ObjectPoolManager.clear()
	SpatialGrid.clear()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
