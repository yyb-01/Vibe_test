class_name Main
extends Node2D

# res://scenes/main.gd
# Root coordinator orchestrating game states, world transitions, and UI overlays

const CameraTraumaClass = preload("res://scripts/systems/camera_trauma.gd")
const GameCompositionRootClass = preload("res://scripts/bootstrap/game_composition_root.gd")

@onready var world_container: Node2D = $IsometricWorld
@onready var actors_container: Node2D = $IsometricWorld/Actors
@onready var player: Player = $IsometricWorld/Actors/Player
@onready var ui_layer: CanvasLayer = $UILayer

@onready var map_select_ui: Control = $UILayer/MapSelect
@onready var build_panel_ui: Control = $UILayer/BuildPanel
@onready var wave_hud_ui: Control = $UILayer/WaveHUD
@onready var day_summary_ui: Control = $UILayer/DaySummary
@onready var expedition_hud_ui: ExpeditionHUD = $UILayer/ExpeditionHUD
@onready var phase_label: Label = $UILayer/HUD/PhaseLabel
@onready var building_manager: IsometricGridBuildingSystem = $BuildingManager
@onready var wave_controller: WaveController = $WaveController
@onready var night_modulate: CanvasModulate = $CanvasModulate
@onready var storage_label: Label = $UILayer/HUD/StorageLabel
@onready var status_label: Label = $UILayer/HUD/StatusLabel


var _current_expedition_scene: Node2D = null
var _expedition_player: Player = null

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
		building_manager.navigation_region = world_container.find_child("NavigationRegion2D", true, false) as NavigationRegion2D
		_configure_build_grid()
		
	if build_panel_ui != null:
		build_panel_ui.building_system = building_manager
		
	if wave_controller != null and night_modulate != null:
		wave_controller.night_modulate = night_modulate
		wave_controller.enemies_container = actors_container
		
	if eb != null:
		eb.game_state_changed.connect(_on_game_state_changed)
		eb.inventory_changed.connect(_on_inventory_changed)
	if gm != null:
		var save_manager := get_node_or_null("/root/SaveManager")
		if save_manager != null and save_manager.has_save_file():
			gm.load_saved_game()
		gm.create_day_start_snapshot()

	var comp_root := GameCompositionRootClass.new()
	comp_root.name = "GameCompositionRoot"
	add_child(comp_root)
	if gm != null and gm.has_method("bind_composition_root"):
		gm.bind_composition_root(comp_root)
	var vfx = find_child("VFXPool", true, false)
	var cam = find_child("CameraTrauma", true, false)
	comp_root.link_presentation_nodes(vfx, cam, actors_container)
	if player != null and comp_root.entity_view_registry != null:
		comp_root.entity_view_registry.register_view(100, player)

	_update_ui_for_state(gm.current_state if gm != null else 0)
	_update_runtime_hud()

func _on_inventory_changed(_container: StringName) -> void:
	_update_runtime_hud()

func _configure_build_grid() -> void:
	if building_manager == null or building_manager.ground_layer == null:
		return
	var region := building_manager.ground_layer.get_used_rect()
	if region.size == Vector2i.ZERO:
		region = Rect2i(-15, -15, 31, 31)
	var core_cells := building_manager.get_footprint_cells(Vector2i.ZERO, Vector2i(2, 2), 0)
	var spawn_cells: Array[Vector2i] = []
	for candidate in [Vector2i(region.position.x, 0), Vector2i(region.end.x - 1, 0), Vector2i(0, region.position.y), Vector2i(0, region.end.y - 1)]:
		if region.has_point(candidate) and candidate not in core_cells and candidate not in spawn_cells:
			spawn_cells.append(candidate)
	building_manager.build_grid.setup(region, core_cells, spawn_cells)
	var core := actors_container.find_child("BaseCore", false, false) as StructureBase
	if core != null:
		var core_data := load("res://data/structures/base_core.tres") as StructureData
		core.setup(core_data, Vector2i.ZERO, 0, core_cells)

func _update_runtime_hud() -> void:
	if storage_label == null:
		return
	var inventory := get_node_or_null("/root/InventoryManager")
	if inventory == null:
		return
	var storage: Dictionary = inventory.storage
	storage_label.text = "WOOD %d   SCRAP %d   ELEC %d   AMMO %d" % [int(storage.get(&"wood", 0)), int(storage.get(&"scrap_metal", 0)), int(storage.get(&"electronics", 0)), int(storage.get(&"ammo", 0))]
	if status_label != null:
		var gm := get_node_or_null("/root/GameManager")
		if gm != null and gm.current_state == GameStateMachine.State.EVENING_PREP:
			status_label.text = "LMB PLACE   R/E ROTATE   Q ROTATE BACK   RMB CANCEL   N START NIGHT"
		elif gm != null and gm.current_state == GameStateMachine.State.NIGHT_DEFENSE:
			status_label.text = "WASD MOVE   LMB FIRE   RMB MELEE   SPACE DASH / I-FRAME"
		else:
			status_label.text = "WASD MOVE   LMB FIRE   SPACE DASH   E INTERACT"

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
	if expedition_hud_ui != null:
		expedition_hud_ui.visible = false
		
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
				_clear_expedition_scene()
			if player != null:
				player.position = Vector2.ZERO
				player.visible = true
				
		GameStateMachine.State.EXPEDITION:
			_set_base_world_visible(false)
			_load_expedition_map()
			if expedition_hud_ui != null:
				expedition_hud_ui.visible = true
				expedition_hud_ui.update_bag_display()

			
		GameStateMachine.State.EVENING_PREP:
			_set_base_world_visible(true)
			if build_panel_ui != null:
				build_panel_ui.visible = true
			if _current_expedition_scene != null:
				_clear_expedition_scene()
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
		if player != null:
			player.visible = p_visible
			player.process_mode = Node.PROCESS_MODE_INHERIT if p_visible else Node.PROCESS_MODE_DISABLED
			player.collision_layer = 2 if p_visible else 0
			player.collision_mask = 13 if p_visible else 0
			var player_hitbox := player.get_node_or_null("HitboxComponent") as Area2D
			if player_hitbox != null:
				player_hitbox.collision_layer = 2 if p_visible else 0
		for actor in actors_container.get_children():
			if actor is Node2D and actor != player:
				actor.visible = p_visible
				actor.process_mode = Node.PROCESS_MODE_INHERIT if p_visible else Node.PROCESS_MODE_DISABLED
				if actor is CollisionObject2D:
					(actor as CollisionObject2D).collision_layer = 8 if p_visible else 0
	if building_manager != null:
		building_manager.visible = p_visible
		building_manager.process_mode = Node.PROCESS_MODE_INHERIT if p_visible else Node.PROCESS_MODE_DISABLED

func _load_expedition_map() -> void:
	_clear_expedition_scene()
		
	var gm = get_node_or_null("/root/GameManager")
	var map_id: StringName = gm.selected_map_id if gm != null else &"forest"
	var path: String = "res://scenes/expedition/%s.tscn" % String(map_id)
	if ResourceLoader.exists(path):
		var scene = load(path)
		_current_expedition_scene = scene.instantiate() as Node2D
		world_container.add_child(_current_expedition_scene)
		
	var spawn_pos: Vector2 = Vector2(0, 160)
	var extract_zone: ExtractionZone = null
	if _current_expedition_scene != null:
		extract_zone = _current_expedition_scene.find_child("ExtractionZone", true, false) as ExtractionZone
		if extract_zone != null:
			# Offset 120px away from zone center (radius 64px) to prevent instant accidental extraction
			spawn_pos = extract_zone.position + Vector2(0, 120)
			
	if _current_expedition_scene != null:
		_expedition_player = load("res://entities/player/player.tscn").instantiate() as Player
		var expedition_actors := _current_expedition_scene.find_child("Actors", true, false) as Node2D
		if expedition_actors != null:
			expedition_actors.add_child(_expedition_player)
		else:
			_current_expedition_scene.add_child(_expedition_player)
		_expedition_player.position = spawn_pos
		var camera := CameraTraumaClass.new()
		camera.zoom = Vector2(1.5, 1.5)
		camera.position_smoothing_enabled = true
		_expedition_player.add_child(camera)
		camera.make_current()

	if expedition_hud_ui != null:
		expedition_hud_ui.setup_player(_expedition_player, extract_zone)

func _clear_expedition_scene() -> void:
	if _expedition_player != null and is_instance_valid(_expedition_player):
		_expedition_player.process_mode = Node.PROCESS_MODE_DISABLED
		_expedition_player = null
	if _current_expedition_scene != null and is_instance_valid(_current_expedition_scene):
		_current_expedition_scene.process_mode = Node.PROCESS_MODE_DISABLED
		_current_expedition_scene.visible = false
		_current_expedition_scene.queue_free()
	_current_expedition_scene = null
