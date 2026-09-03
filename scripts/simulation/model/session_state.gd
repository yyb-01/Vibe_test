class_name SessionState
extends RefCounted

# res://scripts/simulation/model/session_state.gd
# Authoritative session state for game phases, day cycle, shared storage, and meta progress.

const GameStateMachineClass = preload("res://scripts/core/game_state_machine.gd")

var phase: int = GameStateMachineClass.State.HUB
var phase_revision: int = 0
var day: int = 1
var session_seed: int = 12345
var content_hash: String = ""
var grid_revision: int = 0
var shared_storage: Dictionary = {
	&"wood": 40,
	&"scrap_metal": 24,
	&"electronics": 10,
	&"ammo": 60
}

# Meta progress & stats
var legacy_scrap: int = 0
var survivor_xp: int = 0
var survivor_level: int = 1
var unlocked_blueprints: Array[StringName] = [&"barricade_wood"]

var day_stats: Dictionary = {
	"zombies_killed": 0,
	"ammo_consumed": 0,
	"structures_lost": 0,
	"items_harvested": {}
}

var last_day_result: Dictionary = {}

func to_dict() -> Dictionary:
	var bp_array: Array = []
	for bp in unlocked_blueprints:
		bp_array.append(str(bp))
	var storage_dict: Dictionary = {}
	for k in shared_storage:
		storage_dict[str(k)] = shared_storage[k]

	return {
		"phase": phase,
		"phase_revision": phase_revision,
		"day": day,
		"session_seed": session_seed,
		"content_hash": content_hash,
		"grid_revision": grid_revision,
		"shared_storage": storage_dict,
		"legacy_scrap": legacy_scrap,
		"survivor_xp": survivor_xp,
		"survivor_level": survivor_level,
		"unlocked_blueprints": bp_array,
		"day_stats": day_stats.duplicate(true),
		"last_day_result": last_day_result.duplicate(true)
	}

func from_dict(d: Dictionary) -> void:
	if not (d is Dictionary):
		return
	phase = int(d.get("phase", GameStateMachineClass.State.HUB))
	phase_revision = int(d.get("phase_revision", 0))
	day = int(d.get("day", 1))
	session_seed = int(d.get("session_seed", 12345))
	content_hash = str(d.get("content_hash", ""))
	grid_revision = int(d.get("grid_revision", 0))
	legacy_scrap = int(d.get("legacy_scrap", 0))
	survivor_xp = int(d.get("survivor_xp", 0))
	survivor_level = int(d.get("survivor_level", 1))

	var raw_storage = d.get("shared_storage", {})
	shared_storage = {}
	if raw_storage is Dictionary:
		for k in raw_storage:
			shared_storage[StringName(k)] = int(raw_storage[k])

	var raw_bps = d.get("unlocked_blueprints", ["barricade_wood"])
	unlocked_blueprints = []
	if raw_bps is Array:
		for bp in raw_bps:
			unlocked_blueprints.append(StringName(bp))

	if d.has("day_stats") and d["day_stats"] is Dictionary:
		day_stats = d["day_stats"].duplicate(true)
	if d.has("last_day_result") and d["last_day_result"] is Dictionary:
		last_day_result = d["last_day_result"].duplicate(true)
