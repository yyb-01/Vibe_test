class_name CameraShake
extends Camera2D

@export var max_offset: float = 9.0
@export var decay_speed: float = 45.0
@export var noise_speed: float = 28.0

var rng := RandomNumberGenerator.new()
var shake_strength: float = 0.0
var noise_time: float = 0.0
var noise_phase: float = 0.0

func _ready() -> void:
	noise_phase = rng.randf_range(0.0, TAU)
	EventBus.camera_shake_requested.connect(apply_shake)

func apply_shake() -> void:
	if not SaveManager.screen_shake_enabled:
		return
	shake_strength = maxf(shake_strength, max_offset)

func _process(delta: float) -> void:
	shake_strength = move_toward(shake_strength, 0.0, decay_speed * delta)
	noise_time += delta * noise_speed
	var target_offset := _smooth_offset() * shake_strength
	# Interpolating the offset removes the frame-to-frame 60px jumps caused by
	# independently random offsets, while retaining a short hit response.
	offset = offset.lerp(target_offset, minf(delta * 24.0, 1.0))
	if shake_strength <= 0.0 and offset.length_squared() < 0.01:
		offset = Vector2.ZERO

func _smooth_offset() -> Vector2:
	return Vector2(
		sin(noise_time + noise_phase),
		sin(noise_time * 1.73 + noise_phase * 1.41)
	)
