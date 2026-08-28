extends Node

var pool_size: int = 16
var players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	# Pre-warm audio players
	for i in range(pool_size):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)

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
