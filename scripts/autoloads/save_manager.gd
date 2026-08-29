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
var selected_character: String = "scavenger"
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
	config.set_value("Settings", "screen_shake_enabled", screen_shake_enabled)
	config.set_value("Settings", "selected_character", selected_character)
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
		screen_shake_enabled = config.get_value("Settings", "screen_shake_enabled", true)
		selected_character = config.get_value("Settings", "selected_character", "scavenger")
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
