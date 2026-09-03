class_name SerializedLoopbackTransport
extends INetworkTransport

# res://scripts/infrastructure/transport/serialized_loopback_transport.gd
# In-process loopback transport ensuring byte serialization boundary between client and host.

var peer_id: int = 1
var is_active: bool = false
var peer_transport: SerializedLoopbackTransport = null

var _inbox_packets: Array[Dictionary] = []

func _init(p_peer_id: int = 1) -> void:
	peer_id = p_peer_id

static func create_pair(client_peer_id: int = 1, host_peer_id: int = 0) -> Array[SerializedLoopbackTransport]:
	var client := SerializedLoopbackTransport.new(client_peer_id)
	var host := SerializedLoopbackTransport.new(host_peer_id)
	client.peer_transport = host
	host.peer_transport = client
	client.is_active = true
	host.is_active = true
	return [client, host]

func is_connected_to_host() -> bool:
	return is_active and peer_transport != null and peer_transport.is_active

func start_transport(_role: int, _address: String = "", _port: int = 0) -> bool:
	is_active = true
	return true

func send_packet(target_peer: int, channel: int, delivery_mode: int, payload: PackedByteArray) -> bool:
	if not is_connected_to_host():
		return false
	if peer_transport == null:
		return false

	# Enforce byte duplication to test true serialization/immutability
	var wire_bytes := payload.duplicate()
	var packet := {
		"source_peer": peer_id,
		"target_peer": target_peer,
		"channel": channel,
		"delivery_mode": delivery_mode,
		"payload": wire_bytes
	}
	peer_transport._receive_from_peer(packet)
	return true

func _receive_from_peer(packet: Dictionary) -> void:
	_inbox_packets.append(packet)

func try_receive_packet() -> Dictionary:
	if _inbox_packets.is_empty():
		return {}
	return _inbox_packets.pop_front()

func poll() -> void:
	# Loopback is synchronous by default
	pass

func disconnect_transport(_reason: String = "") -> void:
	is_active = false
	_inbox_packets.clear()
