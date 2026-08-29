class_name ExpGem
extends Area2D

@export var exp_amount: int = 10
var speed: float = 0.0
var target: Node2D = null
var magnet_range: float = 150.0

var float_tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	reset()

func reset() -> void:
	speed = 0.0
	target = get_tree().get_first_node_in_group("player")
	$Sprite2D.position.y = 0
	set_exp_amount(10)

	if float_tween:
		float_tween.kill()
	float_tween = create_tween().set_loops()
	float_tween.tween_property($Sprite2D, "position:y", -5.0, 1.0).as_relative().set_trans(Tween.TRANS_SINE)
	float_tween.tween_property($Sprite2D, "position:y", 5.0, 1.0).as_relative().set_trans(Tween.TRANS_SINE)

	SpatialGrid.insert_item(self)

func get_exp_amount() -> int:
	return exp_amount

func set_exp_amount(amount: int) -> void:
	exp_amount = amount
	var sprite = $Sprite2D as Polygon2D
	if exp_amount > 500:
		sprite.color = Color.RED
		sprite.scale = Vector2(2.0, 2.0)
	elif exp_amount > 100:
		sprite.color = Color.PURPLE
		sprite.scale = Vector2(1.5, 1.5)
	else:
		sprite.color = Color(0, 0.8, 1, 1) # Blue
		sprite.scale = Vector2(1.0, 1.0)

func _physics_process(delta: float) -> void:
	if not target:
		target = get_tree().get_first_node_in_group("player")
		return

	var dist = global_position.distance_to(target.global_position)
	if dist < magnet_range or speed > 0:
		# Magnet effect accelerates smoothly as it gets closer
		speed += 1200.0 * delta
		global_position = global_position.move_toward(target.global_position, speed * delta)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("add_exp"):
			body.add_exp(exp_amount)
			AudioManager.play_named("pickup", -10.0, randf_range(0.95, 1.1))
		SpatialGrid.remove_item(self)
		ObjectPoolManager.release(self)
