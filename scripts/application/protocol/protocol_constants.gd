class_name ProtocolConstants
extends RefCounted

# res://scripts/application/protocol/protocol_constants.gd
# Standard constants for message envelope, wire channels, command types, and rejection reason codes.

const PROTOCOL_VERSION: int = 3

enum MessageType {
	HANDSHAKE = 1000,
	COMMAND = 1001,
	COMMAND_RECEIPT = 1002,
	STATE_SNAPSHOT = 1003,
	STATE_DELTA = 1004,
	EVENT_BATCH = 1005,
	HEARTBEAT = 1006
}

enum Channel {
	CONTROL = 0,        # ReliableOrdered: Handshake, Session tokens, Auth
	ACTION = 1,         # ReliableOrdered: Ability edge, build, inventory, phase
	INPUT_STATE = 2,    # UnreliableSequenced: Move, aim, continuous inputs
	SNAPSHOT = 3,       # UnreliableSequenced: Transform/velocity delta, snapshots
	CRITICAL_EVENT = 4, # ReliableOrdered: Damage, death, spawn/despawn, wave result
	COSMETIC_HINT = 5   # UnreliableSequenced: Non-critical VFX/SFX hints
}

enum DeliveryMode {
	RELIABLE_ORDERED = 0,
	UNRELIABLE_SEQUENCED = 1
}

enum CommandType {
	MOVE_INTENT = 1,
	AIM_INTENT = 2,
	ABILITY_COMMAND = 3,
	INTERACT_COMMAND = 4,
	BUILD_COMMAND = 5,
	REMOVE_BUILD_COMMAND = 6,
	PHASE_COMMAND = 7,
	INVENTORY_COMMAND = 8
}

enum ReasonCode {
	ACCEPTED = 0,
	INVALID_STATE = 1,
	NOT_OWNER = 2,
	OUT_OF_RANGE = 3,
	COOLDOWN = 4,
	INSUFFICIENT_RESOURCE = 5,
	OCCUPIED = 6,
	BLOCKED_ROUTE = 7,
	STALE_REVISION = 8,
	RATE_LIMITED = 9,
	UNKNOWN_DEFINITION = 10
}

const REASON_STRINGS: Dictionary = {
	ReasonCode.ACCEPTED: "accepted",
	ReasonCode.INVALID_STATE: "invalid_state",
	ReasonCode.NOT_OWNER: "not_owner",
	ReasonCode.OUT_OF_RANGE: "out_of_range",
	ReasonCode.COOLDOWN: "cooldown",
	ReasonCode.INSUFFICIENT_RESOURCE: "insufficient_resource",
	ReasonCode.OCCUPIED: "occupied",
	ReasonCode.BLOCKED_ROUTE: "blocked_route",
	ReasonCode.STALE_REVISION: "stale_revision",
	ReasonCode.RATE_LIMITED: "rate_limited",
	ReasonCode.UNKNOWN_DEFINITION: "unknown_definition"
}
