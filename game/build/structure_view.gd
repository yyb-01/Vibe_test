class_name StructureView
extends Node2D

const WALL_TEXTURE: Texture2D = preload("res://assets/generated/wall_module.png")
const STRUCTURE_TEXTURES: Dictionary = {
	&"wall": WALL_TEXTURE,
	&"gate": preload("res://assets/generated/structure_gate.png"),
	&"turret": preload("res://assets/generated/structure_turret.png"),
	&"storage": preload("res://assets/generated/structure_storage.png"),
}

var structure_id: StringName
var definition_id: StringName = &"wall"
var footprint_cells: Array = []
var connection_masks: Dictionary = {}
var _sprites: Dictionary = {}

func configure(next_id: StringName, next_cells: Array, next_masks: Dictionary, next_definition_id: StringName = &"wall") -> void:
	structure_id = next_id
	definition_id = next_definition_id
	footprint_cells = next_cells.duplicate()
	connection_masks = next_masks.duplicate()
	visible = true
	_refresh_sprites()
	queue_redraw()

func update_masks(next_masks: Dictionary) -> void:
	connection_masks = next_masks.duplicate()
	_refresh_sprites()
	queue_redraw()

func clear() -> void:
	visible = false
	queue_redraw()

func _draw() -> void:
	var color := Color(0.12, 0.35, 0.37, 0.8)
	for cell in footprint_cells:
		var center := Vector2(cell) * 32.0
		var mask := int(connection_masks.get(cell, 0))
		if mask & 1:
			draw_line(center, center + Vector2(0, -16), color, 6.0)
		if mask & 2:
			draw_line(center, center + Vector2(16, 0), color, 6.0)
		if mask & 4:
			draw_line(center, center + Vector2(0, 16), color, 6.0)
		if mask & 8:
			draw_line(center, center + Vector2(-16, 0), color, 6.0)

func _refresh_sprites() -> void:
	for cell in footprint_cells:
		var sprite: Sprite2D = _sprites.get(cell)
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.texture = STRUCTURE_TEXTURES.get(definition_id, WALL_TEXTURE)
			sprite.position = Vector2(cell) * 32.0
			sprite.scale = Vector2.ONE * 30.0 / float(WALL_TEXTURE.get_width())
			sprite.z_index = 1
			add_child(sprite)
			_sprites[cell] = sprite
		var mask := int(connection_masks.get(cell, 0))
		var has_vertical := (mask & 1) != 0 or (mask & 4) != 0
		var has_horizontal := (mask & 2) != 0 or (mask & 8) != 0
		sprite.rotation = PI * 0.5 if has_vertical and not has_horizontal else 0.0
