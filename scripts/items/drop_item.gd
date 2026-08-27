class_name DropItem
extends Area2D

enum ItemType { HEALTH_KIT, AMMO_BOX }

@export var type: ItemType = ItemType.HEALTH_KIT

var health_amount: int = 25
var ammo_amount: int = 12

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Update visual based on type
	var rect := $ColorRect as ColorRect
	if type == ItemType.HEALTH_KIT:
		rect.color = Color.GREEN
	else:
		rect.color = Color.BLUE

	# Despawn after 10 seconds to keep map clean
	var timer := get_tree().create_timer(10.0)
	timer.timeout.connect(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var player := body as Player
		if player:
			if type == ItemType.HEALTH_KIT:
				player.heal(health_amount)
			elif type == ItemType.AMMO_BOX:
				player.add_ammo(ammo_amount)
			queue_free()
