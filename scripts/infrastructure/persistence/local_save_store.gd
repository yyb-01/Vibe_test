class_name LocalSaveStore
extends RefCounted

# res://scripts/infrastructure/persistence/local_save_store.gd
# Atomic file system persistence with backup rotation and SHA-256 verification.

const SaveEnvelopeV3Class = preload("res://scripts/infrastructure/persistence/save_envelope_v3.gd")
const SaveMigrationServiceClass = preload("res://scripts/infrastructure/persistence/save_migration_service.gd")

const SAVE_PATH: String = "user://save_v3.json"
const BACKUP_PATH: String = "user://save_v3.json.bak"
const TMP_PATH: String = "user://save_v3.json.tmp"

const LEGACY_V2_PATH: String = "user://save.json"

func write_save(envelope: SaveEnvelopeV3Class) -> bool:
	if envelope == null:
		return false

	envelope.integrity["digest"] = envelope.compute_sha256()
	var json_str := JSON.stringify(envelope.to_dict(), "\t")

	# Step 1: Write to .tmp file
	var tmp_file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if tmp_file == null:
		printerr("LocalSaveStore: Failed to open TMP_PATH for writing: ", FileAccess.get_open_error())
		return false
	tmp_file.store_string(json_str)
	tmp_file.flush()
	tmp_file.close()

	# Step 2: Verify tmp file read-back
	if not _verify_file(TMP_PATH):
		printerr("LocalSaveStore: Temporary save failed integrity verification.")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))
		return false

	# Step 3: Rotate existing save to backup
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))

	# Step 4: Atomic replace: tmp -> save
	var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(TMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))
	if err != OK:
		printerr("LocalSaveStore: Failed to commit save file: ", err)
		_try_restore_backup()
		return false

	return true

func read_save() -> SaveEnvelopeV3Class:
	var path_to_load := SAVE_PATH
	if not FileAccess.file_exists(path_to_load):
		if FileAccess.file_exists(BACKUP_PATH):
			path_to_load = BACKUP_PATH
		elif FileAccess.file_exists(LEGACY_V2_PATH):
			return _read_and_migrate_legacy()
		else:
			return null

	var file := FileAccess.open(path_to_load, FileAccess.READ)
	if file == null:
		return _try_read_backup_or_legacy()

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		_preserve_corrupted_file(path_to_load)
		return _try_read_backup_or_legacy()

	var data: Dictionary = json.data
	if SaveMigrationServiceClass.is_v3_envelope(data):
		var env := SaveEnvelopeV3Class.from_dict(data)
		if env.verify_integrity():
			return env
		else:
			printerr("LocalSaveStore: SHA-256 digest mismatch.")
			_preserve_corrupted_file(path_to_load)
			return _try_read_backup_or_legacy()
	else:
		# Auto-migrate
		var migrated := SaveMigrationServiceClass.migrate_to_v3(data)
		return migrated

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH) or FileAccess.file_exists(LEGACY_V2_PATH)

func delete_all_saves() -> void:
	for p in [SAVE_PATH, BACKUP_PATH, TMP_PATH, LEGACY_V2_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _read_and_migrate_legacy() -> SaveEnvelopeV3Class:
	var file := FileAccess.open(LEGACY_V2_PATH, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		return SaveMigrationServiceClass.migrate_to_v3(json.data)
	return null

func _try_read_backup_or_legacy() -> SaveEnvelopeV3Class:
	if FileAccess.file_exists(BACKUP_PATH):
		var file := FileAccess.open(BACKUP_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text()
			file.close()
			var json := JSON.new()
			if json.parse(text) == OK and json.data is Dictionary:
				var env := SaveEnvelopeV3Class.from_dict(json.data)
				if env.verify_integrity():
					return env
	return _read_and_migrate_legacy()

func _verify_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return false
	var env := SaveEnvelopeV3Class.from_dict(json.data)
	return env != null and env.verify_integrity()

func _preserve_corrupted_file(path: String) -> void:
	var corrupt_path := path + ".corrupted." + str(int(Time.get_unix_time_from_system()))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(corrupt_path))

func _try_restore_backup() -> void:
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
