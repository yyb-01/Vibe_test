extends Node

# Autoload: SaveManager
# res://scripts/core/save_manager.gd
# Atomic JSON serialization and backup management per Section D.5 of game_system_architecture.md

const SAVE_PATH: String = "user://save.json"
const BACKUP_PATH: String = "user://save.json.bak"
const TMP_PATH: String = "user://save.json.tmp"

func _ready() -> void:
	pass

func save_game(data: Dictionary) -> bool:
	# Add schema v2 envelope
	var payload: Dictionary = data.duplicate(true)
	payload["version"] = 2
	payload["timestamp"] = int(Time.get_unix_time_from_system())
	
	var json_str: String = JSON.stringify(payload, "\t")
	
	# Step 1: Write to temporary file
	var tmp_file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if tmp_file == null:
		printerr("SaveManager: Failed to open TMP_PATH for writing: ", FileAccess.get_open_error())
		return false
	tmp_file.store_string(json_str)
	tmp_file.flush()
	tmp_file.close()
	
	# Step 2: Backup existing save
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
			
	# Step 3: Atomic replace: copy tmp to save
	var copy_err = DirAccess.copy_absolute(ProjectSettings.globalize_path(TMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))
	if copy_err != OK:
		printerr("SaveManager: Failed to commit save file: ", copy_err)
		_try_restore_backup()
		return false
		
	# Step 4: Verify integrity
	if not _verify_save_file(SAVE_PATH):
		printerr("SaveManager: Written file failed integrity check. Restoring backup.")
		_try_restore_backup()
		return false
		
	return true

func load_game() -> Dictionary:
	var path_to_load: String = SAVE_PATH
	if not FileAccess.file_exists(path_to_load):
		if FileAccess.file_exists(BACKUP_PATH):
			path_to_load = BACKUP_PATH
		elif FileAccess.file_exists("user://saves/slot_01.json"):
			path_to_load = "user://saves/slot_01.json"
		else:
			return {}
			
	var file := FileAccess.open(path_to_load, FileAccess.READ)
	if file == null:
		printerr("SaveManager: Failed to open file for read: ", path_to_load)
		return {}
		
	var content: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_err := json.parse(content)
	if parse_err != OK:
		printerr("SaveManager: Corrupted JSON: ", json.get_error_message())
		_preserve_corrupted_file(path_to_load)
		return _try_load_valid_backup()
		
	var data = json.data
	if not (data is Dictionary) or not validate_save_data(data):
		printerr("SaveManager: Save data failed schema or ID validation.")
		_preserve_corrupted_file(path_to_load)
		return _try_load_valid_backup()
		
	return data

func validate_save_data(data: Dictionary) -> bool:
	if not (data is Dictionary):
		return false
	if data.get("version", 0) < 2:
		return false
	if not ("day" in data) or not ("state" in data or "game_state" in data):
		return false
	if not ("storage" in data and data["storage"] is Dictionary):
		return false
	if not ("structures" in data or "base_structures" in data):
		return false
		
	# Validate item IDs
	var storage_dict: Dictionary = data.get("storage", {})
	for item_id in storage_dict.keys():
		var path = "res://data/items/%s.tres" % str(item_id)
		if not ResourceLoader.exists(path):
			printerr("SaveManager: Unknown item ID: ", item_id)
			return false
			
	# Validate structure IDs
	var structs_list: Array = data.get("structures", data.get("base_structures", []))
	for struct_info in structs_list:
		if not (struct_info is Dictionary):
			return false
		var struct_id = struct_info.get("id", struct_info.get("data_id", ""))
		if struct_id != "":
			var path = "res://data/structures/%s.tres" % str(struct_id)
			if not ResourceLoader.exists(path):
				printerr("SaveManager: Unknown structure ID: ", struct_id)
				return false
				
	return true

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH) or FileAccess.file_exists("user://saves/slot_01.json")

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))
	if FileAccess.file_exists("user://saves/slot_01.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/slot_01.json"))

func _verify_save_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(text) != OK:
		return false
	if not (json.data is Dictionary):
		return false
	return validate_save_data(json.data)

func _preserve_corrupted_file(path: String) -> void:
	var corrupt_path: String = path + ".corrupted"
	if not FileAccess.file_exists(corrupt_path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(corrupt_path))

func _try_restore_backup() -> void:
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP_PATH), ProjectSettings.globalize_path(SAVE_PATH))

func _try_load_valid_backup() -> Dictionary:
	if FileAccess.file_exists(BACKUP_PATH):
		var file := FileAccess.open(BACKUP_PATH, FileAccess.READ)
		if file != null:
			var text: String = file.get_as_text()
			file.close()
			var json := JSON.new()
			if json.parse(text) == OK and json.data is Dictionary:
				if validate_save_data(json.data):
					return json.data
	return {}
