extends Node

var run_active: bool = false
var map_id: String = ""
var elapsed_time: float = 0.0
var kills: int = 0
var damage_taken: int = 0
var survivors_rescued: int = 0
var supply_caches_opened: int = 0
var elite_kills: int = 0
var current_wave: int = 1
var quest_completed: bool = false
const KILL_QUEST_TARGET: int = 25
const KILL_QUEST_REWARD: int = 100

func start_run(new_map_id: String) -> void:
	run_active = true
	map_id = new_map_id
	elapsed_time = 0.0
	kills = 0
	damage_taken = 0
	survivors_rescued = 0
	supply_caches_opened = 0
	elite_kills = 0
	current_wave = 1
	quest_completed = false

func _process(delta: float) -> void:
	if run_active and not get_tree().paused:
		elapsed_time += delta
		current_wave = int(elapsed_time / 30.0) + 1

func register_kill() -> void:
	kills += 1
	if not quest_completed and kills >= KILL_QUEST_TARGET:
		quest_completed = true
		SaveManager.add_gold(KILL_QUEST_REWARD)
		EventBus.quest_completed.emit("horde_breaker", KILL_QUEST_REWARD)

func register_damage(amount: int) -> void:
	damage_taken += amount

func register_rescue() -> void:
	survivors_rescued += 1

func register_supply_cache() -> void:
	supply_caches_opened += 1

func register_elite_kill() -> void:
	elite_kills += 1
	if elite_kills == 5:
		SaveManager.add_gold(75)
		EventBus.quest_completed.emit("elite_breaker", 75)

func finish_run() -> Dictionary:
	run_active = false
	return get_summary()

func get_summary() -> Dictionary:
	return {
		"map_id": map_id,
		"time": elapsed_time,
		"kills": kills,
		"damage_taken": damage_taken,
		"survivors_rescued": survivors_rescued,
		"supply_caches_opened": supply_caches_opened,
		"elite_kills": elite_kills,
		"wave": current_wave
	}
