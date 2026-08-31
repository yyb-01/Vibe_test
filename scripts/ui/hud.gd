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
@onready var scrap_label: Label = $ScrapLabel
@onready var threat_label: Label = $ThreatLabel
@onready var wave_banner: Label = $WaveBanner
@onready var boss_label: Label = $BossLabel
@onready var boss_warning_label: Label = $BossWarningLabel
var mission_status := ""
@onready var pause_confirm: Control = $PauseConfirm
@onready var pause_confirm_button: Button = $PauseConfirm/Panel/VBoxContainer/Buttons/ConfirmButton
@onready var pause_cancel_button: Button = $PauseConfirm/Panel/VBoxContainer/Buttons/CancelButton

var time_elapsed: float = 0.0
var boss_warning_tween: Tween

func _ready() -> void:
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.exp_changed.connect(_on_exp_changed)
	EventBus.inventory_updated.connect(_on_inventory_updated)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.scrap_changed.connect(_on_scrap_changed)
	pause_confirm_button.pressed.connect(_confirm_return_to_menu)
	pause_cancel_button.pressed.connect(_cancel_return_to_menu)
	_on_gold_changed(SaveManager.gold)
	_on_scrap_changed(RunStats.scrap)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.boss_status_changed.connect(_on_boss_status_changed)
	EventBus.boss_attack_warning.connect(_on_boss_attack_warning)
	EventBus.mission_status_changed.connect(_on_mission_status_changed)
	EventBus.mission_completed.connect(_on_mission_completed)
	boss_label.visible = false
	boss_warning_label.visible = false

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
	if not mission_status.is_empty():
		objective_label.text += "  ·  " + mission_status
	if not RunStats.companion_role.is_empty():
		objective_label.text += "  ·  동료: %s" % _companion_display_name(RunStats.companion_role)
	if not RunStats.equipped_pet.is_empty():
		objective_label.text += "  ·  펫: %s" % _pet_display_name(RunStats.equipped_pet)
	if RunStats.map_id in ["map_3", "map_4"]:
		objective_label.text += "  ·  보급품: %d/1" % RunStats.supply_caches_opened
	if not RunStats.quest_completed:
		objective_label.text += "  ·  처치 의뢰: %d/%d" % [RunStats.kills, RunStats.KILL_QUEST_TARGET]
	else:
		objective_label.text += "  ·  처치 의뢰 완료 +%dG" % RunStats.KILL_QUEST_REWARD
	objective_label.text += "  ·  엘리트: %d/5" % RunStats.elite_kills
	if RunStats.active_challenge != "none":
		objective_label.text += "  ·  도전: %s%s" % [RunStats.get_challenge_text(), " ✓" if RunStats.challenge_completed else ""]
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		var fire_mode := "AUTO [F]" if player.auto_fire_enabled else "MANUAL [LMB]"
		var skill_state := "준비" if player.get_unique_skill_cooldown() <= 0.0 else "%.1fs" % player.get_unique_skill_cooldown()
		var run_mode := "%s%s" % [RunStats.get_difficulty_name(), "·무한" if RunStats.endless_mode else ""]
		mode_label.text = "%s  ·  %s  ·  [SPACE] %s %s" % [run_mode, fire_mode, player.get_unique_skill_name(), skill_state]

func _on_gold_changed(total_gold: int) -> void:
	gold_label.text = "골드  %d" % total_gold

func _on_scrap_changed(total_scrap: int) -> void:
	scrap_label.text = "스크랩  %d" % total_scrap

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

func _companion_display_name(role: String) -> String:
	match role:
		"Medic": return "의무병"
		"Gunner": return "사수"
		"Scavenger": return "회수꾼"
		_: return role

func _pet_display_name(pet_id: String) -> String:
	match pet_id:
		"rescue_hound": return "구조견"
		"toxic_crow": return "독성 까마귀"
		"lab_drone": return "연구 드론"
		_: return pet_id

func _on_boss_status_changed(boss_name: String, health_ratio: float, phase: int) -> void:
	if health_ratio < 0.0:
		boss_label.visible = false
		return
	var segments := 18
	var filled := clampi(int(round(health_ratio * segments)), 0, segments)
	boss_label.text = "%s  ·  위상 %d  [%s%s]" % [boss_name, phase, "■".repeat(filled), "□".repeat(segments - filled)]
	boss_label.visible = true

func _on_boss_attack_warning(attack_name: String, active: bool) -> void:
	if boss_warning_tween:
		boss_warning_tween.kill()
	if not active:
		boss_warning_label.visible = false
		return
	match attack_name:
		"shockwave": boss_warning_label.text = "⚠ 충격파 준비 · 표시된 원 밖으로 이동"
		"charge": boss_warning_label.text = "⚠ 돌진 준비 · 붉은 선에서 이탈"
		"summon": boss_warning_label.text = "⚠ 증원 소환 · 표시된 지점을 비우기"
		_: boss_warning_label.text = "⚠ 보스 공격 준비"
	boss_warning_label.visible = true
	boss_warning_label.modulate.a = 1.0
	boss_warning_tween = create_tween()
	boss_warning_tween.set_loops()
	boss_warning_tween.tween_property(boss_warning_label, "modulate:a", 0.35, 0.22)
	boss_warning_tween.tween_property(boss_warning_label, "modulate:a", 1.0, 0.22)

func _on_mission_status_changed(title: String, status: String, _progress: float) -> void:
	mission_status = "%s: %s" % [title, status]

func _on_mission_completed(title: String, reward: int) -> void:
	mission_status = "%s 완료  ·  +%dG  ·  진화 코어 +1" % [title, reward]

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
		var weapon_text := w.get_display_name() + " Lv" + str(w.current_level)
		if w.current_level >= Weapon.MAX_LEVEL and not w.evolved:
			weapon_text += "  ·  진화 조합: " + w.get_evolution_requirement_text()
		weapon_names.append(weapon_text)
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
