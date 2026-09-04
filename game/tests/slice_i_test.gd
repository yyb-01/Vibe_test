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
	var menu := app.current_screen.get_node("MainMenu") as MainMenu
	menu.get_node("StartOperation").emit_signal("pressed")
	await get_tree().process_frame
	app.current_screen.get_node("CampaignScreen/Panel/Layout/SelectOperation").emit_signal("pressed")
	await get_tree().process_frame
	app.current_screen.get_node("BriefingScreen/Panel/Layout/StartOperation").emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().physics_frame
	var operation = app.current_operation
	_check(operation != null, "Presentation operation starts")
	if operation == null:
		_finish(app)
		return
	var hud = operation.get_node("Presentation/HUD")
	var presenter = operation.get_node("Presentation/OperationPresenter")
	var model: Dictionary = presenter.read_model()
	_check(model.has("objective") and model.has("threat") and model.has("extraction"), "Presenter exposes operation read models")
	_check(String(hud.get_node("StatusPanel/Layout/ObjectiveStatus").text).contains("secure_wood"), "HUD displays ObjectiveReadModel")
	_check(String(hud.get_node("StatusPanel/Layout/ThreatStatus").text).contains("위협"), "HUD displays ThreatReadModel")

	var contrast = hud.get_node("StatusPanel/Layout/HighContrast") as CheckButton
	contrast.emit_signal("toggled", true)
	_check(contrast.text == "고대비: 켜짐", "accessibility toggle updates presentation only")

	var controller = operation.controller
	_check(controller.inventory.pickup(&"ui_pickup", &"pickup_wood_01", &"player").accepted, "HUD test acquires build material")
	var build_wall = hud.get_node("StatusPanel/Layout/BuildWall") as Button
	var confirm_build = hud.get_node("StatusPanel/Layout/ConfirmBuild") as Button
	build_wall.emit_signal("pressed")
	await get_tree().process_frame
	_check(controller.build.preview.visible and not confirm_build.disabled, "Build Palette opens a valid Preview")
	_check(String(hud.get_node("StatusPanel/Layout/ActionStatus").text).contains("승인"), "Preview reports its reason")
	confirm_build.emit_signal("pressed")
	await get_tree().process_frame
	_check(controller.build.state.structures.size() == 1, "Confirm Wall commits through BuildController")
	_check(String(hud.get_node("StatusPanel/Layout/ActionStatus").text).contains("승인"), "Confirm reports accepted ActionResult")

	_check(controller.inventory.secure(&"ui_secure", &"player", &"wood").accepted, "HUD test completes objective through controller action")
	await get_tree().process_frame
	var extract = hud.get_node("StatusPanel/Layout/Extract") as Button
	_check(not extract.disabled, "HUD unlocks extraction after objective completion")
	extract.emit_signal("pressed")
	_check(controller.state.lifecycle_state == OperationStateClass.Lifecycle.EXTRACTION, "Extract requests Controller Action")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(app.current_operation == null, "Operation closes after extraction")
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.SETTLEMENT, "AppFlow enters Settlement")
	var settlement = app.current_screen.get_node("SettlementScreen")
	_check(String(settlement.get_node("Panel/Layout/Result").text).contains("성공"), "Settlement displays sealed outcome")
	_check(String(settlement.get_node("Panel/Layout/Details").text).contains("보존"), "Settlement displays RewardProposal")
	settlement.get_node("Panel/Layout/Continue").emit_signal("pressed")
	await get_tree().process_frame
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.CAMPAIGN, "Settlement continues to Campaign")
	_check(app.current_screen.get_node_or_null("CampaignScreen") != null, "Campaign remounts after Settlement")
	_finish(app)

func _finish(app: AppRoot) -> void:
	app.free()
	print("SLICE I TESTS: %d passed, %d failed" % [checks - failures, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _check(condition: bool, name: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % name)
	else:
		failures += 1
		printerr("[FAIL] %s" % name)
