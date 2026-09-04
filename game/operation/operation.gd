class_name Operation
extends Node2D

signal closed(reason: int)
signal outcome_ready(outcome)

@onready var controller = $OperationController

func _ready() -> void:
	controller.closed.connect(_on_controller_closed)
	controller.outcome_ready.connect(_on_controller_outcome_ready)

func start(catalog: ContentCatalog, operation_id: StringName, runtime_operation_id: StringName = &"", blueprint_ids: Array = [], terrain_id: StringName = &"") -> bool:
	return controller.start(catalog, operation_id, runtime_operation_id, blueprint_ids, terrain_id)

func request_end(reason: int) -> bool:
	return controller.end_operation(reason)

func request_extraction(action_id: StringName):
	return controller.request_extraction(action_id)

func _on_controller_closed(reason: int) -> void:
	closed.emit(reason)

func _on_controller_outcome_ready(outcome_value) -> void:
	outcome_ready.emit(outcome_value)
