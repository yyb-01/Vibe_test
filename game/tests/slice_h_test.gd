extends Node

const AppRootScene = preload("res://game/app/app_root.tscn")
const AppFlowStateClass = preload("res://game/app/app_flow_state.gd")
const OperationScene = preload("res://game/operation/operation.tscn")
const OperationStateClass = preload("res://game/operation/operation_state.gd")
const PressureEventClass = preload("res://game/threat/pressure_event.gd")
const SpawnTicketClass = preload("res://game/threat/spawn_ticket.gd")
const RewardChoiceClass = preload("res://game/settlement/reward_choice.gd")

var failures: int = 0
var checks: int = 0
var restore_fact_count: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var app := AppRootScene.instantiate() as AppRoot
	get_tree().root.add_child(app)
	await get_tree().process_frame
	_check(app.save_service.configure_directory("user://vivv_slice_h_test"), "save store accepts fixed user directory")

	app.campaign_state.item_balances[&"wood"] = 7
	app.campaign_state.permanent_resources[&"operations_completed"] = 2
	app.campaign_state.reward_choices[&"choice_save"] = RewardChoiceClass.new(&"choice_save", [&"wall", &"wood"], &"entry_save")
	app.campaign_state.revision = 7
	var campaign_save = app.save_service.save_campaign(app.campaign_state)
	_check(campaign_save.get("accepted", false), "Campaign Save writes atomically")
	app.campaign_state.item_balances.clear()
	app.campaign_state.permanent_resources.clear()
	app.campaign_state.reward_choices.clear()
	app.campaign_state.revision = 0
	var campaign_load = app.save_service.load_campaign(app.campaign_state)
	_check(campaign_load.get("accepted", false), "Campaign Save loads and verifies envelope")
	_check(app.campaign_state.item_balances.get(&"wood", 0) == 7 and app.campaign_state.revision == 7, "Campaign state round-trips")
	_check(app.campaign_state.reward_choices.has(&"choice_save"), "unresolved RewardChoice round-trips")

	var menu := app.current_screen.get_node("MainMenu") as MainMenu
	menu.get_node("StartOperation").emit_signal("pressed")
	await get_tree().process_frame
	app.current_screen.get_node("CampaignScreen/Panel/Layout/SelectOperation").emit_signal("pressed")
	await get_tree().process_frame
	var briefing = app.current_screen.get_node("BriefingScreen")
	var terrain_select = briefing.get_node("Panel/Layout/TerrainSelect") as OptionButton
	terrain_select.select(1)
	terrain_select.emit_signal("item_selected", 1)
	app.current_screen.get_node("BriefingScreen/Panel/Layout/StartOperation").emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().physics_frame
	var operation = app.current_operation
	_check(operation != null and operation.controller.state.lifecycle_state == OperationStateClass.Lifecycle.ACTIVE, "operation is ACTIVE before snapshot")
	if operation == null:
		_finish(app)
		return
	var controller = operation.controller
	var inventory = controller.inventory
	var build = controller.build
	var objective = controller.objective
	var threat = controller.threat
	_check(inventory.pickup(&"save_pickup", &"pickup_wood_01", &"player").accepted, "snapshot operation acquires item")
	var wall = build.place(&"save_wall", &"player", &"wall", Vector2i(2, 0), 0, build.state.grid.revision)
	_check(wall.accepted, "snapshot operation commits structure")
	var reservation = inventory.reserve(&"save_reserve", &"player", &"player_pack", &"wood", 1, &"save_reservation", inventory.get_container_revision(&"player_pack"))
	_check(reservation.accepted, "snapshot keeps an Inventory Reservation")
	_check(not String(threat.state.active_event_id).is_empty(), "snapshot keeps an active Threat event")
	threat.advance_tick(controller.state.logical_tick + 1)
	var event_with_ticket = threat.state.events[threat.state.active_event_id]
	var saved_ticket_id: StringName = event_with_ticket.spawn_ticket_ids[0] if not event_with_ticket.spawn_ticket_ids.is_empty() else &""
	var saved_ticket = threat.state.spawn_tickets.get(saved_ticket_id)
	_check(saved_ticket != null and saved_ticket.lifecycle == SpawnTicketClass.Lifecycle.ACTIVE and not saved_ticket.enemy_ids.is_empty(), "snapshot keeps an active SpawnTicket")
	var saved_tick: int = controller.state.logical_tick
	var saved_grid_revision: int = build.state.grid.revision
	var saved_navigation_revision: int = build.state.grid.navigation_revision
	var saved_occupant: StringName = build.state.grid.get_occupant(Vector2i(2, 0))
	var saved_pressure: int = threat.state.pressure
	var saved_event_id: StringName = threat.state.active_event_id
	var saved_objective_id: StringName = objective.state.active_objective_id
	var saved_terrain_id: StringName = controller.terrain_id

	var operation_save = app.save_service.save_operation(controller)
	_check(operation_save.get("accepted", false), "Operation Snapshot writes atomically")
	var second_operation_save = app.save_service.save_operation(controller)
	_check(second_operation_save.get("accepted", false), "Operation Snapshot can be retried")
	_check(FileAccess.file_exists(ProjectSettings.globalize_path("user://vivv_slice_h_test/operation.save.bak")), "atomic save retains previous backup")

	var restored_operation := OperationScene.instantiate() as Operation
	get_tree().root.add_child(restored_operation)
	_check(restored_operation.start(app.content_catalog, &"outpost", &"restore_target"), "fresh operation is created for restore")
	await get_tree().physics_frame
	await get_tree().physics_frame
	restored_operation.controller.inventory.facts_emitted.connect(_on_restore_facts)
	restored_operation.controller.build.facts_emitted.connect(_on_restore_facts)
	restored_operation.controller.combat.facts_emitted.connect(_on_restore_facts)
	var operation_load = app.save_service.load_operation(restored_operation.controller)
	_check(operation_load.get("accepted", false), "Operation Snapshot loads with checksum and content validation")
	var restored_controller = restored_operation.controller
	_check(restored_controller.state.lifecycle_state == OperationStateClass.Lifecycle.ACTIVE and restored_controller.state.logical_tick == saved_tick, "Operation lifecycle and tick round-trip")
	_check(restored_controller.inventory.has_reservation(&"player_pack", &"save_reservation"), "Inventory Reservation round-trips")
	_check(restored_controller.build.state.grid.get_occupant(Vector2i(2, 0)) == saved_occupant, "BuildGrid occupancy round-trips")
	_check(restored_controller.build.state.grid.revision == saved_grid_revision and restored_controller.build.state.grid.navigation_revision == saved_navigation_revision, "BuildGrid revisions round-trip")
	_check(restored_controller.objective.state.active_objective_id == saved_objective_id and restored_controller.objective.state.objectives[saved_objective_id].get("state") == 2, "Objective state round-trips")
	_check(restored_controller.threat.state.pressure == saved_pressure and restored_controller.threat.state.active_event_id == saved_event_id, "Threat state and active event round-trip")
	_check(restored_controller.threat.state.events[saved_event_id].lifecycle == PressureEventClass.Lifecycle.ACTIVE, "PressureEvent lifecycle round-trips")
	var restored_ticket = restored_controller.threat.state.spawn_tickets.get(saved_ticket_id)
	_check(restored_ticket != null and restored_ticket.lifecycle == SpawnTicketClass.Lifecycle.ACTIVE and restored_ticket.enemy_ids == saved_ticket.enemy_ids, "SpawnTicket and dynamic enemies round-trip")
	_check(restored_controller.terrain_id == saved_terrain_id and restored_controller.get_node("../World").terrain_id == saved_terrain_id, "Terrain selection round-trips")
	_check(not restored_controller.combat.state.enemies[&"enemy_01"].path.is_empty(), "derived enemy path is rebuilt")
	_check(restore_fact_count == 0, "restore emits no gameplay Facts")
	_check(restored_controller.get_node("../World/Telegraph").visible, "derived Threat Telegraph is rebuilt")
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.OPERATION, "app remains in Operation during snapshot restore")
	var corrupt_primary := FileAccess.open("user://vivv_slice_h_test/operation.save", FileAccess.WRITE)
	corrupt_primary.store_var({"format_version": 1, "payload": {}, "checksum": "bad"}, true)
	corrupt_primary.close()
	var backup_load: Dictionary = app.save_service.load_operation(restored_controller)
	_check(backup_load.get("accepted", false) and backup_load.get("used_backup", false), "corrupt primary falls back to backup")
	restored_operation.free()
	_finish(app)

func _on_restore_facts(_facts: Array) -> void:
	restore_fact_count += 1

func _finish(app: AppRoot) -> void:
	app.free()
	print("SLICE H TESTS: %d passed, %d failed" % [checks - failures, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _check(condition: bool, name: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % name)
	else:
		failures += 1
		printerr("[FAIL] %s" % name)
