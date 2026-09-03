class_name MessageCodec
extends RefCounted

# res://scripts/application/protocol/message_codec.gd
# Encodes and decodes message envelopes to/from byte buffers.

const ProtocolConstantsClass = preload("res://scripts/application/protocol/protocol_constants.gd")
const MessageEnvelopeClass = preload("res://scripts/application/protocol/message_envelope.gd")

var protocol_version: int = ProtocolConstantsClass.PROTOCOL_VERSION

func encode_envelope(envelope: MessageEnvelopeClass) -> PackedByteArray:
	if envelope == null:
		return PackedByteArray()
	var dict := envelope.to_dict()
	return encode_dict(dict)

func decode_envelope(bytes: PackedByteArray) -> MessageEnvelopeClass:
	var dict := decode_dict(bytes)
	if dict.is_empty():
		return null
	return MessageEnvelopeClass.from_dict(dict)

func encode_dict(dict: Dictionary) -> PackedByteArray:
	var json_str := JSON.stringify(dict)
	return json_str.to_utf8_buffer()

func decode_dict(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}
	var json_str := bytes.get_string_from_utf8()
	if json_str.is_empty():
		return {}
	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK or not (json.data is Dictionary):
		return {}
	return json.data
