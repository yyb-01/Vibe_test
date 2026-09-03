extends Node

# Autoload: SaveManager
# res://scripts/core/save_manager.gd
# Compatibility facade over LocalSaveStore and SaveEnvelopeV3 migration pipeline.

const LocalSaveStoreClass = preload("res://scripts/infrastructure/persistence/local_save_store.gd")
const SaveEnvelopeV3Class = preload("res://scripts/infrastructure/persistence/save_envelope_v3.gd")
const SaveMigrationServiceClass = preload("res://scripts/infrastructure/persistence/save_migration_service.gd")

var _store: LocalSaveStoreClass = LocalSaveStoreClass.new()

func _ready() -> void:
	pass

func save_game(data: Dictionary) -> bool:
	# Convert raw save data to SaveEnvelopeV3
	var env := SaveMigrationServiceClass.migrate_to_v3(data)
	if env == null:
		printerr("SaveManager: Failed to create v3 save envelope from payload.")
		return false

	return _store.write_save(env)

func load_game() -> Dictionary:
	var env: SaveEnvelopeV3Class = _store.read_save()
	if env == null:
		return {}

	# Convert back to compatible dictionary for GameManager
	var payload := env.payload
	var session := payload.get("session", {})
	var meta := payload.get("meta_progress", {})
	var storage := payload.get("shared_storage", {})
	var build_grid := payload.get("build_grid", {})
	var day_start_snap := payload.get("day_start_snapshot", {})

	# Rebuild structures array
	var structs_array: Array = []
	var grid_structs = build_grid.get("structures", {})
	if grid_structs is Dictionary:
		for s_id in grid_structs:
			var s_info = grid_structs[s_id]
			structs_array.append({
				"id": s_info.get("definition_id", ""),
				"data_id": s_info.get("definition_id", ""),
				"cell": s_info.get("anchor_cell", [0, 0]),
				"anchor_cell": s_info.get("anchor_cell", [0, 0]),
				"rot": s_info.get("rotation_quarters", 0),
				"rotation_quarters": s_info.get("rotation_quarters", 0),
				"hp": 100.0,
				"current_health": 100.0
			})

	var result: Dictionary = {
		"version": 3,
		"schema_version": 3,
		"day": int(session.get("day", 1)),
		"state": str(session.get("phase", "HUB")),
		"game_state": str(session.get("phase", "HUB")),
		"meta": meta.duplicate(true),
		"storage": storage.duplicate(true),
		"structures": structs_array,
		"base_structures": structs_array,
		"day_start_snapshot": day_start_snap.duplicate(true),
		"legacy_scrap": int(meta.get("legacy_scrap", 0)),
		"unlocked_blueprints": meta.get("unlocked_blueprints", ["barricade_wood"])
	}
	return result

func has_save_file() -> bool:
	return _store.has_save()

func delete_save() -> void:
	_store.delete_all_saves()

func validate_save_data(data: Dictionary) -> bool:
	if not (data is Dictionary):
		return false
	var ver: int = int(data.get("version", data.get("schema_version", 0)))
	if ver < 2:
		return false
	return true
