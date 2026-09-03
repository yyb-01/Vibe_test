extends Node

# Autoload: GameManager
# res://scripts/core/game_manager.gd
# Core gameplay loop controller, snapshot rollback, meta progression, and save/load per Section D.1 & F.4

const GameStateMachine = preload("res://scripts/core/game_state_machine.gd")

var state_machine: GameStateMachine = GameStateMachine.new()

var current_state: int:
	get:
		return state_machine.current_state

var day: int = 1
var selected_map_id: StringName = &"forest"
var day_result: Dictionary = {}

# Meta progression
var legacy_scrap: int = 0
var survivor_xp: int = 0
var survivor_level: int = 1
var unlocked_blueprints: Array[StringName] = [&"barricade_wood"]

# Snapshot for failure rollback (Section F.4)
var day_start_snapshot: Dictionary = {}

# Structures manager reference if in base scene
var active_building_system: Node = null

# Stats tracking for Day Summary
var day_stats: Dictionary = {
	"zombies_killed": 0,
	"ammo_consumed": 0,
	"structures_lost": 0,
	"items_harvested": {}
}

func _ready() -> void:
	state_machine.state_changed.connect(_on_state_changed)
	create_day_start_snapshot()

func _on_state_changed(prev: int, curr: int) -> void:
	EventBus.game_state_changed.emit(prev, curr)
	if curr == GameStateMachine.State.HUB:
		create_day_start_snapshot()

func request_expedition(map_id: StringName) -> bool:
	if not state_machine.can_transition_to(GameStateMachine.State.EXPEDITION):
		return false
	if state_machine.transition_to(GameStateMachine.State.EXPEDITION):
		selected_map_id = map_id
		day_stats["items_harvested"].clear()
		return true
	return false

func complete_expedition(success: bool) -> void:
	if success:
		# Track items harvested
		for slot in InventoryManager.expedition_bag.slots:
			var item_id = slot.get("item_id", &"")
			var amount = slot.get("amount", 0)
			day_stats["items_harvested"][item_id] = day_stats["items_harvested"].get(item_id, 0) + amount
				
		InventoryManager.unload_bag_to_storage()
		state_machine.transition_to(GameStateMachine.State.EVENING_PREP)
	else:
		# Calculate lost bag value for failure settlement (Section F.4)
		var lost_items: Dictionary = {}
		for slot in InventoryManager.expedition_bag.slots:
			var item_id = slot.get("item_id", &"")
			var amount = slot.get("amount", 0)
			lost_items[item_id] = lost_items.get(item_id, 0) + amount
				
		var scrap_gain: int = settle_failure(lost_items)
		legacy_scrap += scrap_gain
		
		day_result = {
			"day": day,
			"survived": false,
			"reason": &"expedition_failed",
			"legacy_scrap_earned": scrap_gain,
			"stats": day_stats.duplicate(true)
		}
		
		InventoryManager.clear_bag()
		state_machine.transition_to(GameStateMachine.State.DAY_SUMMARY)

func start_night() -> bool:
	return state_machine.transition_to(GameStateMachine.State.NIGHT_DEFENSE)

func complete_night(survived: bool) -> void:
	if survived:
		day_result = {
			"day": day,
			"survived": true,
			"reason": &"victory",
			"legacy_scrap_earned": 0,
			"stats": day_stats.duplicate(true)
		}
	else:
		# Night defense failed: calculate failure compensation
		var lost_val: Dictionary = InventoryManager.storage.duplicate()
		var scrap_gain: int = settle_failure(lost_val)
		legacy_scrap += scrap_gain
		
		day_result = {
			"day": day,
			"survived": false,
			"reason": &"night_defense_failed",
			"legacy_scrap_earned": scrap_gain,
			"stats": day_stats.duplicate(true)
		}
		
	state_machine.transition_to(GameStateMachine.State.DAY_SUMMARY)

func confirm_summary() -> void:
	var survived: bool = day_result.get("survived", true)
	if survived:
		day += 1
		_reset_day_stats()
		save_current_game()
		state_machine.transition_to(GameStateMachine.State.HUB)
	else:
		# Rollback on defeat: restore day start snapshot while preserving legacy scrap & blueprints
		rollback_to_day_start_snapshot()
		_reset_day_stats()
		save_current_game()
		state_machine.transition_to(GameStateMachine.State.HUB)

func settle_failure(acquired_or_lost_items: Dictionary) -> int:
	# 10% value conversion to legacy_scrap per Section F.4
	var total_items_count: int = 0
	for item_id in acquired_or_lost_items:
		total_items_count += int(acquired_or_lost_items[item_id])
	return maxi(1, int(ceil(total_items_count * 0.1)))

func create_day_start_snapshot() -> void:
	day_start_snapshot = {
		"day": day,
		"storage": InventoryManager.storage.duplicate(),
		"unlocked_blueprints": unlocked_blueprints.duplicate(),
		"legacy_scrap": legacy_scrap,
		"structures": get_structures_data()
	}

func rollback_to_day_start_snapshot() -> void:
	if day_start_snapshot.is_empty():
		return
	day = day_start_snapshot.get("day", day)
	InventoryManager.storage = day_start_snapshot.get("storage", {}).duplicate()
	# Preserve earned legacy scrap and newly unlocked blueprints
	restore_structures_data(day_start_snapshot.get("structures", []))

func get_difficulty_scale() -> float:
	# Section F.1: scale = 1.0 + (day - 1) * 0.25
	return 1.0 + float(day - 1) * 0.25

func get_scaled_zombie_count(base_count: int) -> int:
	return int(ceil(float(base_count) * get_difficulty_scale()))

func get_scaled_zombie_hp(base_hp: float) -> float:
	return base_hp * (1.0 + float(day - 1) * 0.15)

func _reset_day_stats() -> void:
	day_stats = {
		"zombies_killed": 0,
		"ammo_consumed": 0,
		"structures_lost": 0,
		"items_harvested": {}
	}

# Structure serialization for save/load & snapshots
func get_structures_data() -> Array:
	var result: Array = []
	if active_building_system != null and "build_grid" in active_building_system:
		var grid = active_building_system.build_grid
		var visited_nodes: Array = []
		for cell in grid.occupied_cells:
			var node = grid.occupied_cells[cell]
			if node != null and node not in visited_nodes:
				visited_nodes.append(node)
				var data_id = ""
				if "structure_data" in node and node.structure_data != null:
					data_id = str(node.structure_data.id)
				var anchor = node.anchor_cell if "anchor_cell" in node else cell
				var rot = node.rotation_quarters if "rotation_quarters" in node else 0
				var hp = node.current_health if "current_health" in node else 100.0
				result.append({
					"data_id": data_id,
					"anchor_cell": [anchor.x, anchor.y],
					"rotation_quarters": rot,
					"current_health": hp
				})
	return result

func get_structures_data_v2() -> Array:
	var result: Array = []
	if active_building_system != null and "build_grid" in active_building_system:
		var grid = active_building_system.build_grid
		var visited_nodes: Array = []
		for cell in grid.occupied_cells:
			var node = grid.occupied_cells[cell]
			if node != null and node not in visited_nodes:
				visited_nodes.append(node)
				var s_id = ""
				if "structure_data" in node and node.structure_data != null:
					s_id = str(node.structure_data.id)
				var anchor = node.anchor_cell if "anchor_cell" in node else cell
				var rot = node.rotation_quarters if "rotation_quarters" in node else 0
				var hp = node.current_health if "current_health" in node else 100.0
				result.append({
					"id": s_id,
					"cell": [anchor.x, anchor.y],
					"rot": rot,
					"hp": hp,
					"ammo": 0
				})
	return result

func restore_structures_data(structures_data: Array) -> void:
	if active_building_system == null or not active_building_system.has_method("try_place"):
		return
		
	# Clear existing structures
	if "build_grid" in active_building_system:
		var to_free: Array = []
		for cell in active_building_system.build_grid.occupied_cells:
			var node = active_building_system.build_grid.occupied_cells[cell]
			if node != null and node not in to_free:
				to_free.append(node)
		for node in to_free:
			active_building_system.remove_structure(node)
			
	for item in structures_data:
		var data_id = item.get("id", item.get("data_id", ""))
		var coords = item.get("cell", item.get("anchor_cell", [0, 0]))
		var anchor = Vector2i(coords[0], coords[1])
		var rot = int(item.get("rot", item.get("rotation_quarters", 0)))
		var hp = float(item.get("hp", item.get("current_health", -1.0)))
		var path = "res://data/structures/%s.tres" % data_id
		if ResourceLoader.exists(path):
			var res = load(path)
			active_building_system.try_place(res, anchor, rot, true)
			# Restore exact remaining health to placed structure
			if hp >= 0.0:
				var placed_node = active_building_system.build_grid.occupied_cells.get(anchor)
				if placed_node != null:
					if "current_health" in placed_node:
						placed_node.current_health = hp
					var hc = placed_node.find_child("HealthComponent", true, false)
					if hc != null:
						hc.current_health = hp

# Save & Load integration (Section D.5 & D.6)
func save_current_game() -> bool:
	if SaveManager == null:
		return false
	var state_name = GameStateMachine.STATE_NAMES.get(current_state, "HUB")
	var save_dict: Dictionary = {
		"version": 2,
		"day": day,
		"state": state_name,
		"game_state": state_name, # backward compatibility
		"meta": {
			"legacy_scrap": legacy_scrap,
			"survivor_xp": survivor_xp,
			"survivor_level": survivor_level,
			"unlocked_blueprints": unlocked_blueprints.duplicate()
		},
		"storage": InventoryManager.storage.duplicate(),
		"equipped": { "primary": "pistol" },
		"structures": get_structures_data_v2(),
		"base_structures": get_structures_data(), # backward compatibility
		"core_health": 1000.0,
		"day_start_snapshot": day_start_snapshot.duplicate(true),
		"legacy_scrap": legacy_scrap, # backward compatibility
		"unlocked_blueprints": unlocked_blueprints.duplicate(), # backward compatibility
		"stats": {
			"day_stats": day_stats.duplicate(true),
			"survivor_level": survivor_level,
			"survivor_xp": survivor_xp
		}
	}
	return SaveManager.save_game(save_dict)

func load_saved_game() -> bool:
	if SaveManager == null:
		return false
	var save_dict: Dictionary = SaveManager.load_game()
	if save_dict.is_empty():
		return false
		
	day = int(save_dict.get("day", 1))
	var meta_data = save_dict.get("meta", {})
	if meta_data is Dictionary:
		legacy_scrap = int(meta_data.get("legacy_scrap", save_dict.get("legacy_scrap", 0)))
		survivor_xp = int(meta_data.get("survivor_xp", 0))
		survivor_level = int(meta_data.get("survivor_level", 1))
		var bps = meta_data.get("unlocked_blueprints", save_dict.get("unlocked_blueprints", ["barricade_wood"]))
		unlocked_blueprints.clear()
		if bps is Array:
			for bp in bps:
				unlocked_blueprints.append(StringName(bp))
	else:
		legacy_scrap = int(save_dict.get("legacy_scrap", 0))
		var bps = save_dict.get("unlocked_blueprints", ["barricade_wood"])
		unlocked_blueprints.clear()
		if bps is Array:
			for bp in bps:
				unlocked_blueprints.append(StringName(bp))
	
	if "storage" in save_dict and save_dict["storage"] is Dictionary:
		InventoryManager.storage = save_dict["storage"].duplicate()
			
	var structs_data = save_dict.get("structures", save_dict.get("base_structures", []))
	restore_structures_data(structs_data)
	
	if "day_start_snapshot" in save_dict and save_dict["day_start_snapshot"] is Dictionary:
		day_start_snapshot = save_dict["day_start_snapshot"].duplicate(true)
		
	return true

