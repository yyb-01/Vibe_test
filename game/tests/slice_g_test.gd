extends Node

const AppRootScene = preload("res://game/app/app_root.tscn")
const AppFlowStateClass = preload("res://game/app/app_flow_state.gd")
const OperationStateClass = preload("res://game/operation/operation_state.gd")
const RewardChoiceClass = preload("res://game/settlement/reward_choice.gd")
const RewardLedgerClass = preload("res://game/settlement/reward_ledger.gd")

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
	var success_operation = app.current_operation
	_check(success_operation != null and success_operation.controller.state.lifecycle_state == OperationStateClass.Lifecycle.ACTIVE, "settlement success operation reaches ACTIVE")
	if success_operation == null:
		_finish(app)
		return
	var success_inventory = success_operation.controller.inventory
	_check(success_inventory.pickup(&"settle_pickup", &"pickup_wood_01", &"player").accepted, "success operation acquires item")
	_check(success_inventory.secure(&"settle_secure", &"player", &"wood").accepted, "success operation secures item")
	var extraction = success_operation.request_extraction(&"extract_success")
	_check(extraction.accepted, "eligible operation accepts RequestExtractionAction")
	_check(success_operation.controller.state.lifecycle_state == OperationStateClass.Lifecycle.EXTRACTION, "extraction request enters EXTRACTION")
	_check(success_operation.controller.threat.state.extraction_pressure > 0, "extraction starts final threat pressure")
	var duplicate_extraction = success_operation.request_extraction(&"extract_success")
	_check(duplicate_extraction.accepted and duplicate_extraction == extraction, "same extraction action is idempotent")
	await _wait_for_close()

	var success_outcome = app.last_operation_outcome
	var success_settlement: Dictionary = app.last_settlement_result
	_check(success_outcome != null and success_outcome.sealed, "success outcome is sealed")
	_check(success_outcome.end_reason == OperationStateClass.EndReason.COMPLETED, "success outcome records COMPLETED")
	_check(success_outcome.secured_items.get(&"wood", 0) == 5 and success_outcome.carried_items.is_empty(), "outcome separates secured and carried items")
	_check(success_settlement.get("accepted", false) and not success_settlement.get("duplicate", true), "success settlement commits once")
	var success_proposal = success_settlement.get("proposal")
	_check(success_proposal.success and success_proposal.preserved_items.get(&"wood", 0) == 5, "success policy preserves secured item")
	_check(app.campaign_state.item_balances.get(&"wood", 0) == 5, "campaign receives secured reward")
	_check(app.campaign_state.permanent_resources.get(&"operations_completed", 0) == 1, "campaign records completed operation")
	var ledger_count: int = app.settlement_service.ledger.entries.size()
	var retry_success: Dictionary = app.settlement_service.settle(success_outcome)
	_check(retry_success.get("duplicate", false), "re-settling success outcome is detected as duplicate")
	_check(app.settlement_service.ledger.entries.size() == ledger_count and app.campaign_state.item_balances.get(&"wood", 0) == 5, "duplicate success does not pay twice")
	_check(app.settlement_service.ledger.entries_by_outcome.size() == 1, "RewardLedger keys outcome once")
	var applied_entry = app.settlement_service.ledger.entries.values()[0]
	_check(applied_entry.get("state") == RewardLedgerClass.EntryState.APPLIED, "reward ledger entry is APPLIED")
	app.current_screen.get_node("SettlementScreen/Panel/Layout/Continue").emit_signal("pressed")
	await get_tree().process_frame

	var choice := RewardChoiceClass.new(&"choice_test", [&"wall", &"wood"], &"entry_test")
	_check(choice.select(&"wall"), "RewardChoice accepts candidate")
	_check(not choice.select(&"wood"), "RewardChoice rejects second selection")

	var campaign = app.current_screen.get_node("CampaignScreen")
	campaign.get_node("Panel/Layout/SelectOperation").emit_signal("pressed")
	await get_tree().process_frame
	var briefing = app.current_screen.get_node("BriefingScreen")
	briefing.get_node("Panel/Layout/StartOperation").emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var failure_operation = app.current_operation
	_check(failure_operation != null and failure_operation.controller.state.lifecycle_state == OperationStateClass.Lifecycle.ACTIVE, "failure operation reaches ACTIVE")
	var failure_inventory = failure_operation.controller.inventory
	_check(failure_inventory.pickup(&"failure_pickup", &"pickup_wood_01", &"player").accepted, "failure operation acquires carried item")
	_check(failure_operation.request_end(OperationStateClass.EndReason.ABANDONED), "abandoned operation accepts failure end")
	await _wait_for_close()

	var failure_outcome = app.last_operation_outcome
	var failure_settlement: Dictionary = app.last_settlement_result
	_check(failure_outcome.end_reason == OperationStateClass.EndReason.ABANDONED, "failure outcome records ABANDONED")
	_check(failure_outcome.carried_items.get(&"wood", 0) == 5 and failure_outcome.secured_items.is_empty(), "failure outcome retains carried snapshot")
	var failure_proposal = failure_settlement.get("proposal")
	_check(not failure_proposal.success and failure_proposal.lost_items.get(&"wood", 0) == 5, "failure policy loses carried item")
	_check(app.campaign_state.item_balances.get(&"wood", 0) == 5, "failed carried item is not committed")
	_check(app.campaign_state.permanent_resources.get(&"operations_failed", 0) == 1, "campaign records failed operation")
	var retry_failure: Dictionary = app.settlement_service.settle(failure_outcome)
	_check(retry_failure.get("duplicate", false), "re-settling failure outcome is detected as duplicate")
	_check(app.campaign_state.permanent_resources.get(&"operations_failed", 0) == 1, "duplicate failure does not commit twice")
	app.current_screen.get_node("SettlementScreen/Panel/Layout/Continue").emit_signal("pressed")
	await get_tree().process_frame
	_check(app.current_operation == null and app.app_flow_state.current_screen == AppFlowStateClass.Screen.CAMPAIGN, "settlement returns to Campaign")
	_finish(app)

func _wait_for_close() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

func _finish(app: AppRoot) -> void:
	app.free()
	print("SLICE G TESTS: %d passed, %d failed" % [checks - failures, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _check(condition: bool, name: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % name)
	else:
		failures += 1
		printerr("[FAIL] %s" % name)
