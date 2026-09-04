class_name AppRoot
extends Node

const AppFlowStateClass = preload("res://game/app/app_flow_state.gd")
const ContentValidatorClass = preload("res://game/content/content_validator.gd")
const CampaignStateClass = preload("res://game/campaign/campaign_state.gd")
const SettlementServiceClass = preload("res://game/settlement/settlement_service.gd")
const SaveServiceClass = preload("res://game/save/save_service.gd")
const MainMenuScene = preload("res://game/app/main_menu.tscn")
const CampaignScene = preload("res://game/app/campaign_screen.tscn")
const BriefingScene = preload("res://game/app/briefing_screen.tscn")
const OperationScene = preload("res://game/operation/operation.tscn")
const SettlementScene = preload("res://game/app/settlement_screen.tscn")

@export var content_manifest: ContentManifest
@onready var content_catalog: ContentCatalog = $ContentCatalog
@onready var current_screen: Control = $CurrentScreen
@onready var campaign_controller = $CampaignController

var app_flow_state: AppFlowState
var current_operation
var campaign_state
var settlement_service
var save_service
var last_operation_outcome
var last_settlement_result: Dictionary = {}
var _operation_sequence: int = 0
var booted: bool = false
var boot_errors := PackedStringArray()

func _ready() -> void:
	app_flow_state = AppFlowStateClass.new()
	boot_errors = ContentValidatorClass.new().validate(content_manifest)
	if not boot_errors.is_empty():
		_show_boot_error()
		return
	if not content_catalog.build(content_manifest):
		boot_errors.append("CATALOG_BUILD_FAILED")
		_show_boot_error()
		return
	campaign_state = CampaignStateClass.new()
	if not campaign_controller.setup(campaign_state, content_catalog):
		boot_errors.append("CAMPAIGN_BOOT_FAILED")
		_show_boot_error()
		return
	settlement_service = SettlementServiceClass.new()
	if not settlement_service.setup(campaign_state, content_catalog.catalog_hash):
		boot_errors.append("SETTLEMENT_BOOT_FAILED")
		_show_boot_error()
		return
	save_service = SaveServiceClass.new()
	if not save_service.setup("user://vivv", content_catalog.catalog_hash):
		boot_errors.append("SAVE_BOOT_FAILED")
		_show_boot_error()
		return
	if not app_flow_state.transition_to(AppFlowStateClass.Screen.MAIN_MENU):
		boot_errors.append("FLOW_BOOT_FAILED")
		_show_boot_error()
		return
	_mount_main_menu()
	booted = true

func _mount_main_menu() -> void:
	var main_menu := MainMenuScene.instantiate() as MainMenu
	current_screen.add_child(main_menu)
	main_menu.configure(content_catalog)
	main_menu.campaign_requested.connect(_open_campaign)

func _open_campaign() -> void:
	if not app_flow_state.transition_to(AppFlowStateClass.Screen.CAMPAIGN):
		return
	var main_menu := current_screen.get_node_or_null("MainMenu")
	if main_menu != null:
		main_menu.queue_free()
	_mount_campaign()

func _mount_campaign() -> void:
	var campaign = CampaignScene.instantiate()
	current_screen.add_child(campaign)
	campaign.configure(campaign_state, content_catalog)
	campaign.briefing_requested.connect(_open_briefing)
	campaign.main_menu_requested.connect(_return_to_main_menu)

func _open_briefing(operation_id: StringName) -> void:
	if not app_flow_state.transition_to(AppFlowStateClass.Screen.BRIEFING):
		return
	var campaign = current_screen.get_node_or_null("CampaignScreen")
	if campaign != null:
		campaign.queue_free()
	var briefing = BriefingScene.instantiate()
	current_screen.add_child(briefing)
	briefing.configure(content_catalog, campaign_state, operation_id)
	briefing.start_requested.connect(_on_briefing_start_requested)
	briefing.campaign_requested.connect(_return_to_campaign)

func _on_briefing_start_requested(action_id: StringName, operation_id: StringName, loadout_item_ids: Array, blueprint_ids: Array, terrain_id: StringName, risk_id: StringName) -> void:
	var result = campaign_controller.start_operation(action_id, operation_id, loadout_item_ids, blueprint_ids, risk_id, terrain_id)
	if not result.accepted:
		var briefing = current_screen.get_node_or_null("BriefingScreen")
		if briefing != null:
			briefing.show_action_result(result)
		return
	_launch_operation(operation_id, blueprint_ids, terrain_id)

func _launch_operation(operation_id: StringName, blueprint_ids: Array = [], terrain_id: StringName = &"") -> void:
	if current_operation != null or not app_flow_state.transition_to(AppFlowStateClass.Screen.OPERATION):
		return
	last_operation_outcome = null
	last_settlement_result = {}
	current_operation = OperationScene.instantiate()
	current_screen.add_child(current_operation)
	current_operation.closed.connect(_on_operation_closed)
	current_operation.outcome_ready.connect(_on_operation_outcome_ready)
	_operation_sequence += 1
	var runtime_operation_id := StringName("%s_%d" % [String(operation_id), _operation_sequence])
	if not current_operation.start(content_catalog, operation_id, runtime_operation_id, blueprint_ids, terrain_id):
		current_operation.queue_free()
		current_operation = null
		app_flow_state.transition_to(AppFlowStateClass.Screen.MAIN_MENU)
		_mount_main_menu()
		return
	var briefing = current_screen.get_node_or_null("BriefingScreen")
	if briefing != null:
		briefing.queue_free()

func _on_operation_closed(_reason: int) -> void:
	if current_operation == null:
		return
	current_operation.queue_free()
	current_operation = null
	if app_flow_state.transition_to(AppFlowStateClass.Screen.SETTLEMENT):
		_mount_settlement()

func _on_operation_outcome_ready(outcome_value) -> void:
	last_operation_outcome = outcome_value
	last_settlement_result = settlement_service.settle(outcome_value)
	if last_settlement_result.get("accepted", false):
		last_settlement_result["save"] = save_service.save_campaign(campaign_state)

func _mount_settlement() -> void:
	var settlement = SettlementScene.instantiate()
	current_screen.add_child(settlement)
	settlement.configure(last_operation_outcome, last_settlement_result, campaign_state)
	settlement.continue_requested.connect(_return_to_campaign)

func _return_to_main_menu() -> void:
	var campaign = current_screen.get_node_or_null("CampaignScreen")
	if campaign != null:
		campaign.queue_free()
	if app_flow_state.transition_to(AppFlowStateClass.Screen.MAIN_MENU):
		_mount_main_menu()

func _return_to_campaign() -> void:
	var settlement = current_screen.get_node_or_null("SettlementScreen")
	var briefing = current_screen.get_node_or_null("BriefingScreen")
	if settlement != null:
		settlement.queue_free()
	if briefing != null:
		briefing.queue_free()
	if app_flow_state.transition_to(AppFlowStateClass.Screen.CAMPAIGN):
		_mount_campaign()

func _show_boot_error() -> void:
	push_error("Content validation failed: %s" % ", ".join(boot_errors))
	var label := Label.new()
	label.text = "Content validation failed\n" + "\n".join(boot_errors)
	label.position = Vector2(32, 32)
	current_screen.add_child(label)
