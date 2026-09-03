class_name MessageEnvelope
extends RefCounted

# res://scripts/application/protocol/message_envelope.gd
# Top-level network message envelope for wire transmission.

const ProtocolConstantsClass = preload("res://scripts/application/protocol/protocol_constants.gd")

var protocol_version: int = ProtocolConstantsClass.PROTOCOL_VERSION
var message_type: int = ProtocolConstantsClass.MessageType.COMMAND
var session_id: String = ""
var sender_player_id: int = 0
var tick: int = 0
var sequence: int = 0
var payload: Dictionary = {}

func _init(
	p_message_type: int = ProtocolConstantsClass.MessageType.COMMAND,
	p_session_id: String = "",
	p_sender_player_id: int = 0,
	p_tick: int = 0,
	p_sequence: int = 0,
	p_payload: Dictionary = {},
	p_protocol_version: int = ProtocolConstantsClass.PROTOCOL_VERSION
) -> void:
	protocol_version = p_protocol_version
	message_type = p_message_type
	session_id = p_session_id
	sender_player_id = p_sender_player_id
	tick = p_tick
	sequence = p_sequence
	payload = p_payload

func to_dict() -> Dictionary:
	return {
		"protocol_version": protocol_version,
		"message_type": message_type,
		"session_id": session_id,
		"sender_player_id": sender_player_id,
		"tick": tick,
		"sequence": sequence,
		"payload": payload
	}

static func from_dict(d: Dictionary) -> MessageEnvelope:
	if not (d is Dictionary):
		return null
	var env := MessageEnvelope.new(
		int(d.get("message_type", ProtocolConstantsClass.MessageType.COMMAND)),
		str(d.get("session_id", "")),
		int(d.get("sender_player_id", 0)),
		int(d.get("tick", 0)),
		int(d.get("sequence", 0)),
		d.get("payload", {}) if d.get("payload") is Dictionary else {},
		int(d.get("protocol_version", ProtocolConstantsClass.PROTOCOL_VERSION))
	)
	return env
