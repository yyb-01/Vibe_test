class_name BuildController
extends Node

const ActionResultClass = preload("res://game/shared/action_result.gd")
const WorldFactClass = preload("res://game/shared/world_fact.gd")
const BuildGridClass = preload("res://game/build/build_grid.gd")
const BuildStateClass = preload("res://game/build/build_state.gd")
const BuildSiteStateClass = preload("res://game/build/build_site_state.gd")
const StructureStateClass = preload("res://game/build/structure_state.gd")
const BuildRulesClass = preload("res://game/build/build_rules.gd")
const StructureViewClass = preload("res://game/build/structure_view.gd")
const StructureDefinitionClass = preload("res://game/content/definitions/structure_definition.gd")

signal facts_emitted(facts: Array)

var state
var operation_id: StringName
var inventory
var catalog: ContentCatalog
var enabled: bool = false
var _processed_actions: Dictionary = {}
var _sequence: int = 0
var _fact_sequence: int = 0
var _views: Dictionary = {}
var selected_definition_id: StringName = &"wall"

@onready var preview = get_node("../World/BuildPreview")
@onready var structure_root = get_node("../World/Structures")

func setup(next_operation_id: StringName, map_size: Vector2, next_inventory, next_catalog: ContentCatalog, core_position: Vector2) -> bool:
	if next_inventory == null or next_catalog == null or map_size.x <= 0.0 or map_size.y <= 0.0:
		return false
	operation_id = next_operation_id
	inventory = next_inventory
	catalog = next_catalog
	state = BuildStateClass.new()
	state.grid = BuildGridClass.new(map_size)
	var core_cell: Vector2i = state.grid.world_to_cell(core_position)
	state.grid.seed_structure(&"core", [core_cell], [&"SOLID"], &"core", [])
	state.revision = state.grid.revision
	_processed_actions.clear()
	_sequence = 0
	_fact_sequence = 0
	preview.clear()
	selected_definition_id = &"wall"
	enabled = false
	return true

func select_definition(next_definition_id: StringName) -> bool:
	if _get_structure_definition(next_definition_id) == null:
		return false
	selected_definition_id = next_definition_id
	preview.clear()
	return true

func set_enabled(next_enabled: bool) -> void:
	enabled = next_enabled
	if not enabled:
		preview.clear()

func preview_structure(actor_id: StringName, definition_id: StringName, anchor_cell: Vector2i, rotation: int, expected_grid_revision: int = -1) -> Dictionary:
	if not enabled:
		var revision: int = state.grid.revision if state != null else 0
		return {"accepted": false, "reason": &"WRONG_OPERATION_STATE", "footprint_cells": [], "rejected_cells": [], "grid_revision": revision}
	var definition = _get_structure_definition(definition_id)
	var plan: Dictionary = BuildRulesClass.plan(definition, state.grid, inventory, actor_id, anchor_cell, rotation, expected_grid_revision)
	preview.show_plan(plan)
	return plan

func place(action_id: StringName, actor_id: StringName, definition_id: StringName, anchor_cell: Vector2i, rotation: int, expected_grid_revision: int = -1):
	var previous = _previous(action_id)
	if previous != null:
		return previous
	if not enabled:
		return _reject(action_id, &"WRONG_OPERATION_STATE")
	var definition = _get_structure_definition(definition_id)
	var plan: Dictionary = preview_structure(actor_id, definition_id, anchor_cell, rotation, expected_grid_revision)
	if not bool(plan.get("accepted", false)):
		return _reject(action_id, plan.get("reason", &"TARGET_INVALID"))
	var site_id := _next_id("build_site")
	var reservation_id := StringName("%s_cost" % String(site_id))
	var reserve_action_id := StringName("%s_reserve" % String(action_id))
	var reserve_result = inventory.reserve(reserve_action_id, actor_id, &"player_pack", definition.cost_item_id, definition.cost_amount, reservation_id, inventory.get_container_revision(&"player_pack"))
	if not reserve_result.accepted:
		return _reject(action_id, reserve_result.reason_code)
	var footprint: Array = plan.get("footprint_cells", [])
	if not state.grid.reserve_cells(reservation_id, footprint):
		inventory.release_reservation(StringName("%s_release" % String(action_id)), actor_id, &"player_pack", reservation_id)
		return _reject(action_id, &"OCCUPIED")
	var site = BuildSiteStateClass.new(site_id, site_id, definition_id, actor_id, anchor_cell, rotation, footprint)
	site.lifecycle = BuildSiteStateClass.Lifecycle.CONSTRUCTING
	site.reserved_items[definition.cost_item_id] = definition.cost_amount
	state.build_sites[site_id] = site
	return _complete_site(action_id, site, definition, reservation_id)

func remove_structure(action_id: StringName, actor_id: StringName, structure_id: StringName, expected_grid_revision: int = -1):
	return _end_structure(action_id, actor_id, structure_id, expected_grid_revision, StructureStateClass.Lifecycle.REMOVED, &"STRUCTURE_REMOVED")

func destroy_structure(action_id: StringName, actor_id: StringName, structure_id: StringName, expected_grid_revision: int = -1):
	return _end_structure(action_id, actor_id, structure_id, expected_grid_revision, StructureStateClass.Lifecycle.DESTROYED, &"STRUCTURE_DESTROYED")

func destroy_from_combat(action_id: StringName, structure_id: StringName):
	return _end_structure(action_id, &"combat", structure_id, -1, StructureStateClass.Lifecycle.DESTROYED, &"STRUCTURE_DESTROYED")

func get_connection_masks(structure_id: StringName) -> Dictionary:
	var structure = state.structures.get(structure_id) if state != null else null
	return structure.connection_masks.duplicate() if structure != null else {}

func _complete_site(action_id: StringName, site, definition, reservation_id: StringName):
	if not inventory.has_reservation(&"player_pack", reservation_id):
		return _reject(action_id, &"RESERVATION_INVALID")
	if not state.grid.commit_structure(site.entity_id, site.footprint_cells, definition, reservation_id):
		return _reject(action_id, &"OCCUPIED")
	var commit_result = inventory.commit_reservation(StringName("%s_commit" % String(action_id)), site.owner_id, &"player_pack", reservation_id)
	if not commit_result.accepted:
		return _reject(action_id, commit_result.reason_code)
	site.lifecycle = BuildSiteStateClass.Lifecycle.COMPLETED
	site.work_progress = 1
	site.committed_items[definition.cost_item_id] = definition.cost_amount
	site.reserved_items.clear()
	var structure = StructureStateClass.new(site.entity_id, site.definition_id, site.owner_id, site.anchor_cell, site.rotation, site.footprint_cells)
	state.structures[structure.structure_id] = structure
	state.revision = state.grid.revision
	var view := StructureViewClass.new()
	_views[structure.structure_id] = view
	structure_root.add_child(view)
	_mark_dirty(site.footprint_cells)
	_refresh_views()
	var facts: Array = commit_result.facts.duplicate()
	facts.append(_fact(&"BUILD_SITE_CREATED", {"build_site_id": site.build_site_id, "entity_id": site.entity_id, "definition_id": site.definition_id}))
	facts.append(_fact(&"STRUCTURE_COMPLETED", {"structure_id": structure.structure_id, "definition_id": structure.definition_id, "footprint_cells": structure.footprint_cells}))
	structure.connection_masks = _masks_for(structure)
	view.configure(structure.structure_id, structure.footprint_cells, structure.connection_masks, structure.definition_id)
	var result = ActionResultClass.accepted_result(action_id, state.revision, facts)
	_remember(action_id, result)
	preview.clear()
	facts_emitted.emit(facts)
	return result

func _end_structure(action_id: StringName, actor_id: StringName, structure_id: StringName, expected_grid_revision: int, lifecycle: int, fact_type: StringName):
	var previous = _previous(action_id)
	if previous != null:
		return previous
	if not enabled:
		return _reject(action_id, &"WRONG_OPERATION_STATE")
	if actor_id != &"player" and actor_id != &"combat":
		return _reject(action_id, &"ACTOR_NOT_AVAILABLE")
	var structure = state.structures.get(structure_id) if state != null else null
	if structure == null or structure.lifecycle != StructureStateClass.Lifecycle.ACTIVE:
		return _reject(action_id, &"TARGET_INVALID")
	if expected_grid_revision >= 0 and state.grid.revision != expected_grid_revision:
		return _reject(action_id, &"STALE_PREVIEW")
	var definition = _get_structure_definition(structure.definition_id)
	if definition == null or not state.grid.remove_structure(structure_id, structure.footprint_cells, definition.occupied_channels):
		return _reject(action_id, &"TARGET_INVALID")
	structure.lifecycle = lifecycle
	state.revision = state.grid.revision
	_mark_dirty(structure.footprint_cells)
	_refresh_views()
	var view = _views.get(structure_id)
	if view != null:
		view.clear()
	var facts: Array = [_fact(fact_type, {"structure_id": structure_id, "definition_id": structure.definition_id, "footprint_cells": structure.footprint_cells})]
	var result = ActionResultClass.accepted_result(action_id, state.revision, facts)
	_remember(action_id, result)
	facts_emitted.emit(facts)
	return result

func _masks_for(structure) -> Dictionary:
	var masks: Dictionary = {}
	for cell_id in structure.footprint_cells:
		masks[cell_id] = state.grid.get_connection_mask(cell_id)
	return masks

func _get_structure_definition(definition_id: StringName):
	var definition = catalog.get_definition(definition_id) if catalog != null else null
	return definition if definition != null and definition.get_script() == StructureDefinitionClass else null

func _mark_dirty(changed_cells: Array) -> void:
	var dirty: Dictionary = {}
	for cell_id in changed_cells:
		dirty[cell_id] = true
		for direction in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			dirty[cell_id + direction] = true
	var ordered: Array = dirty.keys()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	state.dirty_cells = ordered

func _refresh_views() -> void:
	for structure_id in state.structures.keys():
		var structure = state.structures[structure_id]
		if structure.lifecycle != StructureStateClass.Lifecycle.ACTIVE:
			continue
		structure.connection_masks = _masks_for(structure)
		var view = _views.get(structure_id)
		if view != null:
			view.update_masks(structure.connection_masks)

func _fact(fact_type: StringName, payload: Dictionary):
	_fact_sequence += 1
	return WorldFactClass.new(StringName("%s_%d" % [String(operation_id), _fact_sequence]), fact_type, operation_id, payload)

func _next_id(prefix: String) -> StringName:
	_sequence += 1
	return StringName("%s_%d" % [prefix, _sequence])

func _previous(action_id: StringName):
	return _processed_actions.get(action_id) if _processed_actions.has(action_id) else null

func _reject(action_id: StringName, reason: StringName):
	var result = ActionResultClass.rejected(action_id, reason, state.revision if state != null else 0)
	_remember(action_id, result)
	return result

func _remember(action_id: StringName, result) -> void:
	if not String(action_id).is_empty():
		_processed_actions[action_id] = result
