class_name HostEndpoint
extends RefCounted

# res://scripts/application/host/host_endpoint.gd
# Server-side endpoint reading commands from transport and broadcasting simulation step results.

const ProtocolConstantsClass = preload("res://scripts/application/protocol/protocol_constants.gd")
const MessageEnvelopeClass = preload("res://scripts/application/protocol/message_envelope.gd")
const CommandEnvelopeClass = preload("res://scripts/application/protocol/command_envelope.gd")
const MessageCodecClass = preload("res://scripts/application/protocol/message_codec.gd")
const INetworkTransportClass = preload("res://scripts/infrastructure/transport/i_network_transport.gd")
const SimulationHostClass = preload("res://scripts/simulation/simulation_host.gd")

var transport: INetworkTransportClass
var codec: MessageCodecClass
var simulation_host: SimulationHostClass

func _init(p_transport: INetworkTransportClass, p_codec: MessageCodecClass, p_simulation_host: SimulationHostClass) -> void:
	transport = p_transport
	codec = p_codec
	simulation_host = p_simulation_host

func poll_and_enqueue_commands() -> void:
	if transport == null or simulation_host == null:
		return

	transport.poll()

	var packet: Dictionary = transport.try_receive_packet()
	while not packet.is_empty():
		var bytes: PackedByteArray = packet.get("payload", PackedByteArray())
		var env: MessageEnvelopeClass = codec.decode_envelope(bytes)
		if env != null and env.message_type == ProtocolConstantsClass.MessageType.COMMAND:
			var cmd := CommandEnvelopeClass.from_dict(env.payload)
			if cmd != null:
				simulation_host.enqueue_command(cmd)
		packet = transport.try_receive_packet()

func broadcast_step_result(step_result: Dictionary) -> void:
	if transport == null:
		return

	var tick: int = int(step_result.get("server_tick", 0))

	# 1. Send Command Receipts
	var receipts: Array = step_result.get("receipts", [])
	for r in receipts:
		if r is Dictionary:
			var p_id: int = int(r.get("player_id", 1))
			var env := MessageEnvelopeClass.new(
				ProtocolConstantsClass.MessageType.COMMAND_RECEIPT,
				"",
				0,
				tick,
				int(r.get("sequence", 0)),
				r
			)
			var bytes := codec.encode_envelope(env)
			transport.send_packet(p_id, ProtocolConstantsClass.Channel.ACTION, ProtocolConstantsClass.DeliveryMode.RELIABLE_ORDERED, bytes)

	# 2. Send Domain Events
	var events: Array = step_result.get("events", [])
	if not events.is_empty():
		var ev_batch := {
			"server_tick": tick,
			"events": events
		}
		var env := MessageEnvelopeClass.new(
			ProtocolConstantsClass.MessageType.EVENT_BATCH,
			"",
			0,
			tick,
			0,
			ev_batch
		)
		var bytes := codec.encode_envelope(env)
		transport.send_packet(1, ProtocolConstantsClass.Channel.CRITICAL_EVENT, ProtocolConstantsClass.DeliveryMode.RELIABLE_ORDERED, bytes)

	# 3. Send State Delta
	var delta: Dictionary = step_result.get("delta", {})
	if not delta.is_empty():
		var env := MessageEnvelopeClass.new(
			ProtocolConstantsClass.MessageType.STATE_DELTA,
			"",
			0,
			tick,
			0,
			delta
		)
		var bytes := codec.encode_envelope(env)
		transport.send_packet(1, ProtocolConstantsClass.Channel.SNAPSHOT, ProtocolConstantsClass.DeliveryMode.UNRELIABLE_SEQUENCED, bytes)
