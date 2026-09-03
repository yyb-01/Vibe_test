class_name ClientEndpoint
extends RefCounted

# res://scripts/application/client/client_endpoint.gd
# Handles receiving and processing replicated simulation state, receipts, and domain events on the client.

const ProtocolConstantsClass = preload("res://scripts/application/protocol/protocol_constants.gd")
const MessageEnvelopeClass = preload("res://scripts/application/protocol/message_envelope.gd")
const MessageCodecClass = preload("res://scripts/application/protocol/message_codec.gd")
const INetworkTransportClass = preload("res://scripts/infrastructure/transport/i_network_transport.gd")
const CommandGatewayClass = preload("res://scripts/application/client/command_gateway.gd")

var transport: INetworkTransportClass
var codec: MessageCodecClass
var gateway: CommandGatewayClass

# Client Read Models
var server_tick: int = 0
var current_phase: int = 0
var current_day: int = 1
var grid_revision: int = 0
var replicated_entities: Dictionary = {} # entity_id: int -> Dictionary
var replicated_storage: Dictionary = {}
var replicated_bag: Array[Dictionary] = []

signal state_delta_received(delta: Dictionary)
signal domain_event_received(event: Dictionary)
signal command_receipt_received(receipt: Dictionary)

func _init(p_transport: INetworkTransportClass, p_codec: MessageCodecClass, p_gateway: CommandGatewayClass) -> void:
	transport = p_transport
	codec = p_codec
	gateway = p_gateway

func poll_network() -> void:
	if transport == null:
		return

	transport.poll()

	var packet: Dictionary = transport.try_receive_packet()
	while not packet.is_empty():
		_process_packet(packet)
		packet = transport.try_receive_packet()

func _process_packet(packet: Dictionary) -> void:
	var bytes: PackedByteArray = packet.get("payload", PackedByteArray())
	var env: MessageEnvelopeClass = codec.decode_envelope(bytes)
	if env == null:
		return

	match env.message_type:
		ProtocolConstantsClass.MessageType.COMMAND_RECEIPT:
			var receipt_data = env.payload
			if gateway != null:
				gateway.handle_receipt(receipt_data)
			command_receipt_received.emit(receipt_data)

		ProtocolConstantsClass.MessageType.STATE_DELTA:
			_apply_state_delta(env.payload)
			state_delta_received.emit(env.payload)

		ProtocolConstantsClass.MessageType.EVENT_BATCH:
			var raw_events = env.payload.get("events", [])
			if raw_events is Array:
				for ev in raw_events:
					if ev is Dictionary:
						_apply_domain_event(ev)
						domain_event_received.emit(ev)

		ProtocolConstantsClass.MessageType.STATE_SNAPSHOT:
			_apply_state_snapshot(env.payload)

func _apply_state_delta(delta: Dictionary) -> void:
	server_tick = int(delta.get("server_tick", server_tick))
	current_phase = int(delta.get("phase", current_phase))
	current_day = int(delta.get("day", current_day))
	grid_revision = int(delta.get("grid_revision", grid_revision))

	var raw_entities = delta.get("entities", [])
	if raw_entities is Array:
		for e_dict in raw_entities:
			if e_dict is Dictionary:
				var e_id: int = int(e_dict.get("entity_id", 0))
				replicated_entities[e_id] = e_dict.duplicate(true)

func _apply_domain_event(ev: Dictionary) -> void:
	var ev_type: int = int(ev.get("event_type", 0))
	var payload: Dictionary = ev.get("payload", {})

	match ev_type:
		ProtocolConstantsClass.MessageType.COMMAND:
			pass
		2002: # ENTITY_DESPAWNED or DIED
			var e_id: int = int(payload.get("entity_id", 0))
			replicated_entities.erase(e_id)
		2009: # INVENTORY_COMMITTED
			var container = payload.get("container", "")
			var item_id = StringName(payload.get("item_id", ""))
			var result = int(payload.get("resulting_amount", 0))
			if container == "storage":
				if result <= 0:
					replicated_storage.erase(item_id)
				else:
					replicated_storage[item_id] = result

func _apply_state_snapshot(snap: Dictionary) -> void:
	server_tick = int(snap.get("server_tick", 0))
	var s_state = snap.get("session_state", {})
	if s_state is Dictionary:
		current_phase = int(s_state.get("phase", 0))
		current_day = int(s_state.get("day", 1))
		var stor = s_state.get("shared_storage", {})
		if stor is Dictionary:
			replicated_storage.clear()
			for k in stor:
				replicated_storage[StringName(k)] = int(stor[k])
