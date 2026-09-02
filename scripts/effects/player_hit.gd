extends CPUParticles2D

var active_tween: Tween

func _ready() -> void:
	reset()

func reset() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	emitting = true
	active_tween = create_tween()
	active_tween.tween_interval(0.45)
	active_tween.tween_callback(func() -> void:
		ObjectPoolManager.release(self)
	)

func on_despawn() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = null
	emitting = false
