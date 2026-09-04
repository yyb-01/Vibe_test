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
	_check(app.booted, "AppRoot boots before Operation")

	var menu := app.current_screen.get_node("MainMenu") as MainMenu
	menu.get_node("StartOperation").emit_signal("pressed")
	await get_tree().process_frame
	app.current_screen.get_node("CampaignScreen/Panel/Layout/SelectOperation").emit_signal("pressed")
	await get_tree().process_frame
	app.current_screen.get_node("BriefingScreen/Panel/Layout/StartOperation").emit_signal("pressed")
	await get_tree().process_frame
	var operation = app.current_operation
	_check(operation != null, "Briefing starts an Operation")
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.OPERATION, "flow enters Operation")
	_check(operation.controller.state.lifecycle_state == OperationStateClass.Lifecycle.INSERTION or operation.controller.state.lifecycle_state == OperationStateClass.Lifecycle.ACTIVE, "Operation starts in INSERTION/ACTIVE")
	_check(operation.controller.state.seed == 20260904, "Operation uses definition seed")

	await get_tree().physics_frame
	_check(operation.controller.state.lifecycle_state == OperationStateClass.Lifecycle.ACTIVE, "insertion advances to ACTIVE")
	Input.action_press("ui_right")
	await get_tree().physics_frame
	Input.action_release("ui_right")
	_check(operation.controller.player.position.x > -180.0, "player moves in ACTIVE")
	_check(operation.controller.state.logical_tick > 0, "logical clock advances")

	_check(operation.request_end(OperationStateClass.EndReason.ABANDONED), "active Operation accepts end request")
	await get_tree().physics_frame
	_check(app.current_operation == null, "Operation reaches CLOSED")
	await get_tree().process_frame
	_check(app.current_operation == null, "AppRoot releases Operation reference")
	_check(app.current_screen.get_node_or_null("Operation") == null, "closed Operation node is removed")
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.SETTLEMENT, "flow enters Settlement")
	app.current_screen.get_node("SettlementScreen/Panel/Layout/Continue").emit_signal("pressed")
	await get_tree().process_frame
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.CAMPAIGN, "flow returns to Campaign")
	_check(app.current_screen.get_node_or_null("CampaignScreen") != null, "Campaign is restored")
	app.free()

	print("SLICE B TESTS: %d passed, %d failed" % [checks - failures, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _check(condition: bool, name: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % name)
	else:
		failures += 1
		printerr("[FAIL] %s" % name)
