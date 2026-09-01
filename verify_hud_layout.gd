extends Node

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const VIEWPORT_SIZE := Vector2(1280, 720)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var hud := HUD_SCENE.instantiate() as HUD
	add_child(hud)
	await get_tree().process_frame
	for scale in [0.8, 1.0, 1.25]:
		ThemeDB.fallback_base_scale = scale
		await get_tree().process_frame
		if not _check_layout(hud, scale):
			get_tree().quit(1)
			return
	ThemeDB.fallback_base_scale = SaveManager.ui_scale
	print("HUD layout passed at 1280x720 for UI scales 80%, 100%, and 125%.")
	get_tree().quit(0)

func _check_layout(hud: HUD, scale: float) -> bool:
	var controls: Array[Control] = [
		hud.get_node("InventorySlots"), hud.build_toggle_button,
		hud.get_node("ObjectivePanel"), hud.get_node("SkillPanel"),
		hud.gold_label, hud.scrap_label, hud.threat_label
	]
	for control in controls:
		var rect := control.get_global_rect()
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > VIEWPORT_SIZE.x or rect.end.y > VIEWPORT_SIZE.y:
			push_error("HUD control outside 720p viewport at %.0f%%: %s %s" % [scale * 100.0, control.name, rect])
			return false
	if controls[0].get_global_rect().intersects(controls[1].get_global_rect()):
		push_error("Inventory slots overlap the build button at %.0f%%: %s / %s" % [scale * 100.0, controls[0].get_global_rect(), controls[1].get_global_rect()])
		return false
	if controls[2].get_global_rect().intersects(controls[3].get_global_rect()):
		push_error("Objective and skill panels overlap at %.0f%%" % (scale * 100.0))
		return false
	return true
