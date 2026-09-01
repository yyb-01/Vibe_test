extends Node

const SFX_PATHS := {
	"shot": ["res://assets/audio/sfx/pistol_1.wav", "res://assets/audio/sfx/pistol_2.wav"],
	"shotgun": ["res://assets/audio/sfx/shotgun_1.wav", "res://assets/audio/sfx/shotgun_2.wav"],
	"casing": ["res://assets/audio/sfx/casing.ogg"],
	"lightning": ["res://assets/audio/sfx/lightning.ogg"],
	"impact": ["res://assets/audio/sfx/zombie_hit_1.wav", "res://assets/audio/sfx/zombie_hit_2.wav"],
	"zombie_hit": ["res://assets/audio/sfx/zombie_hit_1.wav", "res://assets/audio/sfx/zombie_hit_2.wav"],
	"zombie_cut": ["res://assets/audio/sfx/zombie_cut_1.wav", "res://assets/audio/sfx/zombie_cut_2.wav"],
	"zombie_hurt": ["res://assets/audio/sfx/zombie_hurt_1.ogg", "res://assets/audio/sfx/zombie_hurt_2.ogg"],
	"explosion": ["res://assets/audio/sfx/explosion.ogg"],
	"pickup": ["res://assets/audio/sfx/pickup.ogg"],
	"hurt": ["res://assets/audio/sfx/zombie_hurt_1.ogg"],
	"level_up": ["res://assets/audio/sfx/pickup.ogg"]
}
const WAVE_BGM := "res://assets/audio/wave_bgm.ogg"
const BOSS_BGM := "res://assets/audio/boss_bgm.ogg"

var players: Array[AudioStreamPlayer] = []
var named_sfx: Dictionary = {}
var bgm_player: AudioStreamPlayer
var current_bgm: String = ""

func _ready() -> void:
	for _index in range(20):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		players.append(player)
	for sound_name in SFX_PATHS:
		var streams: Array[AudioStream] = []
		for path in SFX_PATHS[sound_name]:
			var stream := load(path) as AudioStream
			if stream:
				streams.append(stream)
		named_sfx[sound_name] = streams
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.volume_db = -12.0
	add_child(bgm_player)
	EventBus.boss_status_changed.connect(_on_boss_status_changed)
	set_master_volume(SaveManager.master_volume)

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not stream:
		return
	var player := players[0]
	for candidate in players:
		if not candidate.playing:
			player = candidate
			break
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale * randf_range(0.9, 1.1)
	player.play()

func play_named(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var sounds: Array = named_sfx.get(sfx_name, [])
	if sounds.is_empty():
		return
	play_sfx(sounds.pick_random(), volume_db, pitch_scale)
	if sfx_name in ["shot", "shotgun"] and randf() < (0.45 if sfx_name == "shot" else 0.8):
		var casings: Array = named_sfx["casing"]
		play_sfx(casings.pick_random(), volume_db - 8.0, 1.0)

func play_wave_bgm() -> void:
	_play_bgm(WAVE_BGM)

func play_boss_bgm() -> void:
	_play_bgm(BOSS_BGM)

func _play_bgm(path: String) -> void:
	if current_bgm == path:
		return
	var stream := load(path) as AudioStreamOggVorbis
	if not stream:
		return
	stream.loop = true
	current_bgm = path
	bgm_player.stream = stream
	bgm_player.play()

func _on_boss_status_changed(boss_name: String, health_ratio: float, _phase: int) -> void:
	if boss_name != "" and health_ratio >= 0.0:
		play_boss_bgm()
	elif current_bgm == BOSS_BGM:
		play_wave_bgm()

func set_master_volume(value: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(clampf(value, 0.0, 1.0)))
