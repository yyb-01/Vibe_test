class_name EntityState
extends RefCounted

# res://scripts/simulation/model/entity_state.gd
# Authoritative state of an active entity in the simulation world.

enum Lifecycle {
	RESERVED = 0,
	ACTIVE = 1,
	DISABLED = 2,
	DESPAWNING = 3,
	TOMBSTONE = 4
}

var entity_id: int = 0
var definition_id: StringName = &""
var owner_player_id: int = 0
var lifecycle: int = Lifecycle.ACTIVE

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO

var health: float = 100.0
var max_health: float = 100.0

var cooldowns: Dictionary = {} # ability_id -> remaining_ticks: int
var custom_data: Dictionary = {} # anchor_cell, rotation, dash_timer, iframe_timer, aim_angle, etc.

func _init(p_entity_id: int = 0, p_definition_id: StringName = &"", p_owner_player_id: int = 0) -> void:
	entity_id = p_entity_id
	definition_id = p_definition_id
	owner_player_id = p_owner_player_id

func is_alive() -> bool:
	return lifecycle == Lifecycle.ACTIVE and health > 0.0

func to_dict() -> Dictionary:
	return {
		"entity_id": entity_id,
		"definition_id": str(definition_id),
		"owner_player_id": owner_player_id,
		"lifecycle": lifecycle,
		"position": [position.x, position.y],
		"velocity": [velocity.x, velocity.y],
		"health": health,
		"max_health": max_health,
		"cooldowns": cooldowns.duplicate(true),
		"custom_data": custom_data.duplicate(true)
	}

static func from_dict(d: Dictionary) -> EntityState:
	if not (d is Dictionary):
		return null
	var state := EntityState.new(
		int(d.get("entity_id", 0)),
		StringName(d.get("definition_id", "")),
		int(d.get("owner_player_id", 0))
	)
	state.lifecycle = int(d.get("lifecycle", Lifecycle.ACTIVE))
	var pos_arr = d.get("position", [0.0, 0.0])
	if pos_arr is Array and pos_arr.size() >= 2:
		state.position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	var vel_arr = d.get("velocity", [0.0, 0.0])
	if vel_arr is Array and vel_arr.size() >= 2:
		state.velocity = Vector2(float(vel_arr[0]), float(vel_arr[1]))
	state.health = float(d.get("health", 100.0))
	state.max_health = float(d.get("max_health", 100.0))
	if d.has("cooldowns") and d["cooldowns"] is Dictionary:
		state.cooldowns = d["cooldowns"].duplicate(true)
	if d.has("custom_data") and d["custom_data"] is Dictionary:
		state.custom_data = d["custom_data"].duplicate(true)
	return state
