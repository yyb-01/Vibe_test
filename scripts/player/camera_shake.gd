class_name CameraShake
extends Camera2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func apply_shake(intensity: float) -> void:
	HitEffectManager.shake_camera(intensity)

func _process(_delta: float) -> void:
	offset = HitEffectManager.get_camera_offset()
