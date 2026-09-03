class_name VFXPool
extends Node2D

# Reuses transient presentation nodes and keeps cheap burst effects in one draw list.
# This avoids per-hit scene allocation while keeping gameplay ownership in entities.

const GhostShader = preload("res://assets/shaders/ghost.gdshader")

@export_range(8, 128) var max_ghosts: int = 48
@export_range(8, 128) var max_damage_labels: int = 48
@export_range(0, 48) var prewarm_ghosts: int = 16
@export_range(0, 48) var prewarm_damage_labels: int = 16
@export_range(0, 24) var prewarm_gpu_particles: int = 12

var _effects: Array[Dictionary] = []
var _ghosts: Array[Dictionary] = []
var _free_ghosts: Array[Sprite2D] = []
var _damage_labels: Array[Dictionary] = []
var _free_damage_labels: Array[Label] = []
var _gpu_particles: Array[Dictionary] = []
var _free_gpu_particles: Array[GPUParticles2D] = []
var _particle_texture: Texture2D
var _feedback_stream: AudioStreamWAV
var _audio_players: Array[AudioStreamPlayer] = []
var _audio_index: int = 0

func _ready() -> void:
	add_to_group("vfx_pool")
	z_index = 20
	for _i in range(prewarm_ghosts):
		_free_ghosts.append(_make_ghost())
	for _i in range(prewarm_damage_labels):
		_free_damage_labels.append(_make_damage_label())
	_particle_texture = _make_particle_texture()
	_feedback_stream = _make_feedback_stream()
	for _i in range(prewarm_gpu_particles):
		_free_gpu_particles.append(_make_gpu_particles())
	for _i in range(4):
		var audio_player := AudioStreamPlayer.new()
		audio_player.stream = _feedback_stream
		add_child(audio_player)
		_audio_players.append(audio_player)

func _process(delta: float) -> void:
	for i in range(_effects.size() - 1, -1, -1):
		var effect: Dictionary = _effects[i]
		effect["life"] = float(effect["life"]) - delta
		effect["position"] = Vector2(effect["position"]) + Vector2(effect["velocity"]) * delta
		_effects[i] = effect
		if float(effect["life"]) <= 0.0:
			_effects.remove_at(i)

	for i in range(_ghosts.size() - 1, -1, -1):
		var ghost_info: Dictionary = _ghosts[i]
		ghost_info["life"] = float(ghost_info["life"]) - delta
		var ghost: Sprite2D = ghost_info["node"] as Sprite2D
		ghost.modulate.a = clampf(float(ghost_info["life"]) / float(ghost_info["max_life"]), 0.0, 1.0) * 0.55
		_ghosts[i] = ghost_info
		if float(ghost_info["life"]) <= 0.0:
			ghost.visible = false
			_free_ghosts.append(ghost)
			_ghosts.remove_at(i)

	for i in range(_damage_labels.size() - 1, -1, -1):
		var label_info: Dictionary = _damage_labels[i]
		label_info["life"] = float(label_info["life"]) - delta
		var label: Label = label_info["node"] as Label
		label.position += Vector2(label_info["velocity"]) * delta
		label.modulate.a = clampf(float(label_info["life"]) / float(label_info["max_life"]), 0.0, 1.0)
		_damage_labels[i] = label_info
		if float(label_info["life"]) <= 0.0:
			label.visible = false
			_free_damage_labels.append(label)
			_damage_labels.remove_at(i)

	for i in range(_gpu_particles.size() - 1, -1, -1):
		var particle_info: Dictionary = _gpu_particles[i]
		particle_info["life"] = float(particle_info["life"]) - delta
		_gpu_particles[i] = particle_info
		if float(particle_info["life"]) <= 0.0:
			var particles: GPUParticles2D = particle_info["node"] as GPUParticles2D
			particles.emitting = false
			_free_gpu_particles.append(particles)
			_gpu_particles.remove_at(i)

	queue_redraw()

func spawn_muzzle_flash(world_position: Vector2, direction: Vector2) -> void:
	_add_effect(&"flash", world_position, direction.normalized() * 12.0, 0.045, Color(1.0, 0.8, 0.25, 1.0), 1.0)

func spawn_casing(world_position: Vector2, direction: Vector2) -> void:
	var ejection := direction.rotated(-PI * 0.5).normalized()
	_add_effect(&"casing", world_position, ejection * 80.0 + Vector2(0.0, 35.0), 0.28, Color(1.0, 0.78, 0.3, 1.0), 1.0)

func spawn_debris(world_position: Vector2, direction: Vector2, color: Color, intensity: float = 1.0) -> void:
	var base_direction := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	spawn_gpu_burst(world_position, base_direction, color, intensity)
	var count := clampi(int(ceil(7.0 * intensity)), 4, 14)
	for _i in range(count):
		var particle_direction := base_direction.rotated(deg_to_rad(randf_range(-60.0, 60.0)))
		var life := randf_range(0.18, 0.34)
		_add_effect(&"debris", world_position, particle_direction * randf_range(60.0, 180.0) * intensity, life, color, randf_range(2.0, 4.0))

func spawn_impact(world_position: Vector2, direction: Vector2, color: Color = Color(0.95, 0.75, 0.35, 1.0)) -> void:
	spawn_debris(world_position, direction, color, 0.8)
	_add_effect(&"ring", world_position, Vector2.ZERO, 0.18, color, 1.0)

func spawn_melee_arc(world_position: Vector2, direction: Vector2, radius: float, cone_angle: float, color: Color) -> void:
	_effects.append({"kind": &"arc", "position": world_position, "velocity": Vector2.ZERO, "life": 0.12, "max_life": 0.12, "color": color, "size": radius, "direction": direction.normalized(), "angle": cone_angle})

func play_feedback(positive: bool = true) -> void:
	if _audio_players.is_empty():
		return
	var player := _audio_players[_audio_index]
	_audio_index = (_audio_index + 1) % _audio_players.size()
	player.pitch_scale = 1.08 if positive else 0.72
	player.volume_db = -10.0 if positive else -14.0
	player.play()

func spawn_ghost(texture: Texture2D, world_position: Vector2) -> void:
	if texture == null:
		return
	var ghost: Sprite2D = _free_ghosts.pop_back() if not _free_ghosts.is_empty() else null
	if ghost == null and _ghosts.size() < max_ghosts:
		ghost = _make_ghost()
	if ghost == null:
		return
	ghost.texture = texture
	ghost.global_position = world_position
	ghost.modulate = Color(0.35, 0.9, 1.0, 0.55)
	ghost.visible = true
	_ghosts.append({"node": ghost, "life": 0.16, "max_life": 0.16})

func spawn_damage_text(world_position: Vector2, damage: float, critical: bool = false) -> void:
	var label: Label = _free_damage_labels.pop_back() if not _free_damage_labels.is_empty() else null
	if label == null and _damage_labels.size() < max_damage_labels:
		label = _make_damage_label()
	if label == null:
		return
	label.text = ("%d!" if critical else "%d") % maxi(1, int(round(damage)))
	label.position = to_local(world_position) - Vector2(24.0, 18.0)
	label.modulate = Color(1.0, 0.85, 0.25, 1.0) if critical else Color(1.0, 1.0, 1.0, 1.0)
	label.visible = true
	_damage_labels.append({"node": label, "life": 0.55, "max_life": 0.55, "velocity": Vector2(0.0, -42.0)})

func _add_effect(kind: StringName, world_position: Vector2, effect_velocity: Vector2, life: float, color: Color, size: float) -> void:
	_effects.append({"kind": kind, "position": world_position, "velocity": effect_velocity, "life": life, "max_life": life, "color": color, "size": size})

func _draw() -> void:
	for effect in _effects:
		var p := to_local(Vector2(effect["position"]))
		var ratio := clampf(float(effect["life"]) / float(effect["max_life"]), 0.0, 1.0)
		var color: Color = effect["color"]
		color.a *= ratio
		match StringName(effect["kind"]):
			&"flash":
				var direction: Vector2 = Vector2(effect["velocity"]).normalized()
				draw_line(p - direction * 5.0, p + direction * 24.0, color, 5.0 * ratio, true)
				draw_circle(p, 7.0 * ratio, Color(1.0, 0.95, 0.65, color.a))
			&"casing":
				draw_line(p, p + Vector2(effect["velocity"]) * 0.025, color, 2.5, true)
			&"debris":
				draw_circle(p, float(effect["size"]) * ratio, color)
			&"ring":
				var radius := (1.0 - ratio) * 24.0
				draw_arc(p, radius, 0.0, TAU, 20, color, 2.0 * ratio, true)
			&"arc":
				var arc_direction: Vector2 = Vector2(effect["direction"])
				var arc_angle: float = float(effect["angle"])
				var radius: float = float(effect["size"]) * (0.82 + ratio * 0.18)
				var wedge := PackedVector2Array([p])
				for i in range(13):
					wedge.append(p + arc_direction.rotated(-arc_angle * 0.5 + arc_angle * float(i) / 12.0) * radius)
				draw_colored_polygon(wedge, color)
				draw_arc(p, radius, arc_direction.angle() - arc_angle * 0.5, arc_direction.angle() + arc_angle * 0.5, 16, color, 3.0, true)

func _make_ghost() -> Sprite2D:
	var ghost := Sprite2D.new()
	ghost.material = ShaderMaterial.new()
	(ghost.material as ShaderMaterial).shader = GhostShader
	ghost.visible = false
	add_child(ghost)
	return ghost

func _make_damage_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(48.0, 28.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.visible = false
	add_child(label)
	return label

func spawn_gpu_burst(world_position: Vector2, direction: Vector2, color: Color, intensity: float) -> void:
	var particles: GPUParticles2D = _free_gpu_particles.pop_back() if not _free_gpu_particles.is_empty() else null
	if particles == null:
		return
	particles.global_position = world_position
	particles.modulate = color
	var process_material := particles.process_material as ParticleProcessMaterial
	process_material.direction = Vector3(direction.x, direction.y, 0.0)
	process_material.spread = 55.0
	process_material.initial_velocity_min = 70.0 * intensity
	process_material.initial_velocity_max = 180.0 * intensity
	particles.restart()
	particles.emitting = true
	_gpu_particles.append({"node": particles, "life": particles.lifetime})

func _make_gpu_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.amount = 12
	particles.lifetime = 0.28
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.visibility_rect = Rect2(-180.0, -180.0, 360.0, 360.0)
	particles.texture = _particle_texture
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 0.5
	process_material.scale_max = 1.0
	particles.process_material = process_material
	particles.emitting = false
	add_child(particles)
	return particles

func _make_particle_texture() -> Texture2D:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

func _make_feedback_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	var sample_count := 2205
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var envelope := 1.0 - float(i) / float(sample_count)
		var sample := sin(TAU * 440.0 * float(i) / 44100.0) * envelope * 0.18
		data.encode_s16(i * 2, int(sample * 32767.0))
	stream.data = data
	return stream
