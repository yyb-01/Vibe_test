class_name OperationPlayer
extends CharacterBody2D

var movement_speed: float = 0.0
var movement_bounds := Rect2()

func _ready() -> void:
	set_physics_process(false)

func configure(next_speed: float, bounds: Rect2) -> void:
	movement_speed = next_speed
	movement_bounds = bounds

func set_enabled(enabled: bool) -> void:
	velocity = Vector2.ZERO
	set_physics_process(enabled)

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * movement_speed
	move_and_slide()
	position.x = clampf(position.x, movement_bounds.position.x, movement_bounds.end.x)
	position.y = clampf(position.y, movement_bounds.position.y, movement_bounds.end.y)
