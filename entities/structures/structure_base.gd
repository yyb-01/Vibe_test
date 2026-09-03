class_name StructureBase
extends StaticBody2D

# res://entities/structures/structure_base.gd
# Base class for placeable base structures with occlusion transparency per Section B.3, B.4, C.4

const StructureDataClass = preload("res://scripts/data/structure_data.gd")

@export var structure_data: Resource

var anchor_cell: Vector2i = Vector2i.ZERO
var rotation_quarters: int = 0
var occupied_cells: Array[Vector2i] = []
var current_health: float = 100.0

@onready var visual: Sprite2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _occluding_bodies: Array[Node2D] = []
var _fade_tween: Tween

func _ready() -> void:
	collision_layer = 8 # Layer 4: Structure
	collision_mask = 0
	if structure_data != null and "max_health" in structure_data:
		current_health = structure_data.max_health
		
	_setup_occlusion_detector()

func setup(data: Resource, anchor: Vector2i, rot_quarters: int, cells: Array[Vector2i]) -> void:
	structure_data = data
	anchor_cell = anchor
	rotation_quarters = rot_quarters
	occupied_cells = cells.duplicate()
	if data != null and "max_health" in data:
		current_health = data.max_health

func _setup_occlusion_detector() -> void:
	var area = find_child("OcclusionArea", false, false) as Area2D
	if area == null:
		area = Area2D.new()
		area.name = "OcclusionArea"
		area.collision_layer = 0
		area.collision_mask = 6 # Layer 2 (Player=2) + Layer 3 (Enemy=4) -> 6
		
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(64, 80)
		col.shape = shape
		col.position = Vector2(0, -80)
		area.add_child(col)
		add_child(area)
		
	area.body_entered.connect(_on_occlusion_body_entered)
	area.body_exited.connect(_on_occlusion_body_exited)

func _on_occlusion_body_entered(body: Node2D) -> void:
	if body not in _occluding_bodies:
		_occluding_bodies.append(body)
		_apply_occlusion_alpha(0.35)

func _on_occlusion_body_exited(body: Node2D) -> void:
	_occluding_bodies.erase(body)
	if _occluding_bodies.is_empty():
		_apply_occlusion_alpha(1.0)

func _apply_occlusion_alpha(target_alpha: float) -> void:
	if visual == null:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(visual, "modulate:a", target_alpha, 0.15)
