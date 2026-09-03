extends Node

# Autoload: InventoryManager
# res://scripts/core/inventory_manager.gd
# Manages persistent storage and expedition bag per Section D.4

const InventoryClass = preload("res://scripts/systems/inventory.gd")

var storage: Dictionary = {} # item_id: StringName -> amount: int
var expedition_bag = null    # Inventory instance
var equipped: Dictionary = {}

var _item_cache: Dictionary = {}

func _ready() -> void:
	expedition_bag = InventoryClass.new(8)
	expedition_bag.contents_changed.connect(_on_bag_changed)

func _on_bag_changed() -> void:
	EventBus.inventory_changed.emit(&"bag")

func get_item_data(item_id: StringName) -> ItemData:
	if _item_cache.has(item_id):
		return _item_cache[item_id]
	var path: String = "res://data/items/%s.tres" % String(item_id)
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is ItemData:
			_item_cache[item_id] = res
			return res
	return null

func get_item_max_stack(item_id: StringName) -> int:
	var data: ItemData = get_item_data(item_id)
	if data != null:
		return data.max_stack
	return 50

func can_add_to_bag(item_id: StringName, amount: int) -> bool:
	if expedition_bag == null:
		return false
	var max_stack: int = get_item_max_stack(item_id)
	return expedition_bag.can_add(item_id, amount, max_stack)

func add_to_bag(item_id: StringName, amount: int) -> int:
	if expedition_bag == null or amount <= 0:
		return 0
	var max_stack: int = get_item_max_stack(item_id)
	return expedition_bag.add_item(item_id, amount, max_stack)

func remove_from_bag(item_id: StringName, amount: int) -> bool:
	if expedition_bag == null:
		return false
	return expedition_bag.remove_item(item_id, amount)

func get_bag_count(item_id: StringName) -> int:
	if expedition_bag == null:
		return 0
	return expedition_bag.get_item_count(item_id)

func unload_bag_to_storage() -> void:
	if expedition_bag == null:
		return
	var slots: Array[Dictionary] = expedition_bag.get_slots()
	for slot in slots:
		var id: StringName = slot.get("item_id", &"")
		var amount: int = int(slot.get("amount", 0))
		if id != &"" and amount > 0:
			storage[id] = int(storage.get(id, 0)) + amount
			
	expedition_bag.clear()
	EventBus.inventory_changed.emit(&"storage")
	EventBus.inventory_changed.emit(&"bag")

func clear_bag() -> void:
	if expedition_bag != null:
		expedition_bag.clear()
		EventBus.inventory_changed.emit(&"bag")

func has_materials(costs: Dictionary) -> bool:
	for item_id in costs:
		var req: int = int(costs[item_id])
		if int(storage.get(StringName(item_id), 0)) < req:
			return false
	return true

func consume_materials(costs: Dictionary) -> bool:
	if not has_materials(costs):
		return false
	for item_id in costs:
		var id: StringName = StringName(item_id)
		var req: int = int(costs[item_id])
		storage[id] = int(storage.get(id, 0)) - req
		if storage[id] <= 0:
			storage.erase(id)
	EventBus.inventory_changed.emit(&"storage")
	return true

func refund_materials(costs: Dictionary) -> void:
	for item_id in costs:
		var id: StringName = StringName(item_id)
		var amount: int = int(costs[item_id])
		storage[id] = int(storage.get(id, 0)) + amount
	EventBus.inventory_changed.emit(&"storage")

func to_save_data() -> Dictionary:
	var bag_data: Array = []
	if expedition_bag != null:
		bag_data = expedition_bag.to_dict()
	return {
		"storage": storage.duplicate(true),
		"bag": bag_data,
		"equipped": equipped.duplicate(true)
	}

func load_save_data(data: Dictionary) -> bool:
	if data.has("storage") and data["storage"] is Dictionary:
		storage = {}
		for k in data["storage"]:
			storage[StringName(k)] = int(data["storage"][k])
	if data.has("bag") and data["bag"] is Array and expedition_bag != null:
		expedition_bag.from_dict(data["bag"])
	if data.has("equipped") and data["equipped"] is Dictionary:
		equipped = data["equipped"].duplicate(true)
	EventBus.inventory_changed.emit(&"storage")
	EventBus.inventory_changed.emit(&"bag")
	return true

func sync_from_simulation(sim_storage: Dictionary, sim_bag_slots: Array = []) -> void:
	storage.clear()
	for k in sim_storage:
		storage[StringName(k)] = int(sim_storage[k])
	if expedition_bag != null and not sim_bag_slots.is_empty():
		expedition_bag.from_dict(sim_bag_slots)
	EventBus.inventory_changed.emit(&"storage")
	EventBus.inventory_changed.emit(&"bag")
