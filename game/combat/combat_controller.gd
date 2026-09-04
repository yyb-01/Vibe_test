class_name CombatController
extends Node

const ActionResultClass = preload("res://game/shared/action_result.gd")
const WorldFactClass = preload("res://game/shared/world_fact.gd")
const DamageRulesClass = preload("res://game/combat/damage_rules.gd")
const AttackStateClass = preload("res://game/combat/attack_state.gd")
const EnemyStateClass = preload("res://game/combat/enemy_state.gd")
const CombatStateClass = preload("res://game/combat/combat_state.gd")
const PathServiceClass = preload("res://game/combat/path_service.gd")
const SpawnPlannerClass = preload("res://game/combat/spawn_planner.gd")
const StructureDefinitionClass = preload("res://game/content/definitions/structure_definition.gd")
const StructureStateClass = preload("res://game/build/structure_state.gd")
const EnemyDefinitionClass = preload("res://game/content/definitions/enemy_definition.gd")
const EnemyAgentClass = preload("res://game/combat/enemy_agent.gd")

signal facts_emitted(facts: Array)
signal core_destroyed
signal enemy_defeated(enemy_id: StringName)

@onready var enemy_view = get_node("../World/DynamicEntities/EnemyAgent")
@onready var enemy_root = get_node("../World/DynamicEntities")
@onready var core_view = get_node("../World/Core")

var state
var operation_id: StringName
var catalog
var build
var inventory
var path_service
var enabled: bool = false
var target_cell: Vector2i
var enemy_damage: int
var enemy_cooldown_ticks: int
var enemy_archetype_id: StringName = &"scavenger"
var enemy_definition_id: StringName = &"enemy_scavenger"
var _processed_actions: Dictionary = {}
var _fact_sequence: int = 0
var _attack_sequence: int = 0
var _enemy_views: Dictionary = {}
var _primary_enemy_id: StringName = &"enemy_01"


func setup(next_operation_id: StringName, next_catalog, next_build, core_position: Vector2, core_max_health: int, spawn_cell: Vector2i, enemy_definition, next_enemy_spawn_entries: Array = []) -> bool:
	if next_catalog == null or next_build == null or next_build.state == null or core_max_health <= 0 or enemy_definition == null or enemy_definition.get_script() != EnemyDefinitionClass:
		return false
	operation_id = next_operation_id
	catalog = next_catalog
	build = next_build
	inventory = next_build.inventory
	path_service = PathServiceClass.new(build.state.grid)
	var grid = build.state.grid
	var core_cell: Vector2i = grid.world_to_cell(core_position)
	var spawn_entries: Array = next_enemy_spawn_entries.duplicate()
	if spawn_entries.is_empty():
		spawn_entries = [{"id": &"enemy_01", "definition_id": enemy_definition.id, "spawn_cell": spawn_cell}]
	var first_spawn_cell: Vector2i = spawn_entries[0].get("spawn_cell", spawn_cell) if typeof(spawn_entries[0]) == TYPE_DICTIONARY else spawn_cell
	target_cell = _approach_cell(grid, core_cell, first_spawn_cell)
	var spawn_plan: Dictionary = SpawnPlannerClass.plan_entries(path_service, spawn_entries, target_cell)
	if not bool(spawn_plan.get("accepted", false)):
		return false
	var planned_entries: Array = spawn_plan.get("entries", [])
	if planned_entries.is_empty():
		return false
	state = CombatStateClass.new()
	state.core_cell = core_cell
	state.protected_target_cell = target_cell
	state.navigation_revision = path_service.navigation_revision()
	state.health_by_entity[&"core"] = {"current": core_max_health, "maximum": core_max_health}
	_primary_enemy_id = StringName(planned_entries[0].get("id", &"enemy_01"))
	for planned_value in planned_entries:
		var planned: Dictionary = planned_value
		var enemy_id := StringName(planned.get("id", ""))
		var definition_id := StringName(planned.get("definition_id", ""))
		var definition := catalog.get_definition(definition_id) as EnemyDefinition
		var planned_spawn_cell: Vector2i = planned.get("spawn_cell", Vector2i.ZERO)
		if String(enemy_id).is_empty() or definition == null or definition.get_script() != EnemyDefinitionClass:
			return false
		var enemy = EnemyStateClass.new(enemy_id, planned_spawn_cell, definition_id)
		enemy.path = planned.get("path", []).duplicate()
		enemy.path_index = 1 if enemy.path.size() > 1 else enemy.path.size()
		enemy.attack_damage = int(definition.attack_damage)
		enemy.attack_cooldown_ticks = int(definition.attack_cooldown_ticks)
		if enemy.attack_damage <= 0 or enemy.attack_cooldown_ticks <= 0 or definition.max_health <= 0:
			return false
		state.enemies[enemy_id] = enemy
		state.health_by_entity[enemy_id] = {"current": definition.max_health, "maximum": definition.max_health}
	var first_enemy = state.enemies[_primary_enemy_id]
	var first_definition := catalog.get_definition(first_enemy.definition_id) as EnemyDefinition
	enemy_damage = first_enemy.attack_damage
	enemy_cooldown_ticks = first_enemy.attack_cooldown_ticks
	enemy_archetype_id = first_definition.presentation_id
	enemy_definition_id = first_enemy.definition_id
	_processed_actions.clear()
	_fact_sequence = 0
	_attack_sequence = 0
	enabled = false
	refresh_enemy_views()
	core_view.configure_health(core_max_health)
	return true

func set_enabled(next_enabled: bool) -> void:
	enabled = next_enabled

func advance_tick(tick: int) -> Array:
	var facts: Array = []
	if not enabled or state == null:
		return facts
	_sync_structure_health()
	if path_service.navigation_revision() != state.navigation_revision:
		state.navigation_revision = path_service.navigation_revision()
		for enemy in state.enemies.values():
			_repath(enemy)
	for enemy in state.enemies.values():
		if enemy.lifecycle == EnemyStateClass.Lifecycle.DYING or enemy.lifecycle == EnemyStateClass.Lifecycle.REMOVED:
			continue
		if enemy.attack_cooldown > 0:
			enemy.attack_cooldown -= 1
		if enemy.cell == target_cell:
			enemy.lifecycle = EnemyStateClass.Lifecycle.ATTACKING
			facts.append_array(_attack_core(enemy, tick))
			enemy.lifecycle = EnemyStateClass.Lifecycle.RECOVERING if enemy.attack_cooldown > 0 else EnemyStateClass.Lifecycle.SEEKING
			continue
		if enemy.lifecycle == EnemyStateClass.Lifecycle.RECOVERING and enemy.attack_cooldown > 0:
			continue
		if enemy.lifecycle == EnemyStateClass.Lifecycle.SPAWNING:
			enemy.lifecycle = EnemyStateClass.Lifecycle.SEEKING
		_move_enemy(enemy)
	if not facts.is_empty():
		facts_emitted.emit(facts)
	return facts

func damage_structure(action_id: StringName, actor_id: StringName, structure_id: StringName, amount: int):
	var previous = _processed_actions.get(action_id) if _processed_actions.has(action_id) else null
	if previous != null:
		return previous
	if not enabled or state == null or build == null:
		return _reject(action_id, &"WRONG_OPERATION_STATE")
	if String(actor_id).is_empty() or (actor_id != &"player" and not state.enemies.has(actor_id)):
		return _reject(action_id, &"ACTOR_NOT_AVAILABLE")
	_sync_structure_health()
	var structure = build.state.structures.get(structure_id)
	if structure == null or structure.lifecycle != StructureStateClass.Lifecycle.ACTIVE:
		return _reject(action_id, &"TARGET_INVALID")
	var health: Dictionary = state.health_by_entity.get(structure_id, {})
	var plan: Dictionary = DamageRulesClass.plan(int(health.get("current", 0)), amount)
	if not bool(plan.get("accepted", false)):
		return _reject(action_id, plan.get("reason", &"TARGET_INVALID"))
	var destruction_facts: Array = []
	if bool(plan.get("defeated", false)):
		var destroy_result = build.destroy_from_combat(StringName("%s_destroy" % String(action_id)), structure_id)
		if not destroy_result.accepted:
			return _reject(action_id, &"TARGET_INVALID")
		destruction_facts = destroy_result.facts.duplicate()
	var facts: Array = _commit_damage(actor_id, structure_id, plan, 0, &"")
	facts.append_array(destruction_facts)
	var result = ActionResultClass.accepted_result(action_id, state.revision, facts)
	_processed_actions[action_id] = result
	facts_emitted.emit(facts)
	return result

func damage_enemy(action_id: StringName, actor_id: StringName, enemy_id: StringName, amount: int, tick: int = 0):
	var previous = _processed_actions.get(action_id) if _processed_actions.has(action_id) else null
	if previous != null:
		return previous
	if not enabled or state == null:
		return _reject(action_id, &"WRONG_OPERATION_STATE")
	if actor_id != &"player":
		return _reject(action_id, &"ACTOR_NOT_AVAILABLE")
	var enemy = state.enemies.get(enemy_id)
	if enemy == null:
		return _reject(action_id, &"TARGET_INVALID")
	var health: Dictionary = state.health_by_entity.get(enemy_id, {})
	var plan: Dictionary = DamageRulesClass.plan(int(health.get("current", 0)), amount)
	if not bool(plan.get("accepted", false)):
		return _reject(action_id, plan.get("reason", &"TARGET_INVALID"))
	var facts: Array = _commit_damage(actor_id, enemy_id, plan, tick, &"")
	if bool(plan.get("defeated", false)):
		facts.append_array(_spawn_enemy_drop(enemy, tick))
	var result = ActionResultClass.accepted_result(action_id, state.revision, facts)
	_processed_actions[action_id] = result
	facts_emitted.emit(facts)
	return result

func spawn_ticket(ticket) -> Dictionary:
	if not enabled or state == null or ticket == null or ticket.spawn_entries.is_empty():
		return {"accepted": false, "reason": &"SPAWN_INVALID", "enemy_ids": []}
	for value in ticket.spawn_entries:
		if typeof(value) != TYPE_DICTIONARY:
			return {"accepted": false, "reason": &"SPAWN_INVALID", "enemy_ids": []}
		var enemy_id := StringName(value.get("id", ""))
		if String(enemy_id).is_empty() or state.enemies.has(enemy_id) or state.defeated_entities.has(enemy_id):
			return {"accepted": false, "reason": &"SPAWN_INVALID", "enemy_ids": []}
	var spawn_plan: Dictionary = SpawnPlannerClass.plan_entries(path_service, ticket.spawn_entries, target_cell)
	if not bool(spawn_plan.get("accepted", false)):
		return {"accepted": false, "reason": spawn_plan.get("reason", &"ROUTE_MISSING"), "enemy_ids": []}
	var planned_entries: Array = spawn_plan.get("entries", [])
	var definitions: Dictionary = {}
	for planned_value in planned_entries:
		var planned: Dictionary = planned_value
		var enemy_id := StringName(planned.get("id", ""))
		var definition_id := StringName(planned.get("definition_id", ""))
		var definition := catalog.get_definition(definition_id) as EnemyDefinition
		if String(enemy_id).is_empty() or definitions.has(enemy_id) or definition == null or definition.get_script() != EnemyDefinitionClass:
			return {"accepted": false, "reason": &"SPAWN_INVALID", "enemy_ids": []}
		definitions[enemy_id] = definition
	var enemy_ids: Array = []
	for planned_value in planned_entries:
		var planned: Dictionary = planned_value
		var enemy_id := StringName(planned.get("id", ""))
		var definition: EnemyDefinition = definitions[enemy_id]
		var enemy = EnemyStateClass.new(enemy_id, planned.get("spawn_cell", Vector2i.ZERO), definition.id)
		enemy.path = planned.get("path", []).duplicate()
		enemy.path_index = 1 if enemy.path.size() > 1 else enemy.path.size()
		enemy.attack_damage = int(definition.attack_damage)
		enemy.attack_cooldown_ticks = int(definition.attack_cooldown_ticks)
		state.enemies[enemy_id] = enemy
		state.health_by_entity[enemy_id] = {"current": definition.max_health, "maximum": definition.max_health}
		enemy_ids.append(enemy_id)
	state.revision += 1
	refresh_enemy_views()
	var facts: Array = [_fact(&"ENEMY_WAVE_SPAWNED", {"ticket_id": ticket.ticket_id, "wave_id": ticket.enemy_pool_id, "enemy_ids": enemy_ids.duplicate()})]
	facts_emitted.emit(facts)
	return {"accepted": true, "reason": &"ACCEPTED", "enemy_ids": enemy_ids, "facts": facts}

func _move_enemy(enemy) -> void:
	if enemy.path_index >= enemy.path.size():
		_repath(enemy)
	if enemy.path_index >= enemy.path.size():
		enemy.lifecycle = EnemyStateClass.Lifecycle.RECOVERING
		return
	var next_cell: Vector2i = enemy.path[enemy.path_index]
	if not path_service.is_cell_walkable(next_cell):
		_repath(enemy)
		if enemy.path_index >= enemy.path.size():
			return
		next_cell = enemy.path[enemy.path_index]
	enemy.lifecycle = EnemyStateClass.Lifecycle.MOVING
	enemy.cell = next_cell
	enemy.path_index += 1
	var view = _enemy_views.get(enemy.enemy_id)
	if view != null:
		view.set_cell(next_cell)

func _repath(enemy) -> void:
	enemy.path = path_service.find_path(enemy.cell, target_cell)
	enemy.path_index = 1 if enemy.path.size() > 1 else enemy.path.size()
	enemy.lifecycle = EnemyStateClass.Lifecycle.SEEKING if not enemy.path.is_empty() else EnemyStateClass.Lifecycle.RECOVERING

func _attack_core(enemy, tick: int) -> Array:
	if enemy.attack_cooldown > 0:
		return []
	var health: Dictionary = state.health_by_entity[&"core"]
	var plan: Dictionary = DamageRulesClass.plan(int(health.current), enemy.attack_damage)
	if not bool(plan.get("accepted", false)):
		return []
	_attack_sequence += 1
	var attack_id := StringName("attack_%d" % _attack_sequence)
	var attack = AttackStateClass.new(attack_id, enemy.enemy_id, &"core", enemy.attack_damage, tick)
	state.attacks[attack_id] = attack
	attack.lifecycle = AttackStateClass.Lifecycle.RESOLVED
	enemy.attack_cooldown = enemy.attack_cooldown_ticks
	return _commit_damage(enemy.enemy_id, &"core", plan, tick, attack_id)

func _commit_damage(source_id: StringName, target_id: StringName, plan: Dictionary, tick: int, attack_id: StringName) -> Array:
	var health: Dictionary = state.health_by_entity[target_id]
	health["current"] = int(plan.remaining)
	state.health_by_entity[target_id] = health
	state.revision += 1
	if target_id == &"core":
		core_view.set_health(int(health.current))
	else:
		var view = _enemy_views.get(target_id)
		if view != null:
			view.set_health(int(health.current))
	var facts: Array = [_fact(&"DAMAGE_APPLIED", {"source_entity_id": source_id, "target_entity_id": target_id, "amount": int(plan.applied), "remaining_health": int(plan.remaining), "tick": tick, "attack_id": attack_id})]
	if bool(plan.defeated) and not state.defeated_entities.has(target_id):
		state.defeated_entities[target_id] = true
		var defeated_enemy = state.enemies.get(target_id)
		if defeated_enemy != null:
			defeated_enemy.lifecycle = EnemyStateClass.Lifecycle.DYING
			var defeated_view = _enemy_views.get(target_id)
			if defeated_view != null:
				defeated_view.clear()
		facts.append(_fact(&"ENTITY_DEFEATED", {"entity_id": target_id, "source_entity_id": source_id, "tick": tick}))
		if target_id == &"core":
			enabled = false
			core_destroyed.emit()
		else:
			enemy_defeated.emit(target_id)
	return facts

func _spawn_enemy_drop(enemy, tick: int) -> Array:
	var definition := catalog.get_definition(enemy.definition_id) as EnemyDefinition
	if definition == null or definition.drop_amount <= 0:
		return []
	var pickup_id := StringName("drop_%s" % String(enemy.enemy_id))
	if inventory == null or not inventory.add_pickup(pickup_id, definition.drop_item_id, definition.drop_amount, Vector2(enemy.cell) * 32.0):
		return [_fact(&"ENEMY_DROP_REJECTED", {"enemy_id": enemy.enemy_id, "item_id": definition.drop_item_id, "amount": definition.drop_amount, "tick": tick})]
	return [_fact(&"ENEMY_DROP_CREATED", {"enemy_id": enemy.enemy_id, "pickup_id": pickup_id, "item_id": definition.drop_item_id, "amount": definition.drop_amount, "tick": tick})]

func refresh_enemy_views() -> void:
	if state == null:
		return
	for view in _enemy_views.values():
		if view != enemy_view and is_instance_valid(view):
			view.queue_free()
	_enemy_views.clear()
	for enemy in state.enemies.values():
		var definition := catalog.get_definition(enemy.definition_id) as EnemyDefinition
		if definition == null:
			continue
		var view = enemy_view if enemy.enemy_id == _primary_enemy_id else EnemyAgentClass.new()
		if view != enemy_view:
			enemy_root.add_child(view)
		view.configure(enemy.enemy_id, enemy.cell, definition.max_health, definition.presentation_id)
		view.set_health(int(state.health_by_entity.get(enemy.enemy_id, {}).get("current", definition.max_health)))
		_enemy_views[enemy.enemy_id] = view
	if _enemy_views.is_empty():
		enemy_view.clear()

func _sync_structure_health() -> void:
	for structure_id in build.state.structures.keys():
		var structure = build.state.structures[structure_id]
		if structure.lifecycle != StructureStateClass.Lifecycle.ACTIVE or state.health_by_entity.has(structure_id):
			continue
		var definition = catalog.get_definition(structure.definition_id)
		if definition == null or definition.get_script() != StructureDefinitionClass:
			continue
		state.health_by_entity[structure_id] = {"current": definition.max_health, "maximum": definition.max_health}

func _approach_cell(grid, core_cell: Vector2i, spawn_cell: Vector2i) -> Vector2i:
	var dx := spawn_cell.x - core_cell.x
	var dy := spawn_cell.y - core_cell.y
	var preferred := core_cell + (Vector2i(1 if dx > 0 else -1, 0) if abs(dx) >= abs(dy) else Vector2i(0, 1 if dy > 0 else -1))
	for cell in [preferred, core_cell + Vector2i(1, 0), core_cell + Vector2i(-1, 0), core_cell + Vector2i(0, 1), core_cell + Vector2i(0, -1)]:
		if grid.is_in_bounds(cell) and path_service.is_cell_walkable(cell):
			return cell
	return preferred

func _fact(fact_type: StringName, payload: Dictionary):
	_fact_sequence += 1
	return WorldFactClass.new(StringName("%s_%d" % [String(operation_id), _fact_sequence]), fact_type, operation_id, payload)

func _reject(action_id: StringName, reason: StringName):
	var result = ActionResultClass.rejected(action_id, reason, state.revision if state != null else 0)
	_processed_actions[action_id] = result
	return result
