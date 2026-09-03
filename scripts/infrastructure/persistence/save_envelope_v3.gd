class_name SaveEnvelopeV3
extends RefCounted

# res://scripts/infrastructure/persistence/save_envelope_v3.gd
# Data envelope structure for Save Schema Version 3 per Section 5.2.

const SCHEMA_VERSION: int = 3

var save_id: String = ""
var profile_id: String = ""
var slot_id: String = "slot_01"
var revision: int = 1
var parent_revision: int = 0
var build_id: String = "1.0.0"
var content_revision: String = ""
var created_at_utc: String = ""
var updated_at_utc: String = ""

var integrity: Dictionary = {
	"algorithm": "SHA-256",
	"digest": ""
}

var payload: Dictionary = {}

func _init() -> void:
	save_id = _generate_uuid()
	profile_id = _generate_uuid()
	var dt = Time.get_datetime_dict_from_system(true)
	var time_str = "%04d-%02d-%02dT%02d:%02d:%02dZ" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	created_at_utc = time_str
	updated_at_utc = time_str

func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"save_id": save_id,
		"profile_id": profile_id,
		"slot_id": slot_id,
		"revision": revision,
		"parent_revision": parent_revision,
		"build_id": build_id,
		"content_revision": content_revision,
		"created_at_utc": created_at_utc,
		"updated_at_utc": updated_at_utc,
		"integrity": integrity.duplicate(true),
		"payload": payload.duplicate(true)
	}

static func from_dict(d: Dictionary) -> SaveEnvelopeV3:
	if not (d is Dictionary):
		return null
	var env := SaveEnvelopeV3.new()
	env.save_id = str(d.get("save_id", env.save_id))
	env.profile_id = str(d.get("profile_id", env.profile_id))
	env.slot_id = str(d.get("slot_id", "slot_01"))
	env.revision = int(d.get("revision", 1))
	env.parent_revision = int(d.get("parent_revision", 0))
	env.build_id = str(d.get("build_id", "1.0.0"))
	env.content_revision = str(d.get("content_revision", ""))
	env.created_at_utc = str(d.get("created_at_utc", ""))
	env.updated_at_utc = str(d.get("updated_at_utc", ""))
	if d.has("integrity") and d["integrity"] is Dictionary:
		env.integrity = d["integrity"].duplicate(true)
	if d.has("payload") and d["payload"] is Dictionary:
		env.payload = d["payload"].duplicate(true)
	return env

func compute_sha256() -> String:
	var payload_json := JSON.stringify(payload)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(payload_json.to_utf8_buffer())
	var res := ctx.finish()
	return res.hex_encode()

func verify_integrity() -> bool:
	var expected := str(integrity.get("digest", ""))
	if expected.is_empty():
		return false
	return compute_sha256() == expected

static func _generate_uuid() -> String:
	var b := PackedByteArray()
	for i in range(16):
		b.append(randi() % 256)
	return b.hex_encode()
