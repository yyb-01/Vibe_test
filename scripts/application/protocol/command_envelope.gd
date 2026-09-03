class_name CommandEnvelope
extends RefCounted

# res://scripts/application/protocol/command_envelope.gd
# Encapsulates a player's intent/command for transport to the simulation host.

const ProtocolConstantsClass = preload("res://scripts/application/protocol/protocol_constants.gd")

var protocol_version: int = ProtocolConstantsClass.PROTOCOL_VERSION
var session_id: String = ""
var player_id: int = 1
var controlled_entity_id: int = 0
var predicted_tick: int = 0
var sequence: int = 0
var command_type: int = ProtocolConstantsClass.CommandType.MOVE_INTENT
var payload: Dictionary = {}

func _init(
	p_command_type: int = ProtocolConstantsClass.CommandType.MOVE_INTENT,
	p_payload: Dictionary = {},
	p_player_id: int = 1,
	p_controlled_entity_id: int = 0,
	p_sequence: int = 0,
	p_predicted_tick: int = 0,
	p_session_id: String = "",
	p_protocol_version: int = ProtocolConstantsClass.PROTOCOL_VERSION
) -> void:
	command_type = p_command_type
	payload = p_payload
	player_id = p_player_id
	controlled_entity_id = p_controlled_entity_id
	sequence = p_sequence
	predicted_tick = p_predicted_tick
	session_id = p_session_id
	protocol_version = p_protocol_version

func to_dict() -> Dictionary:
	return {
		"protocol_version": protocol_version,
		"session_id": session_id,
		"player_id": player_id,
		"controlled_entity_id": controlled_entity_id,
		"predicted_tick": predicted_tick,
		"sequence": sequence,
		"command_type": command_type,
		"payload": payload
	}

static func from_dict(d: Dictionary) -> CommandEnvelope:
	if not (d is Dictionary):
		return null
	var cmd := CommandEnvelope.new(
		int(d.get("command_type", ProtocolConstantsClass.CommandType.MOVE_INTENT)),
		d.get("payload", {}) if d.get("payload") is Dictionary else {},
		int(d.get("player_id", 1)),
		int(d.get("controlled_entity_id", 0)),
		int(d.get("sequence", 0)),
		int(d.get("predicted_tick", 0)),
		str(d.get("session_id", "")),
		int(d.get("protocol_version", ProtocolConstantsClass.PROTOCOL_VERSION))
	)
	return cmd
