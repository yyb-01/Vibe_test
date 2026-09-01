extends Node

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const VIEWPORT_SIZE := Vector2(1280, 720)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var menu := MENU_SCENE.instantiate() as MainMenu
	add_child(menu)
	await get_tree().process_frame
	for scale in [0.8, 1.0, 1.25]:
		ThemeDB.fallback_base_scale = scale
		await get_tree().process_frame
		await get_tree().process_frame
		if not _check_layout(menu, scale):
			get_tree().quit(1)
			return
	ThemeDB.fallback_base_scale = SaveManager.ui_scale
	print("Main menu layout passed at 1280x720 for UI scales 80%, 100%, and 125%.")
	get_tree().quit(0)

func _check_layout(menu: MainMenu, scale: float) -> bool:
	var play_columns := menu.get_node("TabContainer/PlayTab/PlayColumns") as Control
	var loadout := play_columns.get_node("LoadoutColumn") as Control
	var maps := play_columns.get_node("MapColumn") as Control
	var grid := loadout.get_node("CharacterGrid") as GridContainer
	if grid.columns != 4 or grid.get_child_count() != 8:
		push_error("Character grid must contain 8 cards in 4 columns")
		return false
	for control in [play_columns, loadout, maps, grid]:
		var rect: Rect2 = control.get_global_rect()
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > VIEWPORT_SIZE.x or rect.end.y > VIEWPORT_SIZE.y:
			push_error("Main menu control outside 720p at %.0f%%: %s %s" % [scale * 100.0, control.name, rect])
			return false
	if loadout.get_global_rect().intersects(maps.get_global_rect()):
		push_error("Loadout and map cards overlap at %.0f%%" % (scale * 100.0))
		return false
	return true
