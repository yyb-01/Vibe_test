class_name EnemyAgent
extends Node2D

const ENEMY_TEXTURES: Dictionary = {
	&"scavenger": preload("res://assets/generated/enemy_scavenger.png"),
	&"runner": preload("res://assets/generated/enemy_runner.png"),
	&"brute": preload("res://assets/generated/enemy_brute.png"),
}

var sprite: Sprite2D

var enemy_id: StringName
var archetype_id: StringName = &"scavenger"
var cell: Vector2i
var health: int = 1
var max_health: int = 1

func configure(next_id: StringName, next_cell: Vector2i, next_max_health: int, next_archetype_id: StringName = &"scavenger") -> void:
	enemy_id = next_id
	archetype_id = next_archetype_id if ENEMY_TEXTURES.has(next_archetype_id) else &"scavenger"
	max_health = maxi(1, next_max_health)
	health = max_health
	sprite.texture = ENEMY_TEXTURES[archetype_id]
	sprite.scale = Vector2.ONE * 0.045
	set_cell(next_cell)
	visible = true

func set_cell(next_cell: Vector2i) -> void:
	cell = next_cell
	position = Vector2(cell) * 32.0
	queue_redraw()

func set_health(next_health: int) -> void:
	health = clampi(next_health, 0, max_health)
	queue_redraw()

func clear() -> void:
	visible = false

func _ready() -> void:
	sprite = get_node_or_null("Sprite")
	if sprite == null:
		sprite = Sprite2D.new()
		add_child(sprite)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0, 5), 13.0, Color(0.02, 0.03, 0.04, 0.35))
	draw_rect(Rect2(-14.0, -25.0, 28.0, 4.0), Color("321f25"))
	draw_rect(Rect2(-14.0, -25.0, 28.0 * float(health) / float(max_health), 4.0), Color("e07a5f"))
