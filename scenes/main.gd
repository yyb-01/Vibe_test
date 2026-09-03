class_name Main
extends Node2D

# res://scenes/main.gd
# Root coordinator orchestrating game states, world transitions, and UI overlays

@onready var world_container: Node2D = $IsometricWorld
@onready var actors_container: Node2D = $IsometricWorld/Actors
@onready var player: Player = $IsometricWorld/Actors/Player
@onready var ui_layer: CanvasLayer = $UILayer

@onready var map_select_ui: Control = $UILayer/MapSelect
@onready var build_panel_ui: Control = $UILayer/BuildPanel
@onready var wave_hud_ui: Control = $UILayer/WaveHUD
@onready var day_summary_ui: Control = $UILayer/DaySummary
@onready var phase_label: Label = $UILayer/HUD/PhaseLabel
@onready var building_manager: IsometricGridBuildingSystem = $BuildingManager
@onready var wave_controller: WaveController = $WaveController
@onready var night_modulate: CanvasModulate = $CanvasModulate

var _current_expedition_scene: Node2D = null

func _ready() -> void:
	if world_container == null:
		world_container = find_child("IsometricWorld", true, false) as Node2D
	if actors_container == null:
		actors_container = find_child("Actors", true, false) as Node2D
	if player == null:
		player = find_child("Player", true, false) as Player

	var gm = get_node_or_null("/root/GameManager")
	var eb = get_node_or_null("/root/EventBus")
	
	if gm != null:
		gm.active_building_system = building_manager
		
	if building_manager != null and world_container != null:
		building_manager.ground_layer = world_container.find_child("GroundLayer", true, false) as TileMap
		building_manager.structures_container = actors_container
		
	if build_panel_ui != null:
		build_panel_ui.building_system = building_manager
		
	if wave_controller != null and night_modulate != null:
		wave_controller.night_modulate = night_modulate
		wave_controller.enemies_container = actors_container
		
	if eb != null:
		eb.game_state_changed.connect(_on_game_state_changed)
		
	_update_ui_for_state(gm.current_state if gm != null else 0)

func _on_game_state_changed(_prev: int, curr: int) -> void:
	_update_ui_for_state(curr)

func _update_ui_for_state(state: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	
	# Hide all overlays by default
	if map_select_ui != null:
		map_select_ui.visible = false
	if build_panel_ui != null:
		build_panel_ui.visible = false
	if wave_hud_ui != null:
		wave_hud_ui.visible = false
	if day_summary_ui != null:
		day_summary_ui.visible = false
		
	var state_name = GameStateMachine.STATE_NAMES.get(state, "HUB")
	if phase_label != null:
		var day_num = gm.day if gm != null else 1
		phase_label.text = "DAY %d | %s" % [day_num, state_name]
		
	match state:
		GameStateMachine.State.HUB:
			_set_base_world_visible(true)
			if map_select_ui != null:
				map_select_ui.visible = true
			if _current_expedition_scene != null:
				_current_expedition_scene.queue_free()
				_current_expedition_scene = null
			if player != null:
				player.position = Vector2.ZERO
				player.visible = true
				
		GameStateMachine.State.EXPEDITION:
			_set_base_world_visible(false)
			_load_expedition_map()
			
		GameStateMachine.State.EVENING_PREP:
			_set_base_world_visible(true)
			if build_panel_ui != null:
				build_panel_ui.visible = true
			if _current_expedition_scene != null:
				_current_expedition_scene.queue_free()
				_current_expedition_scene = null
			if player != null:
				player.position = Vector2.ZERO
				player.visible = true
				
		GameStateMachine.State.NIGHT_DEFENSE:
			_set_base_world_visible(true)
			if wave_hud_ui != null:
				wave_hud_ui.visible = true
			if wave_controller != null:
				wave_controller.start_wave()
				
		GameStateMachine.State.DAY_SUMMARY:
			_set_base_world_visible(true)
			if day_summary_ui != null:
				day_summary_ui.visible = true
				day_summary_ui.update_display()

func _set_base_world_visible(p_visible: bool) -> void:
	if world_container != null:
		var base_ground = world_container.find_child("GroundLayer", false, false) as Node2D
		if base_ground != null:
			base_ground.visible = p_visible
			base_ground.process_mode = Node.PROCESS_MODE_INHERIT if p_visible else Node.PROCESS_MODE_DISABLED
	if actors_container != null:
		var core = actors_container.find_child("BaseCore", false, false) as Node2D
		if core != null:
			core.visible = p_visible
			core.process_mode = Node.PROCESS_MODE_INHERIT if p_visible else Node.PROCESS_MODE_DISABLED
			for child in core.get_children():
				if child is CollisionShape2D or child is CollisionPolygon2D:
					child.set_deferred("disabled", not p_visible)
	if building_manager != null:
		building_manager.visible = p_visible
		building_manager.process_mode = Node.PROCESS_MODE_INHERIT if p_visible else Node.PROCESS_MODE_DISABLED

func _load_expedition_map() -> void:
	if _current_expedition_scene != null:
		_current_expedition_scene.process_mode = Node.PROCESS_MODE_DISABLED
		_current_expedition_scene.visible = false
		_current_expedition_scene.queue_free()
		_current_expedition_scene = null
		
	var gm = get_node_or_null("/root/GameManager")
	var map_id: StringName = gm.selected_map_id if gm != null else &"forest"
	var path: String = "res://scenes/expedition/%s.tscn" % String(map_id)
	if ResourceLoader.exists(path):
		var scene = load(path)
		_current_expedition_scene = scene.instantiate() as Node2D
		world_container.add_child(_current_expedition_scene)
		
	var spawn_pos: Vector2 = Vector2(0, 160)
	if _current_expedition_scene != null:
		var extract_zone = _current_expedition_scene.find_child("ExtractionZone", true, false) as Area2D
		if extract_zone != null:
			# Offset 120px away from zone center (radius 64px) to prevent instant accidental extraction
			spawn_pos = extract_zone.position + Vector2(0, 120)
			
	if player != null:
		player.position = spawn_pos
		player.visible = true


