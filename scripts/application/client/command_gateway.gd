class_name CommandGateway
extends RefCounted

# res://scripts/application/client/command_gateway.gd
# Dispatches outgoing player commands with sequence tracking over the network transport.

const ProtocolConstantsClass = preload("res://scripts/application/protocol/protocol_constants.gd")
const CommandEnvelopeClass = preload("res://scripts/application/protocol/command_envelope.gd")
const MessageEnvelopeClass = preload("res://scripts/application/protocol/message_envelope.gd")
const MessageCodecClass = preload("res://scripts/application/protocol/message_codec.gd")
const INetworkTransportClass = preload("res://scripts/infrastructure/transport/i_network_transport.gd")

var transport: INetworkTransportClass
var codec: MessageCodecClass
var player_id: int = 1
var session_id: String = ""

var next_sequence: int = 1
var unacknowledged_commands: Dictionary = {} # seq: int -> CommandEnvelopeClass

func _init(p_transport: INetworkTransportClass, p_codec: MessageCodecClass, p_player_id: int = 1) -> void:
	transport = p_transport
	codec = p_codec
	player_id = p_player_id

func submit(cmd: CommandEnvelopeClass) -> int:
	if cmd == null or transport == null:
		return 0

	cmd.sequence = next_sequence
	next_sequence += 1
	cmd.player_id = player_id
	cmd.session_id = session_id

	unacknowledged_commands[cmd.sequence] = cmd

	var env := MessageEnvelopeClass.new(
		ProtocolConstantsClass.MessageType.COMMAND,
		session_id,
		player_id,
		cmd.predicted_tick,
		cmd.sequence,
		cmd.to_dict()
	)

	var bytes := codec.encode_envelope(env)
	var channel := ProtocolConstantsClass.Channel.ACTION
	if cmd.command_type == ProtocolConstantsClass.CommandType.MOVE_INTENT or cmd.command_type == ProtocolConstantsClass.CommandType.AIM_INTENT:
		channel = ProtocolConstantsClass.Channel.INPUT_STATE

	transport.send_packet(0, channel, ProtocolConstantsClass.DeliveryMode.RELIABLE_ORDERED, bytes)
	return cmd.sequence

func handle_receipt(receipt_dict: Dictionary) -> void:
	var seq: int = int(receipt_dict.get("sequence", 0))
	unacknowledged_commands.erase(seq)
