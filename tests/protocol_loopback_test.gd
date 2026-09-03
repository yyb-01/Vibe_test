extends SceneTree

# res://tests/protocol_loopback_test.gd
# Conformance test for serialized loopback transport, message codec, command envelope, and receipts.

const ProtocolConstantsClass = preload("res://scripts/application/protocol/protocol_constants.gd")
const MessageEnvelopeClass = preload("res://scripts/application/protocol/message_envelope.gd")
const CommandEnvelopeClass = preload("res://scripts/application/protocol/command_envelope.gd")
const CommandReceiptClass = preload("res://scripts/application/protocol/command_receipt.gd")
const MessageCodecClass = preload("res://scripts/application/protocol/message_codec.gd")
const SerializedLoopbackTransportClass = preload("res://scripts/infrastructure/transport/serialized_loopback_transport.gd")
const CommandGatewayClass = preload("res://scripts/application/client/command_gateway.gd")
const SimulationCommandsClass = preload("res://scripts/simulation/commands/simulation_commands.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("========================================")
	print(" RUNNING PROTOCOL LOOPBACK TEST SUITE")
	print("========================================")

	test_codec_envelope_round_trip()
	test_loopback_transport_packet_delivery()
	test_command_gateway_submission()

	print("========================================")
	print(" TEST RESULTS: %d Passed, %d Failed (Total: %d)" % [passed_tests, failed_tests, total_tests])
	print("========================================")

	quit(1 if failed_tests > 0 else 0)

func assert_true(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s" % test_name)

func assert_equal(actual, expected, test_name: String) -> void:
	total_tests += 1
	if actual == expected:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s: expected %s, got %s" % [test_name, str(expected), str(actual)])

func test_codec_envelope_round_trip() -> void:
	print("\n--- Test: Codec MessageEnvelope Round Trip ---")
	var codec := MessageCodecClass.new()
	var original_env := MessageEnvelopeClass.new(
		ProtocolConstantsClass.MessageType.COMMAND,
		"test-session-uuid",
		1,
		100,
		5,
		{"action": "test_shoot", "val": 42}
	)

	var bytes := codec.encode_envelope(original_env)
	assert_true(bytes.size() > 0, "Codec produces non-empty byte buffer")

	var decoded_env := codec.decode_envelope(bytes)
	assert_true(decoded_env != null, "Codec successfully decodes byte buffer")
	assert_equal(decoded_env.message_type, ProtocolConstantsClass.MessageType.COMMAND, "Message type matches")
	assert_equal(decoded_env.session_id, "test-session-uuid", "Session ID matches")
	assert_equal(decoded_env.sender_player_id, 1, "Player ID matches")
	assert_equal(decoded_env.tick, 100, "Tick matches")
	assert_equal(decoded_env.sequence, 5, "Sequence matches")
	assert_equal(decoded_env.payload.get("val", 0), 42, "Payload content matches")

func test_loopback_transport_packet_delivery() -> void:
	print("\n--- Test: Serialized Loopback Transport Delivery ---")
	var pair := SerializedLoopbackTransportClass.create_pair(1, 0)
	var client_trans := pair[0]
	var host_trans := pair[1]

	assert_true(client_trans.is_connected_to_host(), "Client is connected to host")
	assert_true(host_trans.is_connected_to_host(), "Host is connected to client")

	var test_payload := "Hello loopback".to_utf8_buffer()
	var sent := client_trans.send_packet(0, ProtocolConstantsClass.Channel.ACTION, ProtocolConstantsClass.DeliveryMode.RELIABLE_ORDERED, test_payload)
	assert_true(sent, "Client packet sent")

	var received := host_trans.try_receive_packet()
	assert_true(not received.is_empty(), "Host received packet")
	assert_equal(received.get("source_peer", -1), 1, "Packet source peer is client")
	var received_text: String = received.get("payload", PackedByteArray()).get_string_from_utf8()
	assert_equal(received_text, "Hello loopback", "Packet payload matches exactly")

func test_command_gateway_submission() -> void:
	print("\n--- Test: Command Gateway Submission and Receipts ---")
	var codec := MessageCodecClass.new()
	var pair := SerializedLoopbackTransportClass.create_pair(1, 0)
	var client_trans := pair[0]
	var host_trans := pair[1]

	var gateway := CommandGatewayClass.new(client_trans, codec, 1)
	gateway.session_id = "sess-1"

	var cmd = SimulationCommandsClass.create_move_intent(1, 100, Vector2(1.0, 0.0), 0, 10)
	var seq = gateway.submit(cmd)
	assert_equal(seq, 1, "Gateway assigns monotonic sequence 1")
	assert_true(gateway.unacknowledged_commands.has(1), "Gateway tracks unacknowledged command sequence 1")

	# Verify host receives the command packet
	var host_pkt = host_trans.try_receive_packet()
	assert_true(not host_pkt.is_empty(), "Host received command packet from gateway")
	var env = codec.decode_envelope(host_pkt["payload"])
	assert_equal(env.message_type, ProtocolConstantsClass.MessageType.COMMAND, "Envelope is COMMAND")
	assert_equal(env.sequence, 1, "Envelope sequence is 1")

	# Return receipt
	gateway.handle_receipt({"sequence": 1, "accepted": true})
	assert_true(not gateway.unacknowledged_commands.has(1), "Gateway clears sequence 1 upon receipt")
