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

const ACTIVE_RADIUS := 210.0

func _ready() -> void:
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

	pressure_timer = maxf(0.0, pressure_timer - delta)
	action_timer = maxf(0.0, action_timer - delta)
	if pressure_timer <= 0.0:
		_spawn_pressure()
		pressure_timer = 1.45 if mission_kind != "escort" else 1.8

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
	_emit_status("진행 중", progress)
	AudioManager.play_named("level_up", -8.0)

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
	SaveManager.add_gold(gold_reward)
	EventBus.mission_completed.emit(mission_title, gold_reward)
	var reward_status := "완료  ·  진화 코어 +1"
	if not blueprint_id.is_empty():
		reward_status += "  ·  %s" % ("새 펫 설계도 획득" if blueprint_unlocked else "펫 설계도 보유")
	_emit_status(reward_status, 1.0)
	$CollisionShape2D.set_deferred("disabled", true)
	monitoring = false
	queue_redraw()

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
