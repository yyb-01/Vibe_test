class_name HUD
extends CanvasLayer

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HBoxContainer/HPBar
@onready var exp_bar: ProgressBar = $MarginContainer/VBoxContainer/HBoxContainer/ExpBar
@onready var time_label: Label = $MarginContainer/VBoxContainer/WaveInfoBox/TimeLabel
@onready var mode_label: Label = $MarginContainer/VBoxContainer/WaveInfoBox/ModeLabel
@onready var wave_label: Label = $MarginContainer/VBoxContainer/WaveInfoBox/WaveLabel
@onready var weapons_label: Label = $MarginContainer/VBoxContainer/InventoryBox/WeaponsLabel
@onready var passives_label: Label = $MarginContainer/VBoxContainer/InventoryBox/PassivesLabel
@onready var objective_label: Label = $MarginContainer/VBoxContainer/ObjectiveLabel
@onready var gold_label: Label = $GoldLabel
@onready var threat_label: Label = $ThreatLabel
@onready var wave_banner: Label = $WaveBanner
@onready var pause_confirm: Control = $PauseConfirm
@onready var pause_confirm_button: Button = $PauseConfirm/Panel/VBoxContainer/Buttons/ConfirmButton
@onready var pause_cancel_button: Button = $PauseConfirm/Panel/VBoxContainer/Buttons/CancelButton

var time_elapsed: float = 0.0

func _ready() -> void:
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.exp_changed.connect(_on_exp_changed)
	EventBus.inventory_updated.connect(_on_inventory_updated)
	EventBus.gold_changed.connect(_on_gold_changed)
	pause_confirm_button.pressed.connect(_confirm_return_to_menu)
	pause_cancel_button.pressed.connect(_cancel_return_to_menu)
	_on_gold_changed(SaveManager.gold)
	EventBus.wave_started.connect(_on_wave_started)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	time_elapsed += delta
	var minutes := int(time_elapsed) / 60
	var seconds := int(time_elapsed) % 60
	time_label.text = "Time: %02d:%02d" % [minutes, seconds]
	wave_label.text = "WAVE %02d" % (int(time_elapsed / 30.0) + 1)
	threat_label.text = "위협 %03d" % _get_active_enemy_count()
	objective_label.text = "구조 신호: %d/1" % RunStats.survivors_rescued
	if RunStats.map_id in ["map_3", "map_4"]:
		objective_label.text += "  ·  보급품: %d/1" % RunStats.supply_caches_opened
	if not RunStats.quest_completed:
		objective_label.text += "  ·  처치 의뢰: %d/%d" % [RunStats.kills, RunStats.KILL_QUEST_TARGET]
	else:
		objective_label.text += "  ·  처치 의뢰 완료 +%dG" % RunStats.KILL_QUEST_REWARD
	objective_label.text += "  ·  엘리트: %d/5" % RunStats.elite_kills
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		mode_label.text = "AUTO [F]" if player.auto_fire_enabled else "MANUAL [LMB]"

func _on_gold_changed(total_gold: int) -> void:
	gold_label.text = "골드  %d" % total_gold

func _on_wave_started(wave: int) -> void:
	wave_banner.text = "WAVE %02d  ·  위협 단계 상승" % wave
	wave_banner.modulate = Color(0.65, 1.0, 0.85, 1.0)
	wave_banner.visible = true
	var tween := create_tween()
	tween.tween_interval(1.35)
	tween.tween_property(wave_banner, "modulate:a", 0.0, 0.65)
	tween.tween_callback(func() -> void:
		wave_banner.visible = false
		wave_banner.modulate.a = 1.0
	)

func _get_active_enemy_count() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is CanvasItem and is_instance_valid(enemy) and enemy.process_mode != Node.PROCESS_MODE_DISABLED and enemy.visible:
			count += 1
	return count

func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_bar.get_node("HPLabel").text = "HP  %d / %d" % [current_hp, max_hp]

func _on_exp_changed(current_exp: int, required_exp: int, level: int) -> void:
	exp_bar.max_value = required_exp
	exp_bar.value = current_exp
	exp_bar.get_node("LevelLabel").text = "Lv " + str(level)

func _on_inventory_updated(weapons: Array, passives: Array) -> void:
	var weapon_names: Array[String] = []
	for w in weapons:
		weapon_names.append(w.get_display_name() + " Lv" + str(w.current_level))
	weapons_label.text = "무장  ·  " + "  |  ".join(weapon_names)

	var passive_names: Array[String] = []
	for p in passives:
		passive_names.append(p.perk_name)
	var p_text := "생존 개조  ·  " + "  |  ".join(passive_names)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.active_synergies.size() > 0:
		p_text += "\n시너지  ·  " + ", ".join(PackedStringArray(player.active_synergies))
	passives_label.text = p_text

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if pause_confirm.visible:
			_cancel_return_to_menu()
		else:
			_show_return_confirmation()

func _show_return_confirmation() -> void:
	pause_confirm.visible = true
	get_tree().paused = true
	pause_confirm_button.grab_focus()

func _cancel_return_to_menu() -> void:
	pause_confirm.visible = false
	get_tree().paused = false

func _confirm_return_to_menu() -> void:
	SaveManager.save_data()
	if RunStats.run_active:
		SaveManager.record_run(RunStats.get_summary())
		RunStats.finish_run()
	ObjectPoolManager.clear()
	SpatialGrid.clear()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
