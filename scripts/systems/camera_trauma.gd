class_name CameraTrauma
extends Camera2D

@export var max_offset: Vector2 = Vector2(9.0, 6.0)
@export var max_rotation: float = 0.018
@export var decay: float = 4.8

var trauma: float = 0.0
var _noise_time: float = 0.0
var _base_offset: Vector2
var _directional_kick: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("camera_trauma")
	_base_offset = offset

func add_trauma(amount: float, direction: Vector2 = Vector2.ZERO) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)
	if direction.length_squared() > 0.01:
		_directional_kick += direction.normalized() * amount

func _process(delta: float) -> void:
	_noise_time += delta * 38.0
	trauma = move_toward(trauma, 0.0, decay * delta)
	_directional_kick = _directional_kick.move_toward(Vector2.ZERO, delta * 3.5)
	var shake := trauma * trauma
	var noise_offset := Vector2(sin(_noise_time * 1.7), cos(_noise_time * 2.1)) * max_offset * shake
	offset = _base_offset + noise_offset + _directional_kick * max_offset
	rotation = sin(_noise_time * 1.3) * max_rotation * shake
