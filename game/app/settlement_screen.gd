class_name SettlementScreen
extends Control

const OperationStateClass = preload("res://game/operation/operation_state.gd")

signal continue_requested

@onready var result_label: Label = $Panel/Layout/Result
@onready var details: Label = $Panel/Layout/Details
@onready var campaign: Label = $Panel/Layout/Campaign

func _ready() -> void:
	$Panel/Layout/Continue.pressed.connect(_on_continue_pressed)

func configure(outcome, settlement_result: Dictionary, campaign_state) -> void:
	if outcome == null:
		result_label.text = "정산 결과를 읽을 수 없습니다"
		details.text = "작전 결과가 없습니다."
		return
	var proposal = settlement_result.get("proposal")
	var success: bool = outcome.end_reason == OperationStateClass.EndReason.COMPLETED
	result_label.text = "작전 성공" if success else "작전 종료 — %s" % _end_reason(outcome.end_reason)
	if proposal == null:
		details.text = "정산 실패: %s" % String(settlement_result.get("reason", "UNKNOWN"))
	else:
		details.text = "보존: %s\n소실: %s\n획득 목표: %s" % [_items_text(proposal.preserved_items), _items_text(proposal.lost_items), ", ".join(_strings(outcome.completed_objectives)) if not outcome.completed_objectives.is_empty() else "없음"]
	campaign.text = "캠페인: wood x%d\n완료 %d / 실패 %d" % [int(campaign_state.item_balances.get(&"wood", 0)), campaign_state.completed_operation_ids.size(), campaign_state.failed_operation_ids.size()]

func _on_continue_pressed() -> void:
	continue_requested.emit()

func _end_reason(reason: int) -> String:
	match reason:
		OperationStateClass.EndReason.ABANDONED: return "포기"
		OperationStateClass.EndReason.PLAYER_DISABLED: return "플레이어 무력화"
		OperationStateClass.EndReason.CORE_DESTROYED: return "Core 파괴"
		_: return "미완료"

func _items_text(items: Dictionary) -> String:
	if items.is_empty():
		return "없음"
	return ", ".join(_strings(items.keys(), items))

func _strings(values: Array, amounts: Dictionary = {}) -> Array:
	var result: Array = []
	for value in values:
		result.append("%s x%d" % [String(value), int(amounts[value])] if amounts.has(value) else String(value))
	return result
