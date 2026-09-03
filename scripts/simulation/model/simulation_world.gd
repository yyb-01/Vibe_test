class_name SimulationWorld
extends RefCounted

# res://scripts/simulation/model/simulation_world.gd
# Authoritative aggregate world state container for the game simulation.

const SessionStateClass = preload("res://scripts/simulation/model/session_state.gd")
const PlayerStateClass = preload("res://scripts/simulation/model/player_state.gd")
const EntityStateClass = preload("res://scripts/simulation/model/entity_state.gd")
const BuildGridStateClass = preload("res://scripts/simulation/model/build_grid_state.gd")
const RngStreamsClass = preload("res://scripts/simulation/model/rng_streams.gd")
const SimulationIdsClass = preload("res://scripts/simulation/model/simulation_ids.gd")

var session_state: SessionStateClass = SessionStateClass.new()
var players: Dictionary = {} # PlayerId: int -> PlayerStateClass
var entities: Dictionary = {} # EntityId: int -> EntityStateClass
var build_grid: BuildGridStateClass = BuildGridStateClass.new()
var rng: RngStreamsClass = RngStreamsClass.new()
var id_generator: SimulationIdsClass = SimulationIdsClass.new()

var server_tick: int = 0
var day_start_snapshot: Dictionary = {}

func _init(seed_val: int = 12345) -> void:
	session_state.session_seed = seed_val
	rng.setup(seed_val)
	var default_player := PlayerStateClass.new(1, 0)
	players[1] = default_player

func get_entity(entity_id: int) -> EntityStateClass:
	return entities.get(entity_id, null)

func add_entity(entity: EntityStateClass) -> void:
	if entity != null:
		entities[entity.entity_id] = entity

func remove_entity(entity_id: int) -> void:
	entities.erase(entity_id)

func capture_snapshot() -> Dictionary:
	var players_dict: Dictionary = {}
	for p_id in players:
		players_dict[str(p_id)] = players[p_id].to_dict()

	var entities_array: Array = []
	for e_id in entities:
		entities_array.append(entities[e_id].to_dict())

	return {
		"server_tick": server_tick,
		"session_state": session_state.to_dict(),
		"players": players_dict,
		"entities": entities_array,
		"build_grid": build_grid.to_dict(),
		"rng_streams": rng.to_dict(),
		"day_start_snapshot": day_start_snapshot.duplicate(true)
	}

func restore_snapshot(data: Dictionary) -> void:
	if not (data is Dictionary):
		return
	server_tick = int(data.get("server_tick", 0))

	if data.has("session_state") and data["session_state"] is Dictionary:
		session_state.from_dict(data["session_state"])

	players.clear()
	var raw_players = data.get("players", {})
	if raw_players is Dictionary:
		for p_str in raw_players:
			var p_state := PlayerStateClass.new(int(p_str), 0)
			p_state.from_dict(raw_players[p_str])
			players[int(p_str)] = p_state

	entities.clear()
	var raw_entities = data.get("entities", [])
	if raw_entities is Array:
		for e_dict in raw_entities:
			if e_dict is Dictionary:
				var e_state := EntityStateClass.from_dict(e_dict)
				if e_state != null:
					entities[e_state.entity_id] = e_state

	if data.has("build_grid") and data["build_grid"] is Dictionary:
		build_grid.from_dict(data["build_grid"])

	if data.has("rng_streams") and data["rng_streams"] is Dictionary:
		rng.from_dict(data["rng_streams"])

	if data.has("day_start_snapshot") and data["day_start_snapshot"] is Dictionary:
		day_start_snapshot = data["day_start_snapshot"].duplicate(true)

func calculate_checksum() -> int:
	# Rule state checksum: session state + entities + build grid revision + server tick
	var h: int = 17
	h = (h * 31 + server_tick) & 0x7FFFFFFF
	h = (h * 31 + session_state.phase) & 0x7FFFFFFF
	h = (h * 31 + session_state.phase_revision) & 0x7FFFFFFF
	h = (h * 31 + session_state.day) & 0x7FFFFFFF
	h = (h * 31 + build_grid.grid_revision) & 0x7FFFFFFF
	h = (h * 31 + entities.size()) & 0x7FFFFFFF

	# Sort entity IDs for deterministic order
	var e_ids: Array = entities.keys()
	e_ids.sort()
	for e_id in e_ids:
		var e: EntityStateClass = entities[e_id]
		h = (h * 31 + int(e_id)) & 0x7FFFFFFF
		h = (h * 31 + int(round(e.position.x * 10.0))) & 0x7FFFFFFF
		h = (h * 31 + int(round(e.position.y * 10.0))) & 0x7FFFFFFF
		h = (h * 31 + int(round(e.health))) & 0x7FFFFFFF

	return h
