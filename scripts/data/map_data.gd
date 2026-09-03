class_name MapData
extends Resource

# res://scripts/data/map_data.gd
# Data schema for expedition maps per Section C.3 of game_system_architecture.md

enum MapType { CITY, FOREST }

@export var id: StringName
@export var display_name: String
@export var map_type: MapType = MapType.FOREST
@export var scene: PackedScene
@export var resource_spawn_weights: Dictionary = {} # item_id: StringName -> weight: float
@export_range(1.0, 3600.0) var time_limit_seconds: float = 600.0
@export var extraction_cells: Array[Vector2i] = []

func pick_random_resource(rng: RandomNumberGenerator = null) -> StringName:
	var valid_items: Array[StringName] = []
	var valid_weights: Array[float] = []
	var total_weight: float = 0.0
	
	for item_id in resource_spawn_weights:
		var weight: float = float(resource_spawn_weights[item_id])
		if weight > 0.0:
			valid_items.append(StringName(item_id))
			valid_weights.append(weight)
			total_weight += weight
			
	if valid_items.is_empty() or total_weight <= 0.0:
		return &""
		
	var roll: float
	if rng != null:
		roll = rng.randf_range(0.0, total_weight)
	else:
		roll = randf_range(0.0, total_weight)
		
	var cumulative: float = 0.0
	for i in range(valid_items.size()):
		cumulative += valid_weights[i]
		if roll <= cumulative:
			return valid_items[i]
			
	return valid_items.back()
