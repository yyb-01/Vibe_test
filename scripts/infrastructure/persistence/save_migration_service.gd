class_name SaveMigrationService
extends RefCounted

# res://scripts/infrastructure/persistence/save_migration_service.gd
# Deterministic migration chain from Save Schema v2 to Schema v3.

const SaveEnvelopeV3Class = preload("res://scripts/infrastructure/persistence/save_envelope_v3.gd")

static func is_v3_envelope(data: Dictionary) -> bool:
	return int(data.get("schema_version", 0)) == SaveEnvelopeV3Class.SCHEMA_VERSION

static func migrate_to_v3(raw_data: Dictionary) -> SaveEnvelopeV3Class:
	if not (raw_data is Dictionary):
		return null

	if is_v3_envelope(raw_data):
		return SaveEnvelopeV3Class.from_dict(raw_data)

	var version: int = int(raw_data.get("version", raw_data.get("schema_version", 1)))
	if version > 3:
		printerr("SaveMigrationService: Cannot downgrade future save version: ", version)
		return null

	# Migration: v2 -> v3
	var env := SaveEnvelopeV3Class.new()
	env.slot_id = "slot_01"
	env.revision = int(raw_data.get("revision", 1))

	var meta: Dictionary = raw_data.get("meta", {})
	var day: int = int(raw_data.get("day", 1))
	var state_name: String = str(raw_data.get("state", raw_data.get("game_state", "HUB")))
	var storage: Dictionary = raw_data.get("storage", {})
	var structures: Array = raw_data.get("structures", raw_data.get("base_structures", []))
	var day_start_snapshot: Dictionary = raw_data.get("day_start_snapshot", {})

	# Build build_grid data
	var grid_structs: Dictionary = {}
	for i in range(structures.size()):
		var s = structures[i]
		if s is Dictionary:
			var s_id = s.get("id", s.get("data_id", ""))
			var cell = s.get("cell", s.get("anchor_cell", [0, 0]))
			var rot = int(s.get("rot", s.get("rotation_quarters", 0)))
			grid_structs[str(i + 100)] = {
				"definition_id": s_id,
				"anchor_cell": cell,
				"rotation_quarters": rot,
				"cells": [cell]
			}

	var payload := {
		"checkpoint_tick": 0,
		"session": {
			"phase": state_name,
			"day": day,
			"phase_revision": 1,
			"session_seed": 12345
		},
		"shared_storage": storage.duplicate(true),
		"meta_progress": {
			"legacy_scrap": int(meta.get("legacy_scrap", raw_data.get("legacy_scrap", 0))),
			"survivor_xp": int(meta.get("survivor_xp", 0)),
			"survivor_level": int(meta.get("survivor_level", 1)),
			"unlocked_blueprints": meta.get("unlocked_blueprints", raw_data.get("unlocked_blueprints", ["barricade_wood"]))
		},
		"build_grid": {
			"grid_revision": 1,
			"structures": grid_structs
		},
		"day_start_snapshot": day_start_snapshot.duplicate(true)
	}

	env.payload = payload
	env.integrity["digest"] = env.compute_sha256()

	return env
