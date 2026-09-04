class_name CampaignScreen
extends Control

signal briefing_requested(operation_id: StringName)
signal main_menu_requested

var operation_id: StringName = &""

func _ready() -> void:
	$Panel/Layout/SelectOperation.pressed.connect(_on_select_operation_pressed)
	$Panel/Layout/Back.pressed.connect(_on_back_pressed)

func configure(campaign_state, catalog) -> void:
	var available: Array = campaign_state.accessible_operation_ids
	operation_id = available[0] if not available.is_empty() else &""
	var operation = catalog.get_definition(operation_id) if not String(operation_id).is_empty() else null
	$Panel/Layout/Operation.text = "작전: %s" % String(operation.display_name if operation != null else "없음")
	$Panel/Layout/Status.text = "Wood x%d\n완료 %d / 실패 %d" % [int(campaign_state.item_balances.get(&"wood", 0)), campaign_state.completed_operation_ids.size(), campaign_state.failed_operation_ids.size()]
	$Panel/Layout/SelectOperation.disabled = operation == null

func _on_select_operation_pressed() -> void:
	if not String(operation_id).is_empty():
		briefing_requested.emit(operation_id)

func _on_back_pressed() -> void:
	main_menu_requested.emit()
