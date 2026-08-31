extends Node

var run_active: bool = false
var map_id: String = ""
var elapsed_time: float = 0.0
var kills: int = 0
var damage_taken: int = 0
var damage_dealt: int = 0
var critical_hits: int = 0
var executions: int = 0
var survivors_rescued: int = 0
var supply_caches_opened: int = 0
var elite_kills: int = 0
var scrap: int = 0
var scrap_multiplier: float = 1.0
var companion_role: String = ""
var missions_completed: int = 0
var evolution_cores: int = 0
var pet_blueprints: Array[String] = []
var equipped_pet: String = ""
var current_wave: int = 1
var quest_completed: bool = false
var difficulty: String = "normal"
var endless_mode: bool = false
var active_challenge: String = "none"
var challenge_completed: bool = false
const KILL_QUEST_TARGET: int = 25
const KILL_QUEST_REWARD: int = 100

func start_run(new_map_id: String) -> void:
	run_active = true
	map_id = new_map_id
	elapsed_time = 0.0
	kills = 0
	damage_taken = 0
	damage_dealt = 0
	critical_hits = 0
	executions = 0
	survivors_rescued = 0
	supply_caches_opened = 0
	elite_kills = 0
	scrap = 0
	scrap_multiplier = 1.0
	companion_role = ""
	missions_completed = 0
	evolution_cores = 0
	pet_blueprints.clear()
	pet_blueprints.append_array(SaveManager.pet_blueprints)
	equipped_pet = SaveManager.selected_pet if SaveManager.selected_pet in pet_blueprints else ""
	EventBus.scrap_changed.emit(scrap)
	current_wave = 1
	quest_completed = false
	difficulty = SaveManager.selected_difficulty
	endless_mode = SaveManager.endless_mode
	active_challenge = SaveManager.selected_challenge
	challenge_completed = false

func _process(delta: float) -> void:
	if run_active and not get_tree().paused:
		elapsed_time += delta
		var new_wave := int(elapsed_time / 30.0) + 1
		if new_wave != current_wave:
			current_wave = new_wave
			_check_challenge()

func register_kill() -> void:
	kills += 1
	if not quest_completed and kills >= KILL_QUEST_TARGET:
		quest_completed = true
		SaveManager.add_gold(KILL_QUEST_REWARD)
		EventBus.quest_completed.emit("horde_breaker", KILL_QUEST_REWARD)

func register_damage(amount: int) -> void:
	damage_taken += amount
	_check_challenge()

func register_combat_hit(amount: int, hit_kind: String) -> void:
	damage_dealt += maxi(0, amount)
	if hit_kind == "critical":
		critical_hits += 1
	elif hit_kind == "execute":
		executions += 1

func register_rescue() -> void:
	survivors_rescued += 1
	_check_challenge()

func set_companion(role: String) -> void:
	companion_role = role

func register_mission() -> void:
	missions_completed += 1
	_check_challenge()

func add_evolution_core(amount: int = 1) -> void:
	evolution_cores += maxi(0, amount)

func consume_evolution_core() -> bool:
	if evolution_cores <= 0:
		return false
	evolution_cores -= 1
	return true

func add_pet_blueprint(blueprint_id: String) -> bool:
	if blueprint_id not in pet_blueprints:
		pet_blueprints.append(blueprint_id)
		SaveManager.unlock_pet_blueprint(blueprint_id)
		return true
	return false

func register_supply_cache() -> void:
	supply_caches_opened += 1
	_check_challenge()

func register_elite_kill() -> void:
	elite_kills += 1
	_check_challenge()
	if elite_kills == 5:
		SaveManager.add_gold(75)
		EventBus.quest_completed.emit("elite_breaker", 75)

func add_scrap(amount: int) -> void:
	if amount <= 0:
		return
	scrap += maxi(1, int(round(float(amount) * scrap_multiplier)))
	EventBus.scrap_changed.emit(scrap)

func spend_scrap(amount: int) -> bool:
	if amount <= 0 or scrap < amount:
		return false
	scrap -= amount
	EventBus.scrap_changed.emit(scrap)
	return true

func finish_run() -> Dictionary:
	run_active = false
	return get_summary()

func get_summary() -> Dictionary:
	_check_challenge()
	return {
		"map_id": map_id,
		"time": elapsed_time,
		"kills": kills,
		"damage_taken": damage_taken,
		"damage_dealt": damage_dealt,
		"critical_hits": critical_hits,
		"executions": executions,
		"survivors_rescued": survivors_rescued,
		"supply_caches_opened": supply_caches_opened,
		"elite_kills": elite_kills,
		"wave": current_wave,
		"missions_completed": missions_completed,
		"evolution_cores": evolution_cores,
		"pet_blueprints": pet_blueprints.duplicate(),
		"equipped_pet": equipped_pet,
		"difficulty": difficulty,
		"endless_mode": endless_mode,
		"challenge": active_challenge,
		"challenge_completed": challenge_completed
	}

func get_difficulty_health_mult() -> float:
	match difficulty:
		"easy": return 0.72
		"hard": return 1.45
		"nightmare": return 2.15
		_: return 1.0

func get_difficulty_damage_mult() -> float:
	match difficulty:
		"easy": return 0.75
		"hard": return 1.35
		"nightmare": return 1.8
		_: return 1.0

func get_difficulty_spawn_mult() -> float:
	match difficulty:
		"easy": return 0.78
		"hard": return 1.28
		"nightmare": return 1.65
		_: return 1.0

func get_difficulty_name() -> String:
	match difficulty:
		"easy": return "쉬움"
		"hard": return "어려움"
		"nightmare": return "악몽"
		_: return "보통"

func get_challenge_text() -> String:
	match active_challenge:
		"untouchable": return "철인: 피해 100 이하로 웨이브 8 도달"
		"elite_hunter": return "정예 사냥꾼: 엘리트 10기 처치"
		"mission_master": return "현장 전문가: 사건·구조·보급 목표 2개 완료"
		"endless_15": return "끝없는 밤: 무한 모드 웨이브 15 도달"
		_: return "없음"

func get_challenge_progress_text() -> String:
	match active_challenge:
		"untouchable": return "웨이브 %d/8 · 피해 %d/100" % [mini(current_wave, 8), damage_taken]
		"elite_hunter": return "엘리트 %d/10" % mini(elite_kills, 10)
		"mission_master": return "현장 목표 %d/2" % mini(missions_completed + survivors_rescued + supply_caches_opened, 2)
		"endless_15": return "웨이브 %d/15" % mini(current_wave, 15)
		_: return ""

func _check_challenge() -> void:
	if challenge_completed or active_challenge == "none":
		return
	match active_challenge:
		"untouchable": challenge_completed = current_wave >= 8 and damage_taken <= 100
		"elite_hunter": challenge_completed = elite_kills >= 10
		"mission_master": challenge_completed = missions_completed + survivors_rescued + supply_caches_opened >= 2
		"endless_15": challenge_completed = endless_mode and current_wave >= 15
	if challenge_completed:
		SaveManager.complete_challenge(active_challenge, 300)
		EventBus.quest_completed.emit(active_challenge, 300)
