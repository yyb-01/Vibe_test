class_name Survivor
extends Area2D

@export var rescue_reward: int = 50
@export_enum("Random", "Medic", "Gunner", "Scavenger") var support_role: String = "Random"
var rescued: bool = false
var action_timer: float = 0.0
var follow_offset: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if support_role == "Random":
		support_role = ["Medic", "Gunner", "Scavenger"].pick_random()
	follow_offset = Vector2(randf_range(-74.0, 74.0), randf_range(54.0, 96.0))
	_update_role_visual()

func _on_body_entered(body: Node2D) -> void:
	if rescued or not is_instance_valid(body) or body.is_queued_for_deletion() or not body.is_in_group("player"):
		return
	rescued = true
	RunStats.register_rescue()
	RunStats.set_companion(support_role)
	SaveManager.add_gold(rescue_reward)
	EventBus.survivor_rescued.emit(RunStats.survivors_rescued)
	EventBus.companion_recruited.emit(support_role)
	$CollisionShape2D.set_deferred("disabled", true)
	monitoring = false
	monitorable = false
	_update_role_visual()

func _process(delta: float) -> void:
	if not rescued:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		return
	global_position = global_position.lerp(player.global_position + follow_offset, minf(delta * 4.8, 1.0))
	action_timer = maxf(0.0, action_timer - delta)
	if action_timer > 0.0:
		return
	match support_role:
		"Medic":
			if player.health < player.max_health:
				player.heal(7)
				action_timer = 5.5
			else:
				action_timer = 1.6
		"Gunner":
			var target := _get_nearest_enemy()
			if is_instance_valid(target) and not target.is_queued_for_deletion() and target.has_method("take_damage"):
				target.take_damage(maxi(10, int(15.0 * player.damage_mult)), global_position.direction_to(target.global_position))
				action_timer = 1.15
			else:
				action_timer = 0.3
		"Scavenger":
			RunStats.add_scrap(4)
			action_timer = 8.0

func _get_nearest_enemy() -> Node2D:
	var closest: Node2D = null
	var closest_distance := 520.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy is CanvasItem and (not enemy.visible or enemy.process_mode == Node.PROCESS_MODE_DISABLED):
			continue
		var enemy_health = enemy.get("health")
		if enemy.get("is_dying") == true or enemy_health == null or int(enemy_health) <= 0:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest = enemy
			closest_distance = distance
	return closest

func _update_role_visual() -> void:
	if not sprite:
		return
	match support_role:
		"Medic": sprite.modulate = Color(0.35, 1.0, 0.72, 1.0)
		"Gunner": sprite.modulate = Color(1.0, 0.7, 0.3, 1.0)
		_: sprite.modulate = Color(0.38, 0.8, 1.0, 1.0)
