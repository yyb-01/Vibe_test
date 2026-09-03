class_name IsometricGridBuildingSystem
extends Node2D

# res://scripts/systems/isometric_grid_building_system.gd
# Base building manager handling isometric cell placement, validation, and debounced nav bake per Section E.1

const BuildGridClass = preload("res://scripts/systems/build_grid.gd")
const StructureDataClass = preload("res://scripts/data/structure_data.gd")
const StructureBaseClass = preload("res://entities/structures/structure_base.gd")
const GameStateMachine = preload("res://scripts/core/game_state_machine.gd")
const JuiceHelperClass = preload("res://scripts/systems/juice_helper.gd")

@export var ground_layer: TileMap
@export var structures_container: Node2D
@export var navigation_region: NavigationRegion2D
@export var enforce_game_state: bool = false

var build_grid: BuildGridClass = BuildGridClass.new()
var selected_structure: StructureDataClass = null
var current_anchor_cell: Vector2i = Vector2i.ZERO
var rotation_quarters: int = 0
var preview_cells: Array[Vector2i] = []
var is_current_placement_valid: bool = false
var last_validation_reason: StringName = &"none"
var _preview_blend: float = 0.0

var rebuild_timer: Timer

func _ready() -> void:
	# Setup rebuild timer for debounced navigation baking
	rebuild_timer = Timer.new()
	rebuild_timer.name = "RebuildTimer"
	rebuild_timer.one_shot = true
	rebuild_timer.wait_time = 0.15
	rebuild_timer.timeout.connect(_on_rebuild_timer_timeout)
	add_child(rebuild_timer)
	
	if ground_layer == null and get_parent() != null:
		ground_layer = get_parent().find_child("GroundLayer", true, false) as TileMap
	if structures_container == null and get_parent() != null:
		structures_container = get_parent().find_child("Actors", true, false) as Node2D

func _process(_delta: float) -> void:
	if selected_structure == null or ground_layer == null:
		if preview_cells.size() > 0:
			preview_cells.clear()
			queue_redraw()
		return
		
	# B.1: Convert local mouse to map cell
	var local_mouse: Vector2 = ground_layer.get_local_mouse_position()
	var cell: Vector2i = ground_layer.local_to_map(local_mouse)
	
	if cell != current_anchor_cell:
		current_anchor_cell = cell
		_update_preview()
	_preview_blend = move_toward(_preview_blend, 1.0 if is_current_placement_valid else 0.0, _delta * 12.0)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if selected_structure == null:
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.keycode == KEY_E:
			rotate_preview(true)
		elif event.keycode == KEY_Q:
			rotate_preview(false)
		elif event.keycode == KEY_ESCAPE:
			clear_selection()
			
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			try_place(selected_structure, current_anchor_cell, rotation_quarters)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			clear_selection()

func select_structure(data: StructureDataClass) -> void:
	selected_structure = data
	rotation_quarters = 0
	_update_preview()

func clear_selection() -> void:
	selected_structure = null
	preview_cells.clear()
	queue_redraw()

func rotate_preview(clockwise: bool = true) -> void:
	if clockwise:
		rotation_quarters = (rotation_quarters + 1) % 4
	else:
		rotation_quarters = (rotation_quarters + 3) % 4
	_update_preview()

func get_footprint_cells(anchor: Vector2i, footprint: Vector2i, rot_quarters: int) -> Array[Vector2i]:
	var eff_fp: Vector2i = footprint
	if rot_quarters % 2 == 1:
		eff_fp = Vector2i(footprint.y, footprint.x)
		
	var cells: Array[Vector2i] = []
	for dy in range(eff_fp.y):
		for dx in range(eff_fp.x):
			cells.append(anchor + Vector2i(dx, dy))
	return cells

func validate_placement(data: StructureDataClass, anchor: Vector2i, rot_quarters: int) -> Dictionary:
	if data == null:
		return {"valid": false, "reason": &"no_data", "cells": []}
		
	# 1. State check
	var gm = get_node_or_null("/root/GameManager")
	if enforce_game_state and gm != null:
		if gm.current_state != GameStateMachine.State.EVENING_PREP:
			return {"valid": false, "reason": &"wrong_state", "cells": []}
			
	var cells: Array[Vector2i] = get_footprint_cells(anchor, data.footprint, rot_quarters)
	
	# 2. In bounds check
	for c in cells:
		if not build_grid.is_in_bounds(c):
			return {"valid": false, "reason": &"out_of_bounds", "cells": cells}
			
	# 3. Occupied & Reserved check
	for c in cells:
		if build_grid.is_occupied(c):
			return {"valid": false, "reason": &"occupied", "cells": cells}
		if build_grid.is_reserved(c):
			return {"valid": false, "reason": &"reserved", "cells": cells}
			
	# 4. Required materials check
	var inv = get_node_or_null("/root/InventoryManager")
	if not data.required_materials.is_empty():
		if inv == null or not inv.has_materials(data.required_materials):
			return {"valid": false, "reason": &"insufficient_materials", "cells": cells}
			
	# 5. Route validation to core
	if data.blocks_navigation:
		if not build_grid.check_route_to_core(cells):
			return {"valid": false, "reason": &"blocks_required_route", "cells": cells}
			
	return {"valid": true, "reason": &"ok", "cells": cells}

func try_place(data: StructureDataClass, anchor: Vector2i, rot_quarters: int, free_placement: bool = false) -> bool:
	if data == null:
		last_validation_reason = &"no_data"
		return false
	var cells: Array[Vector2i] = []
	
	if not free_placement:
		var result: Dictionary = validate_placement(data, anchor, rot_quarters)
		if not result.get("valid", false):
			last_validation_reason = result.get("reason", &"invalid")
			_show_invalid_feedback(anchor)
			return false
		cells = result["cells"]
	else:
		cells = get_footprint_cells(anchor, data.footprint, rot_quarters)
		for c in cells:
			if not build_grid.is_in_bounds(c) or build_grid.is_occupied(c):
				return false
	
	# Transaction Step: Consume materials
	var inv = get_node_or_null("/root/InventoryManager")
	if not free_placement and not data.required_materials.is_empty():
		if inv == null or not inv.consume_materials(data.required_materials):
			last_validation_reason = &"insufficient_materials"
			_show_invalid_feedback(anchor)
			return false
			
	# Instantiate structure
	var structure_instance: Node2D = null
	if data.scene != null:
		structure_instance = data.scene.instantiate() as Node2D
	else:
		structure_instance = Node2D.new()
		
	if ground_layer != null:
		structure_instance.position = ground_layer.map_to_local(anchor)
	else:
		structure_instance.position = Vector2(anchor.x * 64, anchor.y * 32)
		
	if structure_instance is StructureBaseClass:
		structure_instance.setup(data, anchor, rot_quarters, cells)
		
	# Register in build grid
	build_grid.register_structure(structure_instance, cells, data.blocks_navigation)
	
	# Add to scene
	if structures_container != null:
		structures_container.add_child(structure_instance)
	else:
		add_child(structure_instance)
	if structure_instance.has_method("play_place_feedback"):
		structure_instance.play_place_feedback()
	else:
		JuiceHelperClass.add_trauma(self, 0.025)
		var pool := JuiceHelperClass.vfx(self)
		if pool != null:
			pool.spawn_impact(structure_instance.global_position, Vector2.UP, Color(0.7, 0.85, 0.65, 1.0))
		
	# Schedule debounced navigation rebake
	if rebuild_timer != null:
		rebuild_timer.start(0.15)
		
	var eb = get_node_or_null("/root/EventBus")
	if eb != null:
		eb.structure_placed.emit(structure_instance, cells)
	_update_preview()
	return true

func remove_structure(structure: Node) -> bool:
	if structure == null:
		return false
	var freed_cells: Array[Vector2i] = build_grid.unregister_structure(structure)
	if freed_cells.is_empty():
		return false
		
	var eb = get_node_or_null("/root/EventBus")
	if eb != null:
		eb.structure_removed.emit(structure, freed_cells)
	structure.queue_free()
	
	if rebuild_timer != null:
		rebuild_timer.start(0.15)
		
	_update_preview()
	return true

func _update_preview() -> void:
	if selected_structure == null:
		preview_cells.clear()
		queue_redraw()
		return
		
	var result: Dictionary = validate_placement(selected_structure, current_anchor_cell, rotation_quarters)
	is_current_placement_valid = result.get("valid", false)
	last_validation_reason = result.get("reason", &"unknown")
	preview_cells = result.get("cells", [])
	queue_redraw()

func _show_invalid_feedback(anchor: Vector2i) -> void:
	var world_position := ground_layer.to_global(ground_layer.map_to_local(anchor)) if ground_layer != null else global_position
	JuiceHelperClass.add_trauma(self, 0.03)
	var pool := JuiceHelperClass.vfx(self)
	if pool != null:
		pool.spawn_impact(world_position, Vector2.ZERO, Color(1.0, 0.2, 0.18, 1.0))
		pool.play_feedback(false)

func _draw() -> void:
	if selected_structure == null or preview_cells.is_empty() or ground_layer == null:
		return
		
	var fill_color: Color = Color(0.9, 0.2, 0.2, 0.45).lerp(Color(0.2, 0.85, 0.3, 0.45), _preview_blend)
	var border_color: Color = Color(1.0, 0.3, 0.3, 0.9).lerp(Color(0.3, 1.0, 0.4, 0.9), _preview_blend)
	var tile_size := ground_layer.tile_set.tile_size if ground_layer.tile_set != null else Vector2i(128, 64)
	var half_size := Vector2(tile_size.x * 0.5, tile_size.y * 0.5)
	
	for cell in preview_cells:
		var center_local: Vector2 = to_local(ground_layer.to_global(ground_layer.map_to_local(cell)))
		# The preview uses the same TileSet dimensions as the authoritative grid.
		var diamond: PackedVector2Array = [
			center_local + Vector2(0, -half_size.y),
			center_local + Vector2(half_size.x, 0),
			center_local + Vector2(0, half_size.y),
			center_local + Vector2(-half_size.x, 0)
		]
		draw_colored_polygon(diamond, fill_color)
		draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), border_color, 2.0)

func _on_rebuild_timer_timeout() -> void:
	if navigation_region != null and navigation_region.is_inside_tree():
		navigation_region.bake_navigation_polygon(true)
