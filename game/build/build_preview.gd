class_name BuildPreview
extends Node2D

var footprint_cells: Array = []
var rejected_cells: Array = []
var valid: bool = false
var reason: StringName = &""
var grid_revision: int = -1

func show_plan(plan: Dictionary) -> void:
	footprint_cells = plan.get("footprint_cells", []).duplicate()
	rejected_cells = plan.get("rejected_cells", []).duplicate()
	valid = bool(plan.get("accepted", false))
	reason = plan.get("reason", &"")
	grid_revision = int(plan.get("grid_revision", -1))
	visible = not footprint_cells.is_empty()
	queue_redraw()

func clear() -> void:
	footprint_cells.clear()
	rejected_cells.clear()
	visible = false
	valid = false
	reason = &""
	grid_revision = -1
	queue_redraw()

func _draw() -> void:
	for cell in footprint_cells:
		var color := Color("71b49f") if valid and not rejected_cells.has(cell) else Color("b45f5f")
		var center := Vector2(cell) * 32.0
		draw_rect(Rect2(center - Vector2(15, 15), Vector2(30, 30)), color, false, 3.0)
