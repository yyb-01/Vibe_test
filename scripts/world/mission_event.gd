class_name MissionEvent
extends Area2D

enum State { AVAILABLE, ACTIVE, COMPLETE }

var mission_kind: String = ""
var mission_title: String = ""
var state: State = State.AVAILABLE
var player: Player
var manager: SpawnManager
var target_positions: Array[Vector2] = []
var target_index: int = 0
var progress: float = 0.0
var action_timer: float = 0.0
var pressure_timer: float = 0.0
var route_start: Vector2
var route_end: Vector2
var branch_name: String = ""
var pressure_interval_mult: float = 1.0
var reward_gold_mult: float = 1.0
var bonus_reward_rolls: int = 1
var choice_layer: CanvasLayer
var default_branch: Dictionary = {}
var choice_generation: int = 0

const ACTIVE_RADIUS := 210.0

func _ready() -> void:
	add_to_group("mission_event")
	body_entered.connect(_on_body_entered)
	monitoring = true
	queue_redraw()

func configure_for_map(map_id: String) -> void:
	manager = get_tree().get_first_node_in_group("spawn_manager") as SpawnManager
	player = get_tree().get_first_node_in_group("player") as Player
	match map_id:
		"map_1":
			mission_kind = "escort"
			mission_title = "구조 차량 호송"
			route_start = Vector2(7200, 3980)
			route_end = Vector2(8460, 4680)
			global_position = route_start
		"map_2":
			mission_kind = "generators"
			mission_title = "봉쇄선 재가동"
			target_positions = [Vector2(6200, 3280), Vector2(8200, 3280), Vector2(8200, 5200)]
			global_position = target_positions[0]
		"map_3":
			mission_kind = "samples"
			mission_title = "감염 샘플 회수"
			target_positions = [Vector2(3600, 1880), Vector2(7600, 5200), Vector2(11600, 2480)]
			global_position = target_positions[0]
		"map_4":
			mission_kind = "hack"
			mission_title = "보스 데이터 해킹"
			target_positions = [Vector2(5200, 2640)]
			global_position = target_positions[0]
		_:
			queue_free()
			return
	queue_redraw()
	_emit_status("접근하면 시작", 0.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_activate()

func _process(delta: float) -> void:
	if state == State.COMPLETE or not is_instance_valid(player):
		return
	if state == State.AVAILABLE:
		if global_position.distance_to(player.global_position) <= ACTIVE_RADIUS:
			_activate()
		return
	if branch_name.is_empty() and not is_instance_valid(choice_layer):
		_select_default_branch()

	pressure_timer = maxf(0.0, pressure_timer - delta)
	action_timer = maxf(0.0, action_timer - delta)
	if pressure_timer <= 0.0:
		_spawn_pressure()
		pressure_timer = (1.45 if mission_kind != "escort" else 1.8) * pressure_interval_mult

	match mission_kind:
		"escort": _process_escort(delta)
		"generators": _process_generator(delta)
		"samples": _process_samples(delta)
		"hack": _process_hack(delta)
	queue_redraw()

func _activate() -> void:
	if state != State.AVAILABLE:
		return
	state = State.ACTIVE
	progress = 0.0
	EventBus.combat_modifier_changed.emit(mission_title, _mission_start_message(), 3.0)
	_show_branch_choices()

func _show_branch_choices() -> void:
	var branches: Array[Dictionary] = [
		{"name": "안전 우선", "description": "적의 압박이 25% 느려집니다.\n골드 80% · 무작위 보상 1회", "pressure": 1.25, "gold": 0.8, "rolls": 1, "color": Color(0.3, 0.9, 0.72, 1.0)},
		{"name": "현장 수색", "description": "표준 난이도로 임무를 수행합니다.\n골드 100% · 무작위 보상 2회", "pressure": 1.0, "gold": 1.0, "rolls": 2, "color": Color(0.35, 0.78, 1.0, 1.0)},
		{"name": "위험 감수", "description": "적의 압박이 30% 빨라집니다.\n골드 140% · 무작위 보상 3회", "pressure": 0.7, "gold": 1.4, "rolls": 3, "color": Color(1.0, 0.38, 0.28, 1.0)}
	]
	default_branch = branches[1].duplicate(true)
	branches.shuffle()
	choice_layer = CanvasLayer.new()
	choice_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	choice_layer.layer = 90
	var scene_root := get_tree().current_scene
	if not is_instance_valid(scene_root):
		choice_layer.free()
		choice_layer = null
		_select_default_branch()
		return
	scene_root.add_child(choice_layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.position = Vector2(-480, 24)
	panel.size = Vector2(960, 260)
	choice_layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)
	var title := Label.new()
	title.text = mission_title + "  ·  실시간 작전 선택 (8초 후 현장 수색)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	content.add_child(title)
	var hint := Label.new()
	hint.text = "위험이 클수록 완료 보상 후보가 늘어납니다. 보상은 임무 완료 시 무작위로 결정됩니다."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.68, 0.82, 0.82, 1.0))
	content.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	var first_button: Button
	for branch in branches:
		var button := Button.new()
		button.custom_minimum_size = Vector2(280, 140)
		button.text = "%s\n\n%s" % [branch.name, branch.description]
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", branch.color)
		button.pressed.connect(_select_branch.bind(branch))
		row.add_child(button)
		if not first_button:
			first_button = button
	if first_button:
		first_button.call_deferred("grab_focus")
	choice_generation += 1
	get_tree().create_timer(8.0).timeout.connect(_select_default_if_pending.bind(choice_generation))
	_emit_status("실시간 작전 시작  ·  분기 선택 8초", 0.0)

func _select_branch(branch: Dictionary) -> void:
	if not branch_name.is_empty():
		return
	choice_generation += 1
	branch_name = String(branch.name)
	pressure_interval_mult = float(branch.pressure)
	reward_gold_mult = float(branch.gold)
	bonus_reward_rolls = int(branch.rolls)
	if is_instance_valid(choice_layer):
		choice_layer.queue_free()
	choice_layer = null
	ModalManager.release(self)
	_emit_status("%s  ·  진행 중" % branch_name, progress)
	AudioManager.play_named("level_up", -8.0)

func _select_default_if_pending(generation: int) -> void:
	if generation == choice_generation and branch_name.is_empty():
		_select_default_branch()

func _select_default_branch() -> void:
	if default_branch.is_empty():
		default_branch = {"name": "현장 수색", "pressure": 1.0, "gold": 1.0, "rolls": 2}
	_select_branch(default_branch)

func _unhandled_input(event: InputEvent) -> void:
	if branch_name.is_empty() and is_instance_valid(choice_layer) and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_SPACE]:
			get_viewport().set_input_as_handled()
			_select_default_branch()

func _exit_tree() -> void:
	if is_instance_valid(choice_layer):
		choice_layer.queue_free()
	ModalManager.release(self)

func _mission_start_message() -> String:
	match mission_kind:
		"escort": return "구조 차량 호송 시작! 주변을 방어하세요"
		"generators": return "봉쇄선 재가동 시작! 발전기를 지키세요"
		"samples": return "감염 샘플 회수 시작! 회수 지점을 확보하세요"
		_: return "보스 데이터 해킹 시작! 단말기를 방어하세요"

func _process_escort(delta: float) -> void:
	var distance := global_position.distance_to(player.global_position)
	if distance <= 340.0:
		progress = minf(1.0, progress + delta / 38.0)
	else:
		progress = maxf(0.0, progress - delta / 9.0)
	global_position = route_start.lerp(route_end, progress)
	_emit_status("차량을 따라가세요  %d%%" % int(progress * 100.0), progress)
	if progress >= 1.0:
		_complete(60, "rescue_hound")

func _process_generator(delta: float) -> void:
	var distance := global_position.distance_to(player.global_position)
	if distance <= 190.0:
		progress = minf(1.0, progress + delta / 5.5)
	else:
		progress = maxf(0.0, progress - delta / 3.0)
	_emit_status("발전기 %d/3  ·  수리 %d%%" % [target_index + 1, int(progress * 100.0)], (float(target_index) + progress) / 3.0)
	if progress >= 1.0:
		target_index += 1
		progress = 0.0
		if target_index >= target_positions.size():
			_complete(80, "")
		else:
			global_position = target_positions[target_index]

func _process_samples(delta: float) -> void:
	var distance := global_position.distance_to(player.global_position)
	if distance <= 165.0:
		progress = minf(1.0, progress + delta / 1.25)
	else:
		progress = maxf(0.0, progress - delta / 2.2)
	_emit_status("샘플 %d/3  ·  회수 %d%%" % [target_index + 1, int(progress * 100.0)], (float(target_index) + progress) / 3.0)
	if progress >= 1.0:
		target_index += 1
		progress = 0.0
		if target_index >= target_positions.size():
			_complete(100, "toxic_crow")
		else:
			global_position = target_positions[target_index]

func _process_hack(delta: float) -> void:
	var distance := global_position.distance_to(player.global_position)
	if distance <= 190.0:
		progress = minf(1.0, progress + delta / 10.0)
	else:
		progress = maxf(0.0, progress - delta / 4.0)
	_emit_status("단말기 해킹  %d%%" % int(progress * 100.0), progress)
	if progress >= 1.0:
		if manager:
			manager.boss_data_hacked = true
		_complete(120, "lab_drone")

func _spawn_pressure() -> void:
	if not manager:
		manager = get_tree().get_first_node_in_group("spawn_manager") as SpawnManager
	if not manager:
		return
	var pool_id := "zombie_runner"
	match mission_kind:
		"escort": pool_id = "zombie_bomber" if randf() < 0.28 else "zombie_runner"
		"generators": pool_id = "zombie_spitter" if randf() < 0.42 else "zombie_runner"
		"samples": pool_id = "zombie_bloater" if randf() < 0.3 else "zombie_spitter"
		"hack": pool_id = "zombie_spitter" if randf() < 0.5 else "zombie_runner"
	var spawn_position := global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(270.0, 380.0)
	manager.spawn_event_enemy(pool_id, spawn_position)

func _complete(gold_reward: int, blueprint_id: String) -> void:
	if state == State.COMPLETE:
		return
	state = State.COMPLETE
	progress = 1.0
	RunStats.register_mission()
	RunStats.add_evolution_core()
	var blueprint_unlocked := false
	if not blueprint_id.is_empty():
		blueprint_unlocked = RunStats.add_pet_blueprint(blueprint_id)
	var final_gold := maxi(1, roundi(float(gold_reward) * reward_gold_mult))
	SaveManager.add_gold(final_gold)
	var random_rewards := _grant_random_rewards(bonus_reward_rolls)
	EventBus.mission_completed.emit(mission_title, final_gold)
	var reward_status := "완료  ·  %s  ·  진화 코어 +1" % branch_name
	if not blueprint_id.is_empty():
		reward_status += "  ·  %s" % ("새 펫 설계도 획득" if blueprint_unlocked else "펫 설계도 보유")
	if not random_rewards.is_empty():
		reward_status += "  ·  " + " / ".join(random_rewards)
	_emit_status(reward_status, 1.0)
	$CollisionShape2D.set_deferred("disabled", true)
	monitoring = false
	queue_redraw()

func _grant_random_rewards(roll_count: int) -> Array[String]:
	var rewards: Array[String] = []
	var pool: Array[String] = ["scrap", "heal", "gold", "damage", "speed", "core"]
	pool.shuffle()
	for index in mini(roll_count, pool.size()):
		match pool[index]:
			"scrap":
				RunStats.add_scrap(18)
				rewards.append("스크랩 +18")
			"heal":
				if is_instance_valid(player):
					player.heal(30)
				rewards.append("체력 +30")
			"gold":
				SaveManager.add_gold(25)
				rewards.append("추가 골드 +25")
			"damage":
				if is_instance_valid(player):
					player.damage_mult *= 1.08
				rewards.append("화력 +8%")
			"speed":
				if is_instance_valid(player):
					player.speed_mult *= 1.06
				rewards.append("이동 속도 +6%")
			"core":
				RunStats.add_evolution_core()
				rewards.append("진화 코어 +1")
	return rewards

func _emit_status(status: String, ratio: float) -> void:
	EventBus.mission_status_changed.emit(mission_title, status, ratio)

func _draw() -> void:
	if state == State.COMPLETE:
		draw_circle(Vector2.ZERO, 62.0, Color(0.25, 1.0, 0.65, 0.22))
		draw_arc(Vector2.ZERO, 68.0, 0.0, TAU, 40, Color(0.3, 1.0, 0.68, 0.8), 5.0, true)
		return
	var active_color := Color(1.0, 0.68, 0.24, 0.9) if state == State.ACTIVE else Color(0.35, 0.85, 1.0, 0.9)
	draw_circle(Vector2.ZERO, 54.0, Color(active_color, 0.18))
	draw_arc(Vector2.ZERO, 70.0, 0.0, TAU, 48, active_color, 5.0, true)
	if state == State.ACTIVE:
		draw_arc(Vector2.ZERO, 82.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, Color(1.0, 0.9, 0.35, 0.95), 8.0, true)
