class_name OperationWorld
extends Node2D

const TERRAIN_TEXTURES: Dictionary = {
	&"grass": preload("res://assets/generated/terrain_grass.png"),
	&"dirt": preload("res://assets/generated/terrain_dirt.png"),
	&"rock": preload("res://assets/generated/terrain_stone.png"),
	&"path": preload("res://assets/generated/terrain_path.png"),
}

var map_size: Vector2 = Vector2(640, 360)
var terrain_id: StringName = &"grass"

func supports_terrain(next_terrain_id: StringName) -> bool:
	return TERRAIN_TEXTURES.has(next_terrain_id)

func configure(next_map_size: Vector2, next_terrain_id: StringName = &"grass") -> void:
	map_size = next_map_size
	terrain_id = next_terrain_id if TERRAIN_TEXTURES.has(next_terrain_id) else &"grass"
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-map_size * 0.5, map_size)
	draw_rect(rect, Color("182329"))
	draw_texture_rect(TERRAIN_TEXTURES[terrain_id], rect, true, Color(0.78, 0.88, 0.84, 0.76))
	for x in range(int(rect.position.x), int(rect.end.x) + 1, 32):
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color("25343a"), 1.0)
	for y in range(int(rect.position.y), int(rect.end.y) + 1, 32):
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("25343a"), 1.0)
	draw_rect(rect, Color("6e8d88"), false, 2.0)
