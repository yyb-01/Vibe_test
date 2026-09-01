class_name GameOverUI
extends CanvasLayer

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var gold_label: Label = $CenterContainer/VBoxContainer/GoldLabel
@onready var summary_label: Label = $CenterContainer/VBoxContainer/SummaryLabel
@onready var return_btn: Button = $CenterContainer/VBoxContainer/ReturnButton
@onready var retry_btn: Button = $CenterContainer/VBoxContainer/RetryButton
var summary_recorded: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.game_over.connect(_on_game_over)
	return_btn.pressed.connect(_on_return_pressed)
	retry_btn.pressed.connect(_on_retry_pressed)

func _on_game_over(is_victory: bool) -> void:
	ModalManager.request(self, _show_game_over.bind(is_victory))

func _show_game_over(is_victory: bool) -> void:
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

	gold_label.text = "보유 골드  ·  " + str(SaveManager.gold)
	var total_seconds := int(summary.get("time", 0.0))
	var challenge_result := "달성" if bool(summary.get("challenge_completed", false)) else "미달성"
	var dealt := int(summary.get("damage_dealt", 0))
	var dps := float(dealt) / maxf(1.0, float(summary.get("time", 0.0)))
	var cause := "\n사망 원인  ·  " + String(summary.get("death_cause", "알 수 없음")) if not is_victory else ""
	summary_label.text = "%s%s%s\n생존  %02d:%02d     웨이브  %02d     처치  %d     엘리트  %d\n가한 피해  %d     평균 DPS  %.1f     받은 피해  %d\n치명타  %d     처형  %d     구조  %d     보급  %d\n도전 과제  ·  %s" % [RunStats.get_difficulty_name(), " · 무한 모드" if bool(summary.get("endless_mode", false)) else "", cause, total_seconds / 60, total_seconds % 60, int(summary.get("wave", 1)), int(summary.get("kills", 0)), int(summary.get("elite_kills", 0)), dealt, dps, int(summary.get("damage_taken", 0)), int(summary.get("critical_hits", 0)), int(summary.get("executions", 0)), int(summary.get("survivors_rescued", 0)), int(summary.get("supply_caches_opened", 0)), challenge_result]
	SaveManager.save_data()

func _on_return_pressed() -> void:
	ModalManager.clear()
	ObjectPoolManager.clear()
	SpatialGrid.clear()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_retry_pressed() -> void:
	var map_id := RunStats.map_id
	var map_path := "res://scenes/maps/%s.tscn" % map_id
	if not ResourceLoader.exists(map_path):
		map_id = "map_1"
		map_path = "res://scenes/maps/map_1.tscn"
	ModalManager.clear()
	ObjectPoolManager.clear()
	SpatialGrid.clear()
	RunStats.start_run(map_id)
	get_tree().change_scene_to_file(map_path)
