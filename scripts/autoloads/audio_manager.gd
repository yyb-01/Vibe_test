extends Node

var pool_size: int = 16
var players: Array[AudioStreamPlayer] = []
var named_sfx: Dictionary = {}

func _ready() -> void:
	# Pre-warm audio players
	for i in range(pool_size):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)
	named_sfx["shot"] = _make_tone(180.0, 0.07, 0.28)
	named_sfx["shotgun"] = _make_tone(90.0, 0.16, 0.42)
	named_sfx["lightning"] = _make_tone(520.0, 0.14, 0.24)
	named_sfx["impact"] = _make_tone(260.0, 0.06, 0.18)
	named_sfx["pickup"] = _make_tone(680.0, 0.08, 0.16)
	named_sfx["hurt"] = _make_tone(110.0, 0.12, 0.3)
	named_sfx["level_up"] = _make_tone(740.0, 0.32, 0.22)
	set_master_volume(SaveManager.master_volume)

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not stream:
		return

	# Find first available player
	for p in players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch_scale
			p.play()
			return

	# Interruption fallback
	if players.size() > 0:
		players[0].stream = stream
		players[0].volume_db = volume_db
		players[0].pitch_scale = pitch_scale
		players[0].play()

func play_named(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	play_sfx(named_sfx.get(sfx_name), volume_db, pitch_scale)

func set_master_volume(value: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(clampf(value, 0.0, 1.0)))

func _make_tone(frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	const MIX_RATE := 22050
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	var sample_count := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / MIX_RATE
		var envelope := 1.0 - (float(i) / sample_count)
		var sample := sin(TAU * frequency * t) * amplitude * envelope
		data.encode_s16(i * 2, int(sample * 32767.0))
	stream.data = data
	return stream
