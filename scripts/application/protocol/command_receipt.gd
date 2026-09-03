class_name CommandReceipt
extends RefCounted

# res://scripts/application/protocol/command_receipt.gd
# Server receipt acknowledging or rejecting a command sequence.

const ProtocolConstantsClass = preload("res://scripts/application/protocol/protocol_constants.gd")

var player_id: int = 1
var sequence: int = 0
var accepted: bool = true
var reason_code: int = ProtocolConstantsClass.ReasonCode.ACCEPTED
var server_tick: int = 0
var resulting_revision: int = 0

func _init(
	p_player_id: int = 1,
	p_sequence: int = 0,
	p_accepted: bool = true,
	p_reason_code: int = ProtocolConstantsClass.ReasonCode.ACCEPTED,
	p_server_tick: int = 0,
	p_resulting_revision: int = 0
) -> void:
	player_id = p_player_id
	sequence = p_sequence
	accepted = p_accepted
	reason_code = p_reason_code
	server_tick = p_server_tick
	resulting_revision = p_resulting_revision

func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"sequence": sequence,
		"accepted": accepted,
		"reason_code": reason_code,
		"server_tick": server_tick,
		"resulting_revision": resulting_revision
	}

static func from_dict(d: Dictionary) -> CommandReceipt:
	if not (d is Dictionary):
		return null
	return CommandReceipt.new(
		int(d.get("player_id", 1)),
		int(d.get("sequence", 0)),
		bool(d.get("accepted", true)),
		int(d.get("reason_code", ProtocolConstantsClass.ReasonCode.ACCEPTED)),
		int(d.get("server_tick", 0)),
		int(d.get("resulting_revision", 0))
	)
