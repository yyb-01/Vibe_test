extends Node

const AppRootScene = preload("res://game/app/app_root.tscn")
const AppFlowStateClass = preload("res://game/app/app_flow_state.gd")
const OperationStateClass = preload("res://game/operation/operation_state.gd")
const ObjectiveStateClass = preload("res://game/objective/objective_state.gd")
const PressureEventClass = preload("res://game/threat/pressure_event.gd")
const SpawnTicketClass = preload("res://game/threat/spawn_ticket.gd")

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
	var operation = app.current_operation
	_check(operation != null, "objective/threat operation starts")
	if operation == null:
		_finish(app)
		return
	await get_tree().physics_frame
	_check(operation.controller.state.lifecycle_state == OperationStateClass.Lifecycle.ACTIVE, "objective/threat slice reaches ACTIVE")
	var controller = operation.controller
	var inventory = controller.inventory
	var objective = controller.objective
	var threat = controller.threat
	_check(not controller.state.extraction_eligible, "extraction is locked before objective completion")
	_check(controller.state.objective_state == objective.state, "OperationState owns ObjectiveState reference")
	_check(objective.state.active_objective_id == &"secure_wood", "secure objective is active")
	_check(objective.state.objectives[&"secure_wood"].get("state") == ObjectiveStateClass.Lifecycle.ACTIVE, "objective runtime state is ACTIVE")
	_check(not operation.request_end(OperationStateClass.EndReason.COMPLETED), "completion is gated before objective completion")

	var pickup_result = inventory.pickup(&"objective_pickup", &"pickup_wood_01", &"player")
	_check(pickup_result.accepted, "objective test acquires item")
	_check(int(objective.state.objectives[&"secure_wood"].get("progress", 0)) == 0, "acquisition does not complete secure objective")
	_check(threat.state.pressure == 1, "acquisition adds one pressure")

	var secure_result = inventory.secure(&"objective_secure", &"player", &"wood")
	_check(secure_result.accepted, "objective test secures item")
	var runtime: Dictionary = objective.state.objectives[&"secure_wood"]
	_check(runtime.get("state") == ObjectiveStateClass.Lifecycle.COMPLETED, "secure objective completes")
	_check(int(runtime.get("progress", 0)) == 1, "objective caps progress at target amount")
	_check(controller.state.extraction_eligible, "objective completion opens extraction eligibility")
	_check(threat.state == controller.state.threat_state, "OperationState owns ThreatState reference")
	_check(threat.state.pressure == 2 and threat.state.events.size() == 1, "secured action crosses threat threshold")
	var event_id: StringName = threat.state.active_event_id
	var event = threat.state.events[event_id]
	_check(event.lifecycle == PressureEventClass.Lifecycle.TELEGRAPHED, "pressure event is telegraphed before activation")
	_check(operation.get_node("World/Telegraph").visible, "telegraph view is visible")
	threat.advance_tick(controller.state.logical_tick + 1)
	var ticket_id: StringName = event.spawn_ticket_ids[0] if not event.spawn_ticket_ids.is_empty() else &""
	var ticket = threat.state.spawn_tickets.get(ticket_id)
	_check(ticket != null and ticket.lifecycle == SpawnTicketClass.Lifecycle.ACTIVE and not ticket.enemy_ids.is_empty(), "active PressureEvent issues a SpawnTicket and dynamic enemy")
	for enemy_id in (ticket.enemy_ids if ticket != null else []):
		var defeated = controller.combat.damage_enemy(StringName("wave_defeat_%s" % String(enemy_id)), &"player", enemy_id, 999, controller.state.logical_tick)
		_check(defeated.accepted, "dynamic wave enemy accepts defeat")
	_check(ticket != null and ticket.lifecycle == SpawnTicketClass.Lifecycle.RESOLVED, "SpawnTicket resolves after its enemies end")
	threat.advance_tick(20)
	_check(event.lifecycle == PressureEventClass.Lifecycle.RESOLVED, "pressure event resolves after duration")
	_check(not operation.get_node("World/Telegraph").visible, "telegraph clears after resolution")
	_check(operation.request_end(OperationStateClass.EndReason.COMPLETED), "eligible operation accepts completion")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(app.current_operation == null, "objective/threat operation closes cleanly")
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.SETTLEMENT, "objective/threat slice enters Settlement")
	app.current_screen.get_node("SettlementScreen/Panel/Layout/Continue").emit_signal("pressed")
	await get_tree().process_frame
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.CAMPAIGN, "flow returns after objective/threat slice")
	_finish(app)

func _finish(app: AppRoot) -> void:
	app.free()
	print("SLICE F TESTS: %d passed, %d failed" % [checks - failures, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _check(condition: bool, name: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % name)
	else:
		failures += 1
		printerr("[FAIL] %s" % name)
