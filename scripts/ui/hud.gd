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
@onready var inventory_box: VBoxContainer = $MarginContainer/VBoxContainer/InventoryBox
@onready var inventory_backplate: Panel = $InventoryBackplate
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
var banner_tween: Tween
var skill_bar: ProgressBar
var skill_label: Label
var build_status_label: Label
var build_toggle_button: Button

func _ready() -> void:
	_build_information_ui()
	pause_confirm.z_index = 100
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
	EventBus.combat_modifier_changed.connect(_on_combat_modifier_changed)
	boss_label.visible = false
	boss_warning_label.visible = false

func _build_information_ui() -> void:
	build_toggle_button = Button.new()
	build_toggle_button.position = Vector2(14, 86)
	build_toggle_button.size = Vector2(154, 34)
	build_toggle_button.text = "빌드 보기  [TAB]"
	build_toggle_button.add_theme_font_size_override("font_size", 13)
	build_toggle_button.tooltip_text = "무기·패시브·진화 조합 정보를 펼치거나 접습니다."
	build_toggle_button.pressed.connect(_toggle_build_panel)
	add_child(build_toggle_button)
	inventory_box.visible = false
	inventory_backplate.visible = false

	var objective_panel := PanelContainer.new()
	objective_panel.anchor_top = 1.0
	objective_panel.anchor_bottom = 1.0
	objective_panel.offset_left = 14.0
	objective_panel.offset_top = -134.0
	objective_panel.offset_right = 520.0
	objective_panel.offset_bottom = -48.0
	objective_panel.add_theme_stylebox_override("panel", _info_panel_style(Color(1.0, 0.58, 0.24, 0.75)))
	add_child(objective_panel)
	var objective_margin := MarginContainer.new()
	objective_margin.add_theme_constant_override("margin_left", 14)
	objective_margin.add_theme_constant_override("margin_top", 9)
	objective_margin.add_theme_constant_override("margin_right", 14)
	objective_margin.add_theme_constant_override("margin_bottom", 9)
	objective_panel.add_child(objective_margin)
	objective_label.reparent(objective_margin)
	objective_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	objective_label.add_theme_font_size_override("font_size", 13)

	var skill_panel := PanelContainer.new()
	skill_panel.anchor_left = 1.0
	skill_panel.anchor_top = 1.0
	skill_panel.anchor_right = 1.0
	skill_panel.anchor_bottom = 1.0
	skill_panel.offset_left = -358.0
	skill_panel.offset_top = -126.0
	skill_panel.offset_right = -18.0
	skill_panel.offset_bottom = -48.0
	skill_panel.add_theme_stylebox_override("panel", _info_panel_style(Color(0.3, 0.82, 1.0, 0.8)))
	add_child(skill_panel)
	var skill_content := VBoxContainer.new()
	skill_content.add_theme_constant_override("separation", 5)
	skill_panel.add_child(skill_content)
	skill_label = Label.new()
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.add_theme_font_size_override("font_size", 16)
	skill_content.add_child(skill_label)
	skill_bar = ProgressBar.new()
	skill_bar.custom_minimum_size = Vector2(320, 20)
	skill_bar.show_percentage = false
	skill_content.add_child(skill_bar)
	build_status_label = Label.new()
	build_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_status_label.add_theme_font_size_override("font_size", 13)
	build_status_label.add_theme_color_override("font_color", Color(0.7, 0.92, 1.0, 1.0))
	skill_content.add_child(build_status_label)

func _info_panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.025, 0.034, 0.78)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(8.0)
	return style

func _toggle_build_panel() -> void:
	var expanded := not inventory_box.visible
	inventory_box.visible = expanded
	inventory_backplate.visible = expanded
	build_toggle_button.text = ("빌드 접기" if expanded else "빌드 보기") + "  [TAB]"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not pause_confirm.visible and (event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB):
		get_viewport().set_input_as_handled()
		_toggle_build_panel()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	time_elapsed += delta
	var minutes := int(time_elapsed) / 60
	var seconds := int(time_elapsed) % 60
	time_label.text = "Time: %02d:%02d" % [minutes, seconds]
	wave_label.text = "WAVE %02d" % (int(time_elapsed / 30.0) + 1)
	threat_label.text = "위협 %03d" % _get_active_enemy_count()
	_update_objective_panel()
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		var fire_mode := "AUTO [F]" if player.auto_fire_enabled else "MANUAL [LMB]"
		var run_mode := "%s%s" % [RunStats.get_difficulty_name(), "·무한" if RunStats.endless_mode else ""]
		mode_label.text = "%s  ·  %s" % [run_mode, fire_mode]
		_update_skill_panel(player)

func _update_objective_panel() -> void:
	var lines: Array[String] = []
	var quest_text := "완료 +%dG" % RunStats.KILL_QUEST_REWARD if RunStats.quest_completed else "%d/%d" % [RunStats.kills, RunStats.KILL_QUEST_TARGET]
	lines.append("주요 목표  ·  구조 %d/1  ·  처치 의뢰 %s  ·  엘리트 %d/5" % [RunStats.survivors_rescued, quest_text, RunStats.elite_kills])
	if not mission_status.is_empty():
		lines.append("맵 사건  ·  " + mission_status)
	if RunStats.active_challenge != "none":
		lines.append("도전 과제  ·  %s  [%s]%s" % [RunStats.get_challenge_text(), RunStats.get_challenge_progress_text(), "  ✓" if RunStats.challenge_completed else ""])
	var support: Array[String] = []
	if not RunStats.companion_role.is_empty(): support.append("동료 " + _companion_display_name(RunStats.companion_role))
	if not RunStats.equipped_pet.is_empty(): support.append("펫 " + _pet_display_name(RunStats.equipped_pet))
	if not support.is_empty(): lines.append("지원 전력  ·  " + "  ·  ".join(support))
	objective_label.text = "\n".join(lines)

func _update_skill_panel(player: Player) -> void:
	var cooldown := player.get_unique_skill_cooldown()
	var max_cooldown := player.get_unique_skill_max_cooldown()
	skill_bar.max_value = max_cooldown
	skill_bar.value = max_cooldown - cooldown
	var state := "사용 가능" if cooldown <= 0.0 else "%.1f초" % cooldown
	skill_label.text = "[SPACE]  %s  ·  %s" % [player.get_unique_skill_name(), state]
	skill_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.72, 1.0) if cooldown <= 0.0 else Color(0.62, 0.82, 1.0, 1.0))
	var doctrines := player.get_active_build_labels()
	build_status_label.text = "전투 교리: 없음" if doctrines.is_empty() else "전투 교리: " + " / ".join(doctrines)

func _on_gold_changed(total_gold: int) -> void:
	gold_label.text = "골드  %d" % total_gold

func _on_scrap_changed(total_scrap: int) -> void:
	scrap_label.text = "스크랩  %d" % total_scrap

func _on_wave_started(wave: int) -> void:
	if wave_banner.visible:
		return
	wave_banner.text = "WAVE %02d  ·  위협 단계 상승" % wave
	wave_banner.modulate = Color(0.65, 1.0, 0.85, 1.0)
	wave_banner.visible = true
	_start_banner_fade(1.35)

func _on_combat_modifier_changed(title: String, description: String, duration: float) -> void:
	wave_banner.text = "%s\n%s  ·  %.0f초" % [title, description, duration]
	wave_banner.add_theme_font_size_override("font_size", 23)
	wave_banner.modulate = Color(1.0, 0.72, 0.3, 1.0)
	wave_banner.visible = true
	_start_banner_fade(2.4)

func _start_banner_fade(hold_time: float) -> void:
	if banner_tween:
		banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.tween_interval(hold_time)
	banner_tween.tween_property(wave_banner, "modulate:a", 0.0, 0.65)
	banner_tween.tween_callback(func() -> void:
		wave_banner.visible = false
		wave_banner.modulate.a = 1.0
		wave_banner.add_theme_font_size_override("font_size", 26)
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
		var weapon_text := "◆ %s Lv%d" % [w.get_display_name(), w.current_level]
		if w.evolved:
			weapon_text = "★ %s Lv%d" % [w.get_display_name(), w.current_level]
		elif w.can_evolve(get_tree().get_first_node_in_group("player") as Player):
			weapon_text += " [진화 가능]"
		elif w.current_level >= Weapon.MAX_LEVEL:
			weapon_text += " [필요: %s]" % w.get_evolution_requirement_text()
		weapon_names.append(weapon_text)
	weapons_label.text = "무장  ·  " + "   |   ".join(weapon_names)

	var passive_names: Array[String] = []
	for p in passives:
		passive_names.append(p.perk_name)
	var p_text := "생존 개조  ·  " + "  |  ".join(passive_names)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.active_synergies.size() > 0:
		p_text += "\n전투 교리  ·  " + ", ".join(PackedStringArray(player.get_active_build_labels()))
	var build_hint := player.get_next_build_hint() if player else ""
	if not build_hint.is_empty():
		p_text += "\n다음 조합  ·  " + build_hint
	passives_label.text = p_text
	weapons_label.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0, 1.0))
	passives_label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.82, 1.0) if player and not player.active_synergies.is_empty() else Color(0.72, 0.78, 0.78, 1.0))

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
