extends Node

const AppRootScene = preload("res://game/app/app_root.tscn")
const AppFlowStateClass = preload("res://game/app/app_flow_state.gd")
const OperationStateClass = preload("res://game/operation/operation_state.gd")
const InventoryControllerClass = preload("res://game/inventory/inventory_controller.gd")

var failures: int = 0
var checks: int = 0
var emitted_fact_types := PackedStringArray()

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
	_check(operation != null, "Operation starts for inventory slice")
	if operation == null:
		_finish(app)
		return
	await get_tree().physics_frame
	_check(operation.controller.state.lifecycle_state == OperationStateClass.Lifecycle.ACTIVE, "inventory slice reaches ACTIVE")
	var inventory = operation.controller.inventory
	inventory.facts_emitted.connect(_on_facts_emitted)
	var before: int = inventory.total_item_count(&"wood")
	_check(before == 5, "world pickup enters conservation total")
	Input.action_press("ui_accept")
	await get_tree().physics_frame
	Input.action_release("ui_accept")
	_check(inventory.get_item_count(&"player_pack", &"wood") == 5, "Enter picks up into Carried")
	_check(inventory.get_item_count(&"core_storage", &"wood") == 0, "pickup does not secure early")
	_check(inventory.total_item_count(&"wood") == before, "pickup conserves total amount")
	_check(emitted_fact_types.has("ITEM_ACQUIRED"), "pickup emits ITEM_ACQUIRED")
	_check(not operation.controller.pickup_view.visible, "pickup view clears after state commit")
	var stale_result = inventory.transfer(&"stale_transfer", &"player", &"player_pack", &"core_storage", &"wood", 1, 0, 0)
	_check(not stale_result.accepted and stale_result.reason_code == &"STALE_PREVIEW", "stale revisions reject transfer")
	var failed_inventory = InventoryControllerClass.new()
	failed_inventory.setup(&"capacity_check", app.content_catalog, &"player", 4, 10, &"small_pack_pickup", &"wood", 5, Vector2.ZERO)
	var failed_pickup = failed_inventory.pickup(&"full_pickup", &"small_pack_pickup", &"player")
	_check(not failed_pickup.accepted and failed_pickup.reason_code == &"INVENTORY_FULL", "pickup rejects a full target")
	_check(not failed_inventory.state.pickups[&"small_pack_pickup"].claimed, "failed pickup releases claim")
	failed_inventory.free()

	var reserve_result = inventory.reserve(&"reserve_wood", &"player", &"player_pack", &"wood", 3, &"build_1")
	_check(reserve_result.accepted, "reservation is accepted")
	var blocked_result = inventory.secure(&"blocked_secure", &"player", &"wood")
	_check(not blocked_result.accepted and blocked_result.reason_code == &"NOT_ENOUGH_RESOURCE", "reservation protects reserved amount")
	_check(inventory.get_item_count(&"core_storage", &"wood") == 0, "blocked secure does not mutate target")
	_check(inventory.release_reservation(&"release_wood", &"player", &"player_pack", &"build_1").accepted, "reservation releases")

	var transfer_result = inventory.transfer(&"transfer_wood", &"player", &"player_pack", &"core_storage", &"wood", 1)
	_check(transfer_result.accepted, "direct transfer is accepted")
	var duplicate_result = inventory.transfer(&"transfer_wood", &"player", &"player_pack", &"core_storage", &"wood", 1)
	_check(duplicate_result.accepted and inventory.get_item_count(&"core_storage", &"wood") == 1, "duplicate action is idempotent")
	operation.controller.player.position = operation.controller.core.position
	Input.action_press("ui_accept")
	await get_tree().physics_frame
	Input.action_release("ui_accept")
	_check(inventory.get_item_count(&"player_pack", &"wood") == 0, "Enter secures remaining Carried items")
	_check(inventory.get_item_count(&"core_storage", &"wood") == 5, "Secured receives the full amount")
	_check(inventory.total_item_count(&"wood") == before, "secure conserves total amount")
	_check(emitted_fact_types.has("ITEM_SECURED"), "secure emits ITEM_SECURED")

	_check(operation.request_end(OperationStateClass.EndReason.ABANDONED), "inventory operation accepts end")
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(app.current_operation == null, "inventory operation closes cleanly")
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.SETTLEMENT, "inventory slice enters Settlement")
	app.current_screen.get_node("SettlementScreen/Panel/Layout/Continue").emit_signal("pressed")
	await get_tree().process_frame
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.CAMPAIGN, "flow returns after inventory slice")
	_finish(app)

func _on_facts_emitted(facts: Array) -> void:
	for fact in facts:
		emitted_fact_types.append(String(fact.fact_type))

func _finish(app: AppRoot) -> void:
	app.free()
	print("SLICE C TESTS: %d passed, %d failed" % [checks - failures, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _check(condition: bool, name: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % name)
	else:
		failures += 1
		printerr("[FAIL] %s" % name)
