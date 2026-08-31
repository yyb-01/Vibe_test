extends Node

const SAVE_PATH = "user://save_data.cfg"

var gold: int = 0

# Permanent Upgrade Levels
var upgrade_max_hp: int = 0
var upgrade_speed: int = 0
var upgrade_damage: int = 0
var total_runs: int = 0
var best_time: float = 0.0
var highest_wave: int = 0
var pet_blueprints: Array[String] = []
var selected_pet: String = ""
var selected_character: String = "scavenger"
var selected_difficulty: String = "normal"
var endless_mode: bool = false
var selected_challenge: String = "none"
var completed_challenges: Array[String] = []
var screen_shake_enabled: bool = true
var master_volume: float = 0.8

func _ready() -> void:
	load_data()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Flush the latest gold and permanent upgrades before the executable closes.
		save_data()
		get_tree().quit()

func save_data() -> void:
	var config = ConfigFile.new()
	config.set_value("Meta", "gold", gold)
	config.set_value("Upgrades", "max_hp", upgrade_max_hp)
	config.set_value("Upgrades", "speed", upgrade_speed)
	config.set_value("Upgrades", "damage", upgrade_damage)
	config.set_value("Progress", "total_runs", total_runs)
	config.set_value("Progress", "best_time", best_time)
	config.set_value("Progress", "highest_wave", highest_wave)
	config.set_value("Progress", "pet_blueprints", pet_blueprints)
	config.set_value("Progress", "selected_pet", selected_pet)
	config.set_value("Settings", "screen_shake_enabled", screen_shake_enabled)
	config.set_value("Settings", "selected_character", selected_character)
	config.set_value("Settings", "selected_difficulty", selected_difficulty)
	config.set_value("Settings", "endless_mode", endless_mode)
	config.set_value("Settings", "selected_challenge", selected_challenge)
	config.set_value("Progress", "completed_challenges", completed_challenges)
	config.set_value("Settings", "master_volume", master_volume)
	config.save(SAVE_PATH)

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return # Safe fallback to default values

	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		gold = config.get_value("Meta", "gold", 0)
		upgrade_max_hp = config.get_value("Upgrades", "max_hp", 0)
		upgrade_speed = config.get_value("Upgrades", "speed", 0)
		upgrade_damage = config.get_value("Upgrades", "damage", 0)
		total_runs = config.get_value("Progress", "total_runs", 0)
		best_time = config.get_value("Progress", "best_time", 0.0)
		highest_wave = config.get_value("Progress", "highest_wave", 0)
		pet_blueprints.clear()
		for blueprint in config.get_value("Progress", "pet_blueprints", []):
			if blueprint is String:
				pet_blueprints.append(blueprint)
		selected_pet = config.get_value("Progress", "selected_pet", "")
		if not selected_pet.is_empty() and selected_pet not in pet_blueprints:
			selected_pet = ""
		screen_shake_enabled = config.get_value("Settings", "screen_shake_enabled", true)
		selected_character = config.get_value("Settings", "selected_character", "scavenger")
		selected_difficulty = config.get_value("Settings", "selected_difficulty", "normal")
		endless_mode = config.get_value("Settings", "endless_mode", false)
		selected_challenge = config.get_value("Settings", "selected_challenge", "none")
		completed_challenges.clear()
		for challenge in config.get_value("Progress", "completed_challenges", []):
			if challenge is String:
				completed_challenges.append(challenge)
		master_volume = config.get_value("Settings", "master_volume", 0.8)

func record_run(summary: Dictionary) -> void:
	total_runs += 1
	highest_wave = maxi(highest_wave, int(summary.get("wave", 1)))
	var run_time := float(summary.get("time", 0.0))
	if run_time > best_time:
		best_time = run_time
	save_data()

func add_gold(amount: int) -> void:
	gold += amount
	save_data()
	EventBus.gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		save_data()
		EventBus.gold_changed.emit(gold)
		return true
	return false

func unlock_pet_blueprint(blueprint_id: String) -> void:
	if blueprint_id in pet_blueprints:
		return
	pet_blueprints.append(blueprint_id)
	save_data()

func complete_challenge(challenge_id: String, reward: int) -> bool:
	if challenge_id.is_empty() or challenge_id == "none" or challenge_id in completed_challenges:
		return false
	completed_challenges.append(challenge_id)
	add_gold(reward)
	return true
