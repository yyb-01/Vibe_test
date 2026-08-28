extends Node

const SAVE_PATH = "user://save_data.cfg"

var gold: int = 0

# Permanent Upgrade Levels
var upgrade_max_hp: int = 0
var upgrade_speed: int = 0
var upgrade_damage: int = 0

func _ready() -> void:
	load_data()

func save_data() -> void:
	var config = ConfigFile.new()
	config.set_value("Meta", "gold", gold)
	config.set_value("Upgrades", "max_hp", upgrade_max_hp)
	config.set_value("Upgrades", "speed", upgrade_speed)
	config.set_value("Upgrades", "damage", upgrade_damage)
	config.save(SAVE_PATH)

func load_data() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		gold = config.get_value("Meta", "gold", 0)
		upgrade_max_hp = config.get_value("Upgrades", "max_hp", 0)
		upgrade_speed = config.get_value("Upgrades", "speed", 0)
		upgrade_damage = config.get_value("Upgrades", "damage", 0)

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
