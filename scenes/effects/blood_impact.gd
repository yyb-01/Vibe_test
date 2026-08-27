extends CPUParticles2D

func _ready() -> void:
	emitting = true
	$Timer.timeout.connect(queue_free)
