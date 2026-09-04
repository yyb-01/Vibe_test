extends Node

const AppRootScene = preload("res://game/app/app_root.tscn")
const AppFlowStateClass = preload("res://game/app/app_flow_state.gd")
const OperationStateClass = preload("res://game/operation/operation_state.gd")

var failures: int = 0
var checks: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var app := AppRootScene.instantiate() as AppRoot
	get_tree().root.add_child(app)
	await get_tree().process_frame
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.MAIN_MENU, "flow starts at Main Menu")
	app.current_screen.get_node("MainMenu/StartOperation").emit_signal("pressed")
	await get_tree().process_frame
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.CAMPAIGN, "Main Menu opens Campaign")
	_check(app.current_screen.get_node_or_null("CampaignScreen") != null, "Campaign screen is mounted")
	app.current_screen.get_node("CampaignScreen/Panel/Layout/SelectOperation").emit_signal("pressed")
	await get_tree().process_frame
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.BRIEFING, "Campaign opens Briefing")
	var briefing = app.current_screen.get_node("BriefingScreen")
	_check(String(briefing.get_node("Panel/Layout/Loadout").text).contains("wood"), "Briefing displays selected loadout")
	_check(String(briefing.get_node("Panel/Layout/Blueprints").text).contains("wall"), "Briefing displays unlocked Blueprint")
	var terrain_select = briefing.get_node("Panel/Layout/TerrainSelect") as OptionButton
	var dirt_index := -1
	for index in range(terrain_select.get_item_count()):
		if StringName(terrain_select.get_item_metadata(index)) == &"dirt":
			dirt_index = index
	_check(terrain_select.get_item_count() == 4 and dirt_index >= 0, "Briefing exposes registered Terrain definitions")
	if dirt_index >= 0:
		terrain_select.select(dirt_index)
		terrain_select.emit_signal("item_selected", dirt_index)
	_check(briefing.terrain_id == &"dirt", "Briefing keeps the selected Terrain")
	var before_revision: int = app.campaign_state.revision
	var invalid = app.campaign_controller.start_operation(&"invalid_start", &"missing", [], [&"wall"], &"standard")
	_check(not invalid.accepted and invalid.reason_code == &"OPERATION_LOCKED", "locked operation is rejected by StartOperationAction")
	var invalid_terrain = app.campaign_controller.start_operation(&"invalid_terrain", &"outpost", [], [&"wall"], &"standard", &"missing")
	_check(not invalid_terrain.accepted and invalid_terrain.reason_code == &"UNKNOWN_TERRAIN", "unknown Terrain is rejected by StartOperationAction")
	_check(app.campaign_state.revision == before_revision, "rejected start does not mutate CampaignState")
	briefing.get_node("Panel/Layout/StartOperation").emit_signal("pressed")
	await get_tree().process_frame
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.OPERATION, "accepted briefing action opens Operation")
	_check(app.current_operation != null, "selected operation is created")
	_check(app.current_operation.controller.terrain_id == &"dirt", "selected Terrain reaches Operation")
	_check(String(app.current_operation.get_node("Presentation/HUD/StatusPanel/Layout/TerrainStatus").text).contains("Dirt"), "Operation HUD displays selected Terrain")
	_check(app.current_operation.request_end(OperationStateClass.EndReason.ABANDONED), "operation accepts explicit end")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.SETTLEMENT, "Operation opens Settlement")
	app.current_screen.get_node("SettlementScreen/Panel/Layout/Continue").emit_signal("pressed")
	await get_tree().process_frame
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.CAMPAIGN, "Settlement returns to Campaign")
	_finish(app)

func _finish(app: AppRoot) -> void:
	app.free()
	print("SLICE J TESTS: %d passed, %d failed" % [checks - failures, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _check(condition: bool, name: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % name)
	else:
		failures += 1
		printerr("[FAIL] %s" % name)
