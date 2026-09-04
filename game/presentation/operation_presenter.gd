class_name OperationPresenter
extends Node

@onready var controller = get_node("../../OperationController")

func read_model() -> Dictionary:
	if controller == null or controller.state == null:
		return _empty_model()
	var state = controller.state
	var grid = controller.build.state.grid if controller.build.state != null else null
	var objective := _objective_model(state.objective_state)
	var threat := _threat_model(state.threat_state, state)
	var carried := _items(state.inventory_state.containers.get(&"player_pack"))
	var secured := _items(state.inventory_state.containers.get(&"core_storage"))
	var preview = controller.build.preview
	var preview_cells: Array = preview.footprint_cells.duplicate()
	var selected_id: StringName = controller.build.selected_definition_id
	var selected = controller.build.catalog.get_definition(selected_id) if controller.build.catalog != null else null
	var cost_item_id: StringName = selected.cost_item_id if selected != null else &"wood"
	var cost_amount: int = int(selected.cost_amount) if selected != null else 0
	return {
		"lifecycle": state.lifecycle_state,
		"logical_tick": state.logical_tick,
		"terrain_id": controller.terrain_id,
		"player": {"position": controller.player.position, "cell": grid.world_to_cell(controller.player.position) if grid != null else Vector2i.ZERO},
		"core": _core_model(state),
		"inventory": {"carried": carried, "secured": secured},
		"build": {
			"selected_definition_id": selected_id,
			"cost_item_id": cost_item_id,
			"cost_amount": cost_amount,
			"available_amount": controller.inventory.get_available_amount(&"player_pack", cost_item_id),
			"preview_cells": preview_cells,
			"preview_accepted": preview.valid,
			"preview_reason": preview.reason,
			"preview_revision": preview.grid_revision,
			"route_warning": _route_warning(grid, preview_cells, state),
		},
		"objective": objective,
		"threat": threat,
		"extraction": {"eligible": state.extraction_eligible, "lifecycle": state.lifecycle_state},
		"prompt": {"text": _prompt(state, carried)},
	}

func _empty_model() -> Dictionary:
	return {"lifecycle": -1, "terrain_id": &"", "player": {"cell": Vector2i.ZERO}, "core": {}, "inventory": {"carried": {}, "secured": {}}, "build": {"available_amount": 0, "cost_amount": 0, "preview_accepted": false, "preview_reason": &""}, "objective": {}, "threat": {}, "extraction": {"eligible": false}, "prompt": {"text": "작전 준비 중"}}

func _objective_model(objective_state) -> Dictionary:
	if objective_state == null:
		return {"id": &"", "state": -1, "progress": 0, "target": 0}
	var objective_id: StringName = objective_state.active_objective_id
	if String(objective_id).is_empty() and not objective_state.completed_objective_ids.is_empty():
		objective_id = objective_state.completed_objective_ids.back()
	var value: Dictionary = objective_state.objectives.get(objective_id, {})
	return {"id": objective_id, "state": int(value.get("state", -1)), "progress": int(value.get("progress", 0)), "target": int(value.get("target_amount", 0))}

func _threat_model(threat_state, operation_state) -> Dictionary:
	if threat_state == null:
		return {"pressure": 0, "tier": 0, "event_id": &"", "remaining": 0, "lifecycle": -1}
	var event_id: StringName = threat_state.active_event_id
	var event = threat_state.events.get(event_id) if not String(event_id).is_empty() else null
	var remaining := maxi(0, int(event.expiry_tick) - operation_state.logical_tick) if event != null else 0
	return {"pressure": threat_state.pressure, "tier": threat_state.pressure_tier, "event_id": event_id, "remaining": remaining, "lifecycle": int(event.lifecycle) if event != null else -1, "extraction_pressure": threat_state.extraction_pressure}

func _core_model(state) -> Dictionary:
	var health: Dictionary = state.combat_state.health_by_entity.get(&"core", {}) if state.combat_state != null else {}
	return {"health": int(health.get("current", 0)), "maximum": int(health.get("maximum", 0))}

func _items(container) -> Dictionary:
	var result: Dictionary = {}
	if container == null:
		return result
	for item_id in container.item_stacks.keys():
		result[StringName(item_id)] = int(container.item_stacks[item_id])
	return result

func _route_warning(grid, preview_cells: Array, state) -> bool:
	if grid == null or preview_cells.is_empty() or state.combat_state == null:
		return false
	var enemy = state.combat_state.enemies.get(&"enemy_01")
	if enemy == null:
		return false
	for cell in grid.get_id_path(enemy.cell, state.combat_state.protected_target_cell):
		if preview_cells.has(cell):
			return true
	return false

func _prompt(state, carried: Dictionary) -> String:
	var pickup_id: StringName = controller.inventory.find_pickup_near(controller.player.position, 76.0)
	if not String(pickup_id).is_empty():
		return "상호작용: 물자 획득 [Enter]"
	if controller.player.position.distance_to(controller.core.position) <= 72.0 and not carried.is_empty():
		return "상호작용: Core에 확보 [Enter]"
	if state.extraction_eligible:
		return "탈출 조건 충족 — Extract를 요청하세요"
	return "목표를 완료하고 물자를 확보하세요"
