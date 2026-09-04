class_name PickupView
extends Node2D

const ITEM_TEXTURES: Dictionary = {
	&"wood": preload("res://assets/generated/wood_salvage.png"),
	&"scrap": preload("res://assets/generated/resource_scrap.png"),
	&"stone": preload("res://assets/generated/resource_stone.png"),
	&"medicine": preload("res://assets/generated/resource_medicine.png"),
}

var sprite: Sprite2D

var pickup_id: StringName
var item_id: StringName
var amount: int = 0

func _ready() -> void:
	sprite = get_node_or_null("Sprite")
	if sprite == null:
		sprite = Sprite2D.new()
		add_child(sprite)

func configure(next_id: StringName, next_item_id: StringName, next_amount: int) -> void:
	pickup_id = next_id
	item_id = next_item_id
	amount = next_amount
	sprite.texture = ITEM_TEXTURES.get(item_id, ITEM_TEXTURES[&"wood"])
	sprite.scale = Vector2.ONE * 0.04
	visible = true
	queue_redraw()

func clear() -> void:
	visible = false
	amount = 0
	queue_redraw()

func _draw() -> void:
	for index in range(mini(amount, 5)):
		draw_circle(Vector2(-12.0 + index * 6.0, 22.0), 2.5, Color("d8d0a8"))
