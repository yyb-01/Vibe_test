class_name ExpGem
extends Area2D

@export var exp_amount: int = 10
var speed: float = 0.0
var target: Node2D = null
var magnet_range: float = 150.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Initial floating animation
	var tween = create_tween().set_loops()
	tween.tween_property($Sprite2D, "position:y", -5.0, 1.0).as_relative().set_trans(Tween.TRANS_SINE)
	tween.tween_property($Sprite2D, "position:y", 5.0, 1.0).as_relative().set_trans(Tween.TRANS_SINE)

func _physics_process(delta: float) -> void:
	if not target:
		target = get_tree().get_first_node_in_group("player")
		return

	var dist = global_position.distance_to(target.global_position)
	if dist < magnet_range or speed > 0:
		# Magnet effect accelerates as it gets closer
		speed += 800.0 * delta
		var dir = global_position.direction_to(target.global_position)
		position += dir * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("add_exp"):
			body.add_exp(exp_amount)
		queue_free()
