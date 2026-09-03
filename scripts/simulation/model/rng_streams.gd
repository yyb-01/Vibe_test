class_name RngStreams
extends RefCounted

# res://scripts/simulation/model/rng_streams.gd
# Deterministic named RNG streams for simulation rules.

var streams: Dictionary = {}

const STREAM_NAMES: Array[String] = ["loot", "wave", "ai", "combat"]

func _init(base_seed: int = 12345) -> void:
	setup(base_seed)

func setup(base_seed: int) -> void:
	streams.clear()
	for i in range(STREAM_NAMES.size()):
		var name := STREAM_NAMES[i]
		var rng := RandomNumberGenerator.new()
		rng.seed = base_seed + (i * 7919)
		streams[name] = rng

func get_stream(name: String) -> RandomNumberGenerator:
	if not streams.has(name):
		var rng := RandomNumberGenerator.new()
		rng.seed = 12345
		streams[name] = rng
	return streams[name]

func randf_range(stream_name: String, from_val: float, to_val: float) -> float:
	return get_stream(stream_name).randf_range(from_val, to_val)

func randi_range(stream_name: String, from_val: int, to_val: int) -> int:
	return get_stream(stream_name).randi_range(from_val, to_val)

func randf(stream_name: String) -> float:
	return get_stream(stream_name).randf()

func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for name in streams:
		var rng: RandomNumberGenerator = streams[name]
		result[name] = {
			"seed": rng.seed,
			"state": rng.state
		}
	return result

func from_dict(d: Dictionary) -> void:
	for name in d:
		if d[name] is Dictionary:
			var rng := RandomNumberGenerator.new()
			rng.seed = int(d[name].get("seed", 12345))
			rng.state = int(d[name].get("state", 0))
			streams[name] = rng
