class_name OperationController
extends Node

const OperationStateClass = preload("res://game/operation/operation_state.gd")
const OperationClockClass = preload("res://game/operation/operation_clock.gd")
const ActionResultClass = preload("res://game/shared/action_result.gd")
const WorldFactClass = preload("res://game/shared/world_fact.gd")
const RequestExtractionActionClass = preload("res://game/operation/request_extraction_action.gd")
const OperationOutcomeClass = preload("res://game/settlement/operation_outcome.gd")
const EnemyDefinitionClass = preload("res://game/content/definitions/enemy_definition.gd")
const TerrainDefinitionClass = preload("res://game/content/definitions/terrain_definition.gd")
const PickupViewClass = preload("res://game/inventory/pickup_view.gd")
const StructureDefinitionClass = preload("res://game/content/definitions/structure_definition.gd")

signal closed(reason: int)
signal outcome_ready(outcome)
signal facts_emitted(facts: Array)

@onready var world = get_node("../World")
@onready var player = get_node("../World/DynamicEntities/Player")
@onready var core = get_node("../World/Core")
@onready var inventory = get_node("../InventoryController")
@onready var build = get_node("../BuildController")
@onready var combat = get_node("../CombatController")
@onready var objective = get_node("../ObjectiveController")
@onready var threat = get_node("../ThreatDirector")
@onready var pickup_root = get_node("../World/Pickups")
@onready var pickup_view = get_node("../World/Pickups/WoodPickup")

var state
var clock
var _definition: OperationDefinition
var _action_sequence: int = 0
var _fact_sequence: int = 0
var _processed_actions: Dictionary = {}
var _content_revision: String = ""
var outcome
var terrain_id: StringName = &"grass"
var available_blueprint_ids: Array = [&"wall"]
var _pickup_views: Dictionary = {}
var _primary_pickup_id: StringName = &""

func _ready() -> void:
	inventory.pickup_removed.connect(_on_pickup_removed)
	inventory.pickup_added.connect(_on_pickup_added)
	inventory.facts_emitted.connect(_on_facts_emitted)
	build.facts_emitted.connect(_on_facts_emitted)
	combat.facts_emitted.connect(_on_facts_emitted)
	combat.enemy_defeated.connect(_on_enemy_defeated)
	threat.spawn_ticket_created.connect(_on_spawn_ticket_created)
	objective.extraction_eligibility_opened.connect(_on_extraction_eligibility_opened)
	combat.core_destroyed.connect(_on_core_destroyed)

func start(catalog: ContentCatalog, operation_id: StringName, runtime_operation_id: StringName = &"", next_blueprint_ids: Array = [], next_terrain_id: StringName = &"") -> bool:
	if state != null or catalog == null:
		return false
	var definition := catalog.get_definition(operation_id) as OperationDefinition
	if definition == null:
		return false
	var selected_terrain_id := StringName(next_terrain_id)
	if String(selected_terrain_id).is_empty():
		selected_terrain_id = definition.terrain_id
	var terrain = catalog.get_definition(selected_terrain_id)
	if terrain == null or terrain.get_script() != TerrainDefinitionClass or not world.supports_terrain(selected_terrain_id):
		return false
	var operation_instance_id: StringName = operation_id if String(runtime_operation_id).is_empty() else runtime_operation_id

	_definition = definition
	terrain_id = selected_terrain_id
	_content_revision = catalog.catalog_hash
	state = OperationStateClass.new(operation_instance_id, definition.id, definition.seed)
	clock = OperationClockClass.new()
	_action_sequence = 0
	_fact_sequence = 0
	_processed_actions.clear()
	outcome = null
	world.configure(definition.map_size, terrain_id)
	core.position = definition.core_position
	player.position = definition.player_spawn
	player.configure(definition.player_speed, _player_bounds(definition.map_size))
	player.set_enabled(false)
	var enemy_definition := catalog.get_definition(definition.enemy_definition_id) as EnemyDefinition
	if enemy_definition == null or enemy_definition.get_script() != EnemyDefinitionClass:
		return false
	var pickup_entries: Array = definition.pickup_entries
	if pickup_entries.is_empty() or typeof(pickup_entries[0]) != TYPE_DICTIONARY:
		return false
	var first_pickup: Dictionary = pickup_entries[0]
	var first_pickup_id := StringName(first_pickup.get("id", ""))
	var first_item_id := StringName(first_pickup.get("item_id", ""))
	var first_amount := int(first_pickup.get("amount", 0))
	var first_position: Vector2 = first_pickup.get("position", Vector2.ZERO)
	if not inventory.setup(operation_instance_id, catalog, &"player", definition.player_pack_capacity, definition.core_storage_capacity, first_pickup_id, first_item_id, first_amount, first_position):
		return false
	_primary_pickup_id = first_pickup_id
	for pickup_value in pickup_entries.slice(1):
		if typeof(pickup_value) != TYPE_DICTIONARY:
			return false
		var pickup: Dictionary = pickup_value
		if not inventory.add_pickup(StringName(pickup.get("id", "")), StringName(pickup.get("item_id", "")), int(pickup.get("amount", 0)), pickup.get("position", Vector2.ZERO)):
			return false
	state.inventory_state = inventory.state
	if not build.setup(operation_instance_id, definition.map_size, inventory, catalog, definition.core_position):
		return false
	available_blueprint_ids = _valid_blueprints(catalog, next_blueprint_ids)
	if available_blueprint_ids.is_empty() or not build.select_definition(available_blueprint_ids[0]):
		return false
	state.build_state = build.state
	if not combat.setup(operation_instance_id, catalog, build, definition.core_position, definition.core_max_health, definition.enemy_spawn_cell, enemy_definition, definition.enemy_spawn_entries):
		return false
	state.combat_state = combat.state
	if not objective.setup(operation_instance_id, definition.objective_id, definition.objective_fact_type, definition.objective_item_id, definition.objective_amount, state.logical_tick):
		return false
	state.objective_state = objective.state
	if not threat.setup(operation_instance_id, definition.threat_fact_types, definition.threat_pressure_per_action, definition.threat_pressure_threshold, definition.threat_event_duration_ticks, definition.enemy_spawn_waves):
		return false
	state.threat_state = threat.state
	_refresh_pickup_views()
	return state.transition_to(OperationState.Lifecycle.INSERTION)

func end_operation(reason: int) -> bool:
	if state == null or state.lifecycle_state != OperationStateClass.Lifecycle.ACTIVE:
		return false
	if reason == OperationStateClass.EndReason.COMPLETED:
		return request_extraction(_next_action_id("extract")).accepted
	state.end_reason = reason
	return state.transition_to(OperationStateClass.Lifecycle.RESOLVING)

func request_extraction(action_id: StringName):
	var previous = _processed_actions.get(action_id) if _processed_actions.has(action_id) else null
	if previous != null:
		return previous
	var action = RequestExtractionActionClass.new(action_id)
	if String(action.action_id).is_empty():
		return _reject(action.action_id, &"ACTION_INVALID")
	if state == null or state.lifecycle_state != OperationStateClass.Lifecycle.ACTIVE:
		return _reject(action.action_id, &"WRONG_OPERATION_STATE")
	if not state.extraction_eligible:
		return _reject(action.action_id, &"OBJECTIVE_INCOMPLETE")
	state.end_reason = OperationStateClass.EndReason.COMPLETED
	if not state.transition_to(OperationStateClass.Lifecycle.EXTRACTION):
		return _reject(action.action_id, &"WRONG_OPERATION_STATE")
	threat.start_extraction_pressure(state.logical_tick)
	var facts: Array = [_fact(&"EXTRACTION_REQUESTED", {"action_id": action.action_id})]
	var result = ActionResultClass.accepted_result(action.action_id, state.revision, facts)
	_processed_actions[action.action_id] = result
	facts_emitted.emit(facts)
	return result

func _physics_process(_delta: float) -> void:
	if state == null:
		return
	match state.lifecycle_state:
		OperationStateClass.Lifecycle.INSERTION:
			state.transition_to(OperationStateClass.Lifecycle.ACTIVE)
			player.set_enabled(true)
			build.set_enabled(true)
			combat.set_enabled(true)
			objective.set_enabled(true)
			threat.set_enabled(true)
		OperationStateClass.Lifecycle.ACTIVE:
			state.logical_tick = clock.advance_tick()
			if Input.is_action_just_pressed("ui_accept"):
				_interact()
			if Input.is_action_just_pressed("ui_cancel"):
				end_operation(OperationStateClass.EndReason.ABANDONED)
			combat.advance_tick(state.logical_tick)
			threat.advance_tick(state.logical_tick)
		OperationStateClass.Lifecycle.EXTRACTION:
			state.transition_to(OperationStateClass.Lifecycle.RESOLVING)
		OperationStateClass.Lifecycle.RESOLVING:
			player.set_enabled(false)
			build.set_enabled(false)
			combat.set_enabled(false)
			objective.set_enabled(false)
			threat.set_enabled(false)
			_create_outcome()
			state.transition_to(OperationStateClass.Lifecycle.CLOSED)
			closed.emit(state.end_reason)

func _interact() -> void:
	var pickup_id: StringName = inventory.find_pickup_near(player.position, 76.0)
	if not String(pickup_id).is_empty():
		var pickup_result = inventory.pickup(_next_action_id("pickup"), pickup_id, &"player")
		if pickup_result.accepted:
			return
	if player.position.distance_to(core.position) <= 72.0:
		var secure_result = inventory.secure(_next_action_id("secure"), &"player")
		if secure_result.accepted:
			return
	var anchor_cell: Vector2i = build.state.grid.world_to_cell(player.position)
	build.place(_next_action_id("build"), &"player", build.selected_definition_id, anchor_cell, 0, build.state.grid.revision)

func _next_action_id(prefix: String) -> StringName:
	_action_sequence += 1
	return StringName("%s_%d" % [prefix, _action_sequence])

func refresh_pickup_views() -> void:
	_refresh_pickup_views()

func _refresh_pickup_views() -> void:
	if inventory == null or inventory.state == null:
		return
	var primary_id := _primary_pickup_id
	if not inventory.state.pickups.has(primary_id):
		primary_id = &""
		_primary_pickup_id = primary_id
	for view in _pickup_views.values():
		if view != pickup_view and is_instance_valid(view):
			view.queue_free()
	_pickup_views.clear()
	for pickup in inventory.state.pickups.values():
		var view = pickup_view if pickup.pickup_id == primary_id else PickupViewClass.new()
		if view != pickup_view:
			pickup_root.add_child(view)
		view.position = pickup.position
		view.configure(pickup.pickup_id, pickup.item_id, pickup.amount)
		_pickup_views[pickup.pickup_id] = view
	if _pickup_views.is_empty():
		pickup_view.clear()

func _on_pickup_removed(pickup_id: StringName) -> void:
	var view = _pickup_views.get(pickup_id)
	if view == null:
		return
	view.clear()
	_pickup_views.erase(pickup_id)
	if view == pickup_view:
		_primary_pickup_id = &""
		_refresh_pickup_views()
	else:
		view.queue_free()

func _on_pickup_added(_pickup_id: StringName) -> void:
	_refresh_pickup_views()

func _on_core_destroyed() -> void:
	if state != null and state.lifecycle_state == OperationStateClass.Lifecycle.ACTIVE:
		end_operation(OperationStateClass.EndReason.CORE_DESTROYED)

func _on_facts_emitted(facts: Array) -> void:
	if state == null or state.lifecycle_state != OperationStateClass.Lifecycle.ACTIVE:
		return
	objective.accept_facts(facts, state.logical_tick)
	threat.accept_facts(facts, state.logical_tick)

func _on_spawn_ticket_created(ticket) -> void:
	var result: Dictionary = combat.spawn_ticket(ticket)
	if result.get("accepted", false):
		threat.bind_spawn_ticket(ticket.ticket_id, result.get("enemy_ids", []))
	else:
		threat.cancel_spawn_ticket(ticket.ticket_id)

func _on_enemy_defeated(enemy_id: StringName) -> void:
	threat.mark_enemy_defeated(enemy_id)

func _on_extraction_eligibility_opened(_objective_id: StringName) -> void:
	if state != null:
		state.extraction_eligible = true
		state.revision += 1

func _create_outcome() -> void:
	if outcome != null:
		return
	outcome = OperationOutcomeClass.from_runtime(state, state.inventory_state, state.objective_state, state.combat_state, _content_revision)
	outcome_ready.emit(outcome)

func _fact(fact_type: StringName, payload: Dictionary):
	_fact_sequence += 1
	return WorldFactClass.new(StringName("%s_%d" % [String(state.operation_id), _fact_sequence]), fact_type, state.operation_id, payload)

func _reject(action_id: StringName, reason: StringName):
	var result = ActionResultClass.rejected(action_id, reason, state.revision if state != null else 0)
	if not String(action_id).is_empty():
		_processed_actions[action_id] = result
	return result

func _player_bounds(size: Vector2) -> Rect2:
	var margin := Vector2(28.0, 28.0)
	return Rect2(-size * 0.5 + margin, size - margin * 2.0)

func _valid_blueprints(catalog: ContentCatalog, requested: Array) -> Array:
	var result: Array = []
	for value in requested:
		var definition_id := StringName(value)
		var definition = catalog.get_definition(definition_id)
		if definition != null and definition.get_script() == StructureDefinitionClass and not result.has(definition_id):
			result.append(definition_id)
	if result.is_empty():
		var wall = catalog.get_definition(&"wall")
		if wall != null and wall.get_script() == StructureDefinitionClass:
			result.append(&"wall")
	return result
