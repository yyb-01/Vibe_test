extends Node

const AppRootScene = preload("res://game/app/app_root.tscn")
const AppFlowStateClass = preload("res://game/app/app_flow_state.gd")
const OperationStateClass = preload("res://game/operation/operation_state.gd")
const StructureStateClass = preload("res://game/build/structure_state.gd")

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
	_check(operation != null, "combat operation starts")
	if operation == null:
		_finish(app)
		return
	await get_tree().physics_frame
	_check(operation.controller.state.lifecycle_state == OperationStateClass.Lifecycle.ACTIVE, "combat slice reaches ACTIVE")
	var combat = operation.controller.combat
	var build = operation.controller.build
	var grid = build.state.grid
	combat.facts_emitted.connect(_on_facts_emitted)
	var enemy = combat.state.enemies[&"enemy_01"]
	_check(enemy != null and combat.state.enemies.size() == 3, "three enemy definitions are planned")
	var runner = combat.state.enemies[&"enemy_02"]
	var brute = combat.state.enemies[&"enemy_03"]
	_check(runner.definition_id == &"enemy_runner" and runner.attack_damage == 1 and brute.definition_id == &"enemy_brute" and brute.attack_damage == 2, "enemy definitions apply per-enemy stats")
	_check(grid.has_path(enemy.cell, combat.state.protected_target_cell), "spawn has a valid protected-target route")
	var path_before: Array = enemy.path.duplicate()
	_check(path_before.has(Vector2i(-4, 0)), "initial route crosses the future wall cell")
	var drop_result = combat.damage_enemy(&"damage_runner", &"player", &"enemy_02", 999, 1)
	_check(drop_result.accepted and _has_fact(drop_result.facts, &"ENEMY_DROP_CREATED"), "defeated enemy creates a drop fact")
	_check(operation.controller.inventory.state.pickups.has(&"drop_enemy_02"), "enemy drop enters world inventory")
	_check(operation.controller.inventory.pickup(&"combat_pickup", &"pickup_wood_01", &"player").accepted, "combat test acquires wall cost")
	var navigation_before: int = grid.navigation_revision
	var wall_result = build.place(&"combat_wall", &"player", &"wall", Vector2i(-4, 0), 0, grid.revision)
	_check(wall_result.accepted, "wall placement commits during combat")
	_check(grid.navigation_revision > navigation_before, "wall changes navigation revision")
	combat.advance_tick(1)
	_check(combat.state.navigation_revision == grid.navigation_revision, "enemy observes navigation revision")
	_check(not enemy.path.has(Vector2i(-4, 0)), "enemy re-paths around the wall")
	_check(grid.has_path(enemy.cell, combat.state.protected_target_cell), "re-path remains valid")

	var structure_id: StringName = build.state.structures.keys()[0]
	var damage_result = combat.damage_structure(&"damage_wall", &"enemy_01", structure_id, 999)
	_check(damage_result.accepted, "combat damage accepts structure target")
	_check(grid.get_occupant(Vector2i(-4, 0)) == &"", "lethal structure damage releases occupancy")
	_check(build.state.structures[structure_id].lifecycle == StructureStateClass.Lifecycle.DESTROYED, "combat destruction records terminal state")
	_check(_has_fact(damage_result.facts, &"DAMAGE_APPLIED") and _has_fact(damage_result.facts, &"STRUCTURE_DESTROYED"), "structure damage emits damage and destruction facts")
	combat.advance_tick(2)
	_check(combat.state.navigation_revision == grid.navigation_revision, "enemy refreshes after structure destruction")
	_check(grid.has_path(enemy.cell, combat.state.protected_target_cell), "route recovers after combat destruction")

	var core_health_before := int(combat.state.health_by_entity[&"core"].current)
	for tick in range(3, 24):
		combat.advance_tick(tick)
	var core_health_after := int(combat.state.health_by_entity[&"core"].current)
	_check(core_health_after < core_health_before, "enemy reaches and damages Core")
	_check(combat.state.attacks.size() > 0, "resolved attack state is recorded")
	_check(emitted_fact_types.has("DAMAGE_APPLIED"), "combat emits damage fact")

	_check(operation.request_end(OperationStateClass.EndReason.ABANDONED), "combat operation accepts end")
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(app.current_operation == null, "combat operation closes cleanly")
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.SETTLEMENT, "combat slice enters Settlement")
	app.current_screen.get_node("SettlementScreen/Panel/Layout/Continue").emit_signal("pressed")
	await get_tree().process_frame
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.CAMPAIGN, "flow returns after combat slice")
	_finish(app)

func _has_fact(facts: Array, fact_type: StringName) -> bool:
	for fact in facts:
		if fact.fact_type == fact_type:
			return true
	return false

func _on_facts_emitted(facts: Array) -> void:
	for fact in facts:
		emitted_fact_types.append(String(fact.fact_type))

func _finish(app: AppRoot) -> void:
	app.free()
	print("SLICE E TESTS: %d passed, %d failed" % [checks - failures, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _check(condition: bool, name: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % name)
	else:
		failures += 1
		printerr("[FAIL] %s" % name)
