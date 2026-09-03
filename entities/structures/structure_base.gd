class_name StructureBase
extends StaticBody2D

# res://entities/structures/structure_base.gd
# Base class for placeable base structures with occlusion transparency per Section B.3, B.4, C.4

const StructureDataClass = preload("res://scripts/data/structure_data.gd")
const HealthComponentClass = preload("res://scripts/components/health_component.gd")
const JuiceHelperClass = preload("res://scripts/systems/juice_helper.gd")
const GameStateMachine = preload("res://scripts/core/game_state_machine.gd")

@export var structure_data: Resource

var anchor_cell: Vector2i = Vector2i.ZERO
var rotation_quarters: int = 0
var occupied_cells: Array[Vector2i] = []
var current_health: float = 100.0

@onready var visual: Sprite2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_component: HealthComponentClass = get_node_or_null("HealthComponent")

var _occluding_bodies: Array[Node2D] = []
var _fade_tween: Tween

func _ready() -> void:
	collision_layer = 8 # Layer 4: Structure
	collision_mask = 0
	if structure_data != null and "max_health" in structure_data:
		current_health = structure_data.max_health
	if health_component != null:
		_bind_health_component()
	if structure_data != null and StringName(structure_data.id) == &"barricade_metal" and visual != null:
		visual.texture = load("res://assets/art/structures/barricade_metal.png")
		
	_setup_occlusion_detector()

func setup(data: Resource, anchor: Vector2i, rot_quarters: int, cells: Array[Vector2i]) -> void:
	structure_data = data
	anchor_cell = anchor
	rotation_quarters = rot_quarters
	occupied_cells = cells.duplicate()
	if data != null and "max_health" in data:
		current_health = data.max_health
	if health_component == null:
		health_component = HealthComponentClass.new()
		health_component.name = "HealthComponent"
		add_child(health_component)
	if health_component != null:
		_bind_health_component()
		health_component.max_health = current_health
		health_component.current_health = current_health

func receive_damage(amount: float, source: Node = null) -> bool:
	if health_component == null:
		health_component = get_node_or_null("HealthComponent") as HealthComponentClass
		if health_component != null:
			_bind_health_component()
	if health_component == null:
		return false
	return health_component.apply_damage(amount, source)

func _bind_health_component() -> void:
	if not health_component.health_changed.is_connected(_on_health_changed):
		health_component.health_changed.connect(_on_health_changed)
	if not health_component.damage_taken.is_connected(_on_damage_taken):
		health_component.damage_taken.connect(_on_damage_taken)
	if not health_component.died.is_connected(_on_health_died):
		health_component.died.connect(_on_health_died)
	if structure_data != null and "max_health" in structure_data:
		health_component.max_health = current_health
		health_component.current_health = current_health

func play_place_feedback() -> void:
	scale = Vector2(0.82, 0.82)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	var pool := JuiceHelperClass.vfx(self)
	if pool != null:
		pool.spawn_impact(global_position, Vector2.UP, Color(0.72, 0.88, 0.65, 1.0))
		pool.play_feedback(true)
	JuiceHelperClass.add_trauma(self, 0.025)

func _on_health_changed(current: float, _maximum: float) -> void:
	current_health = current

func _on_damage_taken(amount: float, source: Variant) -> void:
	var direction := Vector2.UP
	if source is Node2D:
		direction = (global_position - (source as Node2D).global_position).normalized()
	JuiceHelperClass.white_flash(visual, 0.05)
	var critical := bool(source.get("critical")) if source is Object and source.get("critical") != null else false
	JuiceHelperClass.hit_feedback(self, global_position + Vector2(0.0, -34.0), direction, amount, critical)
	var wobble := create_tween()
	wobble.tween_property(visual, "rotation", direction.x * 0.06, 0.035)
	wobble.tween_property(visual, "rotation", 0.0, 0.09)

func _on_health_died(_source: Variant) -> void:
	var gm := get_node_or_null("/root/GameManager")
	if structure_data != null and structure_data.kind == StructureDataClass.Kind.CORE:
		if gm != null and gm.current_state == GameStateMachine.State.NIGHT_DEFENSE:
			gm.complete_night(false)
		return
	if gm != null and gm.active_building_system != null and gm.active_building_system.has_method("remove_structure"):
		gm.active_building_system.remove_structure(self)
	else:
		queue_free()

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
