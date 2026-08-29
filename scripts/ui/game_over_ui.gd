class_name GameOverUI
extends CanvasLayer

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var gold_label: Label = $CenterContainer/VBoxContainer/GoldLabel
@onready var summary_label: Label = $CenterContainer/VBoxContainer/SummaryLabel
@onready var return_btn: Button = $CenterContainer/VBoxContainer/ReturnButton
var summary_recorded: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.game_over.connect(_on_game_over)
	return_btn.pressed.connect(_on_return_pressed)

func _on_game_over(is_victory: bool) -> void:
	get_tree().paused = true
	visible = true
	var summary := RunStats.get_summary()
	if not summary_recorded:
		SaveManager.record_run(summary)
		RunStats.finish_run()
		summary_recorded = true

	if is_victory:
		title_label.text = "VICTORY"
		title_label.add_theme_color_override("font_color", Color.GOLD)
		# Save gold state automatically triggered during boss death logic
	else:
		title_label.text = "GAME OVER"
		title_label.add_theme_color_override("font_color", Color.RED)

	gold_label.text = "Total Gold: " + str(SaveManager.gold)
	var total_seconds := int(summary.get("time", 0.0))
	summary_label.text = "생존 %02d:%02d  ·  처치 %d  ·  웨이브 %02d  ·  구조 %d" % [total_seconds / 60, total_seconds % 60, int(summary.get("kills", 0)), int(summary.get("wave", 1)), int(summary.get("survivors_rescued", 0))]
	SaveManager.save_data()

func _on_return_pressed() -> void:
	get_tree().paused = false
	ObjectPoolManager.clear()
	SpatialGrid.clear()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
