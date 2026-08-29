extends CPUParticles2D

func _ready() -> void:
	reset()

func reset() -> void:
	scale = Vector2.ONE
	emitting = true
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func(): ObjectPoolManager.release(self))
