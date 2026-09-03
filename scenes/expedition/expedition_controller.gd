class_name ExpeditionController
extends Node2D

# res://scenes/expedition/expedition_controller.gd
# Manages expedition map lifecycle, timer countdown, and extraction per Section E.4

signal timer_updated(time_left: float)
signal expedition_ended(success: bool)

@export var default_map: MapData

@onready var map_container: Node2D = $MapContainer
@onready var hud: CanvasLayer = $HUD
@onready var timer_label: Label = $HUD/TimerLabel
@onready var bag_label: Label = $HUD/BagLabel

var current_map_data: MapData = null
var remaining_time: float = 300.0
var is_active: bool = false
var player_instance: Player = null

func _ready() -> void:
	EventBus.inventory_changed.connect(_on_inventory_changed)
	
	# Determine map data to load
	var map_to_load: MapData = default_map
	if GameManager.selected_map_id != &"":
		var path: String = "res://data/maps/%s.tres" % String(GameManager.selected_map_id)
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is MapData:
				map_to_load = res
				
	if map_to_load != null:
		start_expedition(map_to_load)

func start_expedition(map_data: MapData) -> void:
	current_map_data = map_data
	remaining_time = map_data.time_limit_seconds
	is_active = true
	
	# Clear previous map if any
	for child in map_container.get_children():
		child.queue_free()
		
	if map_data.scene != null:
		var map_inst: Node = map_data.scene.instantiate()
		map_container.add_child(map_inst)
		
		# Spawn player
		var player_scene: PackedScene = load("res://entities/player/player.tscn")
		player_instance = player_scene.instantiate()
		player_instance.position = Vector2(0, 64)
		
		var actors = map_inst.find_child("Actors", true, false)
		if actors != null:
			actors.add_child(player_instance)
		else:
			map_inst.add_child(player_instance)
			
		# Add camera to player
		var cam := Camera2D.new()
		cam.zoom = Vector2(1.5, 1.5)
		cam.position_smoothing_enabled = true
		player_instance.add_child(cam)
		cam.make_current()
		
	_update_hud()

func _process(delta: float) -> void:
	if not is_active:
		return
		
	remaining_time -= delta
	timer_updated.emit(remaining_time)
	_update_timer_display()
	
	if remaining_time <= 0.0:
		_fail_expedition()

func _update_timer_display() -> void:
	if timer_label != null:
		var minutes: int = int(remaining_time) / 60
		var seconds: int = int(remaining_time) % 60
		timer_label.text = "Time Left: %02d:%02d" % [minutes, seconds]

func _update_hud() -> void:
	_update_timer_display()
	if bag_label != null and InventoryManager != null:
		var slots: Array[Dictionary] = InventoryManager.expedition_bag.get_slots()
		var text: String = "Bag: %d/8 slots\n" % slots.size()
		for s in slots:
			text += "%s: %d\n" % [s.get("item_id", ""), s.get("amount", 0)]
		bag_label.text = text

func _on_inventory_changed(container: StringName) -> void:
	if container == &"bag":
		_update_hud()

func _fail_expedition() -> void:
	if not is_active:
		return
	is_active = false
	remaining_time = 0.0
	expedition_ended.emit(false)
	GameManager.complete_expedition(false)
