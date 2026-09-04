class_name SaveStore
extends RefCounted

const FORMAT_VERSION: int = 1
const GAME_VERSION: String = "g1"

var directory: String = "user://vivv"

func configure(next_directory: String) -> bool:
	if not next_directory.begins_with("user://") or next_directory.ends_with("/"):
		return false
	directory = next_directory
	return true

func write(file_name: String, payload_type: String, payload: Dictionary, content_hash: String, save_id: String) -> Dictionary:
	if not _valid_file_name(file_name) or payload.is_empty() or String(payload_type).is_empty() or String(content_hash).is_empty() or String(save_id).is_empty():
		return {"accepted": false, "reason": &"SAVE_INPUT_INVALID"}
	if not _ensure_directory():
		return {"accepted": false, "reason": &"SAVE_DIRECTORY_FAILED"}
	var envelope := {
		"format_version": FORMAT_VERSION,
		"game_version": GAME_VERSION,
		"content_hash": content_hash,
		"save_id": save_id,
		"created_at": Time.get_datetime_string_from_system(true),
		"payload_type": payload_type,
		"payload": payload,
		"checksum": _checksum(payload),
	}
	var temp_name := "%s.tmp" % file_name
	var temp_path := directory.path_join(temp_name)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return {"accepted": false, "reason": &"SAVE_OPEN_FAILED"}
	file.store_var(envelope, true)
	file.flush()
	file.close()
	var verification := _read_file(temp_path)
	if not verification.get("accepted", false):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return {"accepted": false, "reason": &"SAVE_VERIFY_FAILED"}
	var dir := DirAccess.open(directory)
	if dir == null:
		return {"accepted": false, "reason": &"SAVE_DIRECTORY_FAILED"}
	var backup_name := "%s.bak" % file_name
	var had_primary := FileAccess.file_exists(directory.path_join(file_name))
	if had_primary:
		if FileAccess.file_exists(directory.path_join(backup_name)):
			dir.remove(backup_name)
		if dir.rename(file_name, backup_name) != OK:
			dir.remove(temp_name)
			return {"accepted": false, "reason": &"SAVE_BACKUP_FAILED"}
	if dir.rename(temp_name, file_name) != OK:
		if had_primary and not FileAccess.file_exists(directory.path_join(file_name)):
			dir.rename(backup_name, file_name)
		return {"accepted": false, "reason": &"SAVE_COMMIT_FAILED"}
	return {"accepted": true, "file_name": file_name, "used_backup": false}

func read(file_name: String, expected_payload_type: String, expected_content_hash: String) -> Dictionary:
	if not _valid_file_name(file_name):
		return {"accepted": false, "reason": &"SAVE_INPUT_INVALID"}
	var primary_path := directory.path_join(file_name)
	var result := _read_file(primary_path)
	var used_backup := false
	if not result.get("accepted", false):
		var backup_path := directory.path_join("%s.bak" % file_name)
		if FileAccess.file_exists(backup_path):
			result = _read_file(backup_path)
			used_backup = result.get("accepted", false)
	if not result.get("accepted", false):
		return result
	var envelope: Dictionary = result.get("envelope", {})
	if envelope.get("payload_type", "") != expected_payload_type:
		return {"accepted": false, "reason": &"SAVE_PAYLOAD_TYPE_MISMATCH"}
	if envelope.get("content_hash", "") != expected_content_hash:
		return {"accepted": false, "reason": &"SAVE_CONTENT_MISMATCH"}
	return {"accepted": true, "payload": envelope.get("payload", {}), "envelope": envelope, "used_backup": used_backup}

func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"accepted": false, "reason": &"SAVE_NOT_FOUND"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"accepted": false, "reason": &"SAVE_OPEN_FAILED"}
	var envelope = file.get_var(true)
	file.close()
	if typeof(envelope) != TYPE_DICTIONARY:
		return {"accepted": false, "reason": &"SAVE_ENVELOPE_INVALID"}
	if int(envelope.get("format_version", -1)) != FORMAT_VERSION:
		return {"accepted": false, "reason": &"SAVE_VERSION_UNSUPPORTED"}
	var payload = envelope.get("payload")
	if typeof(payload) != TYPE_DICTIONARY or String(envelope.get("checksum", "")) != _checksum(payload):
		return {"accepted": false, "reason": &"SAVE_CHECKSUM_INVALID"}
	return {"accepted": true, "envelope": envelope}

func _ensure_directory() -> bool:
	var absolute_path := ProjectSettings.globalize_path(directory)
	if DirAccess.dir_exists_absolute(absolute_path):
		return true
	return DirAccess.make_dir_recursive_absolute(absolute_path) == OK

func _valid_file_name(file_name: String) -> bool:
	return not String(file_name).is_empty() and not file_name.contains("/") and not file_name.contains("\\") and not file_name.contains("..")

func _checksum(payload: Dictionary) -> String:
	# ponytail: lightweight corruption guard; use SHA-256 if save tamper resistance becomes a requirement.
	return str(JSON.stringify(payload).hash())
