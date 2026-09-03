class_name SimulationIds
extends RefCounted

# res://scripts/simulation/model/simulation_ids.gd
# Generates and validates authoritative runtime EntityId, SessionId, and EventId.

var authority_epoch: int = 1
var next_entity_counter: int = 1
var next_event_counter: int = 1

func _init(p_epoch: int = 1) -> void:
	authority_epoch = p_epoch
	next_entity_counter = 1
	next_event_counter = 1

func generate_entity_id() -> int:
	var id: int = (authority_epoch * 1000000000) + next_entity_counter
	next_entity_counter += 1
	return id

func generate_event_id() -> int:
	var id: int = next_event_counter
	next_event_counter += 1
	return id

static func generate_session_id() -> String:
	# Generate random hex UUID-like string
	var bytes: PackedByteArray = PackedByteArray()
	for i in range(16):
		bytes.append(randi() % 256)
	return bytes.hex_encode()
