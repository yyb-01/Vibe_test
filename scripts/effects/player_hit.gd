extends CPUParticles2D

func _ready() -> void:
	reset()

func reset() -> void:
	emitting = true
	var tween := create_tween()
	tween.tween_interval(0.45)
	tween.tween_callback(func() -> void:
		ObjectPoolManager.release(self)
	)
