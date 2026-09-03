class_name ResourceNode
extends StaticBody2D

# res://scenes/expedition/resource_node.gd
# Harvestable world resource node with hit feedback and remaining amount tracking

signal harvested(item_id: StringName, amount_harvested: int, remaining: int)
signal depleted()

@export var item_id: StringName = &"wood"
@export var max_amount: int = 10
@export var remaining_amount: int = 10
@export var harvest_per_interaction: int = 2

@onready var visual: Sprite2D = $Visual
@onready var hit_particles: GPUParticles2D = $HitParticles
@onready var interaction_area: Area2D = $InteractionArea

var _is_player_nearby: bool = false
var _original_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	_original_scale = scale
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func setup(p_item_id: StringName, p_amount: int) -> void:
	item_id = p_item_id
	max_amount = p_amount
	remaining_amount = p_amount

func interact(harvester: Node = null) -> int:
	if remaining_amount <= 0:
		return 0
		
	var to_harvest: int = mini(harvest_per_interaction, remaining_amount)
	# Attempt adding to inventory bag
	var added: int = InventoryManager.add_to_bag(item_id, to_harvest)
	
	if added > 0:
		remaining_amount -= added
		_play_feedback()
		harvested.emit(item_id, added, remaining_amount)
		
		if remaining_amount <= 0:
			depleted.emit()
			_on_depleted()
	# If added == 0, bag is full and remaining_amount stays in world untouched
	return added

func _play_feedback() -> void:
	if hit_particles != null:
		hit_particles.restart()
		
	# Section F.2: Micro-loop feedback - wobble / flash
	var tween: Tween = create_tween()
	tween.tween_property(visual, "scale", Vector2(1.15, 0.85), 0.05)
	tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.08)

func _on_depleted() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_is_player_nearby = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_is_player_nearby = false

func _unhandled_input(event: InputEvent) -> void:
	# Key E or left click when player is nearby
	if _is_player_nearby and remaining_amount > 0:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
			interact()

