class_name ZombieSpawner
extends Node2D

# res://scenes/defense/zombie_spawner.gd
# Directional zombie spawner per Section E.2 of game_system_architecture.md

@export var default_zombie_scene: PackedScene

@onready var north_markers: Node2D = $NorthMarkers
@onready var east_markers: Node2D = $EastMarkers
@onready var south_markers: Node2D = $SouthMarkers
@onready var west_markers: Node2D = $WestMarkers

func _ready() -> void:
	if default_zombie_scene == null:
		default_zombie_scene = load("res://entities/zombies/zombie.tscn")

func get_spawn_position(direction_enum: int) -> Vector2:
	# 0: NORTH, 1: EAST, 2: SOUTH, 3: WEST, 4: RANDOM
	var target_group: Node2D = null
	var dir: int = direction_enum
	if dir == 4: # RANDOM
		dir = randi() % 4
		
	match dir:
		0:
			target_group = north_markers
		1:
			target_group = east_markers
		2:
			target_group = south_markers
		3:
			target_group = west_markers
			
	if target_group != null and target_group.get_child_count() > 0:
		var idx = randi() % target_group.get_child_count()
		var marker = target_group.get_child(idx) as Marker2D
		if marker != null:
			var tangent := Vector2.RIGHT if dir == 0 or dir == 2 else Vector2.DOWN
			return marker.global_position + tangent * randf_range(-110.0, 110.0) + Vector2(0.0, randf_range(-18.0, 18.0))
			
	return global_position + Vector2(randf_range(-300, 300), randf_range(-200, 200))

func spawn_zombie(direction_enum: int = 4, target_parent: Node2D = null) -> Zombie:
	var scene: PackedScene = default_zombie_scene
	if scene == null:
		scene = load("res://entities/zombies/zombie.tscn")
		
	var zombie_inst = scene.instantiate() as Zombie
	zombie_inst.global_position = get_spawn_position(direction_enum)
	
	if target_parent != null:
		target_parent.add_child(zombie_inst)
	else:
		get_parent().add_child(zombie_inst)
		
	return zombie_inst
