class_name INetworkTransport
extends RefCounted

# res://scripts/infrastructure/transport/i_network_transport.gd
# Abstract transport port contract for network communication.

func is_connected_to_host() -> bool:
	return false

func start_transport(role: int, address: String = "", port: int = 0) -> bool:
	return false

func send_packet(target_peer: int, channel: int, delivery_mode: int, payload: PackedByteArray) -> bool:
	return false

func try_receive_packet() -> Dictionary:
	return {}

func poll() -> void:
	pass

func disconnect_transport(reason: String = "") -> void:
	pass
