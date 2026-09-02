extends Node

const HIT_STOP_SCALE := 0.05
const DEFAULT_HIT_STOP_DURATION := 0.05
const FLASH_DURATION := 0.08
const MAX_TRAUMA := 1.5
const HEAVY_TYPES := ["shotgun", "explosion", "explosive", "nova", "railgun", "heavy", "critical", "execute", "산탄", "폭발", "충격파", "자폭"]

@export var max_shake_offset: float = 9.0
@export var shake_decay: float = 4.5
@export var noise_speed: float = 18.0

var _noise := FastNoiseLite.new()
var _noise_time: float = 0.0
var _last_time: float = 0.0
var _trauma: float = 0.0
var _direction := Vector2.ZERO
var _camera_offset := Vector2.ZERO
var _hit_stop_tween: Tween
var _hit_stop_duration: float = 0.0
var _flash_tweens: Dictionary = {}
var _flash_tokens: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.seed = randi()
	_noise.frequency = 0.08
	_last_time = _now()
	EventBus.camera_shake_requested.connect(_on_legacy_camera_shake)

func _process(_delta: float) -> void:
	var now := _now()
	var real_delta := clampf(now - _last_time, 0.0, 0.1)
	_last_time = now
	_trauma = move_toward(_trauma, 0.0, shake_decay * real_delta)
	_noise_time += real_delta * noise_speed

	var strength := pow(_trauma / MAX_TRAUMA, 2.0)
	var noise_offset := Vector2(_noise.get_noise_1d(_noise_time), _noise.get_noise_1d(_noise_time + 31.7))
	var target := noise_offset * max_shake_offset * strength
	target += _direction * max_shake_offset * strength * 0.45
	_camera_offset = _camera_offset.lerp(target, minf(real_delta * 24.0, 1.0))
	if _trauma <= 0.001 and _camera_offset.length_squared() < 0.01:
		_camera_offset = Vector2.ZERO
		_direction = Vector2.ZERO

func play_hit(damage: float, weapon_type: String = "", direction: Vector2 = Vector2.ZERO) -> void:
	if damage <= 0.0:
		return
	var heavy := _is_heavy_type(weapon_type)
	var duration := 0.07 if heavy else DEFAULT_HIT_STOP_DURATION
	if damage >= 80.0:
		duration = maxf(duration, 0.08)
	hit_stop(damage, weapon_type, duration)
	var trauma := clampf(0.18 + damage / 140.0, 0.18, 0.75)
	if heavy:
		trauma = maxf(trauma, 0.6)
	shake_camera(trauma, direction)

func hit_stop(damage: float = 0.0, weapon_type: String = "", duration: float = DEFAULT_HIT_STOP_DURATION) -> void:
	var resolved_duration := maxf(duration, 0.01)
	if _is_heavy_type(weapon_type):
		resolved_duration = maxf(resolved_duration, 0.07)
	elif damage >= 80.0:
		resolved_duration = maxf(resolved_duration, 0.08)
	if _hit_stop_tween and _hit_stop_tween.is_valid():
		if resolved_duration <= _hit_stop_duration:
			return
		_hit_stop_tween.kill()
	Engine.time_scale = HIT_STOP_SCALE
	_hit_stop_duration = resolved_duration
	_hit_stop_tween = create_tween()
	# Godot 4.2 has no Tween.set_ignore_time_scale(). Compensate for the
	# slowed frame delta while keeping the recovery controlled by a Tween.
	_hit_stop_tween.set_speed_scale(1.0 / HIT_STOP_SCALE)
	_hit_stop_tween.tween_interval(resolved_duration)
	_hit_stop_tween.tween_callback(_restore_time_scale)

func cancel_hit_stop() -> void:
	if _hit_stop_tween and _hit_stop_tween.is_valid():
		_hit_stop_tween.kill()
	_hit_stop_tween = null
	_hit_stop_duration = 0.0
	Engine.time_scale = 1.0

func shake_camera(trauma: float, direction: Vector2 = Vector2.ZERO) -> void:
	if not SaveManager.screen_shake_enabled:
		return
	var value := clampf(trauma, 0.0, MAX_TRAUMA)
	if value <= 0.0:
		return
	_trauma = maxf(_trauma, value)
	if direction.length_squared() > 0.001:
		_direction = direction.normalized()

func get_camera_offset() -> Vector2:
	return _camera_offset if SaveManager.screen_shake_enabled else Vector2.ZERO

func flash_sprite(target: CanvasItem, duration: float = FLASH_DURATION) -> void:
	if not is_instance_valid(target) or not target.material is ShaderMaterial:
		return
	var id := target.get_instance_id()
	var old_tween = _flash_tweens.get(id)
	if old_tween is Tween and old_tween.is_valid():
		old_tween.kill()
	var token := int(_flash_tokens.get(id, 0)) + 1
	_flash_tokens[id] = token
	var material := target.material as ShaderMaterial
	material.set_shader_parameter("flash_color", Color.WHITE)
	material.set_shader_parameter("active", true)
	var tween := create_tween()
	tween.set_speed_scale(1.0 / maxf(Engine.time_scale, 0.01))
	tween.tween_interval(maxf(duration, 0.01))
	tween.tween_callback(func() -> void:
		if int(_flash_tokens.get(id, -1)) == token:
			_flash_tweens.erase(id)
			_flash_tokens.erase(id)
			if is_instance_valid(target):
				var current_material := target.material as ShaderMaterial
				if current_material:
					current_material.set_shader_parameter("active", false)
	)
	_flash_tweens[id] = tween

func _on_legacy_camera_shake(intensity: float) -> void:
	shake_camera(intensity)

func _restore_time_scale() -> void:
	Engine.time_scale = 1.0
	_hit_stop_duration = 0.0
	_hit_stop_tween = null

func _is_heavy_type(weapon_type: String) -> bool:
	var value := weapon_type.to_lower()
	for keyword in HEAVY_TYPES:
		if value.contains(keyword):
			return true
	return false

func _now() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0

func _exit_tree() -> void:
	cancel_hit_stop()
	for tween in _flash_tweens.values():
		if tween is Tween and tween.is_valid():
			tween.kill()
	_flash_tweens.clear()
	_flash_tokens.clear()
	Engine.time_scale = 1.0
