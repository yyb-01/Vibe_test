extends Node

const AppRootScene = preload("res://game/app/app_root.tscn")
const AppFlowStateClass = preload("res://game/app/app_flow_state.gd")
const OperationStateClass = preload("res://game/operation/operation_state.gd")
const BuildSiteStateClass = preload("res://game/build/build_site_state.gd")
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
	_check(operation != null, "Operation starts for build slice")
	if operation == null:
		_finish(app)
		return
	await get_tree().physics_frame
	_check(operation.controller.state.lifecycle_state == OperationStateClass.Lifecycle.ACTIVE, "build slice reaches ACTIVE")
	var build = operation.controller.build
	var inventory = operation.controller.inventory
	build.facts_emitted.connect(_on_facts_emitted)
	_check(inventory.pickup(&"build_pickup", &"pickup_wood_01", &"player").accepted, "build test acquires construction cost")
	var grid = build.state.grid
	var revision_before_preview: int = grid.revision
	var preview_result: Dictionary = build.preview_structure(&"player", &"wall", Vector2i(2, 0), 0, revision_before_preview)
	_check(preview_result.accepted, "valid preview is accepted")
	_check(grid.revision == revision_before_preview, "preview does not mutate BuildGrid")
	var invalid_preview: Dictionary = build.preview_structure(&"player", &"wall", Vector2i(100, 100), 0, revision_before_preview)
	_check(not invalid_preview.accepted and invalid_preview.reason == &"OUT_OF_BOUNDS", "out-of-bounds preview is rejected")
	_check(grid.revision == revision_before_preview, "invalid preview remains read-only")

	var first_result = build.place(&"build_wall_1", &"player", &"wall", Vector2i(2, 0), 0, grid.revision)
	_check(first_result.accepted, "first wall commits")
	var first_id: StringName = build.state.structures.keys()[0]
	_check(build.state.build_sites[first_id].lifecycle == BuildSiteStateClass.Lifecycle.COMPLETED, "BuildSite reaches COMPLETED")
	_check(inventory.get_item_count(&"player_pack", &"wood") == 4, "build consumes reserved cost")
	_check(not inventory.has_reservation(&"player_pack", StringName("build_wall_1_cost")), "build reservation is cleared")
	var navigation_after_first: int = grid.navigation_revision

	var second_result = build.place(&"build_wall_2", &"player", &"wall", Vector2i(3, 0), 0, grid.revision)
	_check(second_result.accepted, "adjacent wall commits")
	var second_id: StringName = build.state.structures.keys()[1]
	var first_mask := int(build.get_connection_masks(first_id).get(Vector2i(2, 0), 0))
	var second_mask := int(build.get_connection_masks(second_id).get(Vector2i(3, 0), 0))
	_check((first_mask & 2) != 0 and (second_mask & 8) != 0, "adjacent walls resolve reciprocal connection masks")
	_check(grid.navigation_revision > navigation_after_first, "SOLID placement updates AStarGrid2D revision")
	_check(grid.has_path(Vector2i(-8, 0), Vector2i(8, 0)), "navigation keeps a route around walls")
	_check(emitted_fact_types.has("BUILD_SITE_CREATED") and emitted_fact_types.has("STRUCTURE_COMPLETED"), "build emits completion facts")

	var remove_result = build.remove_structure(&"remove_wall_2", &"player", second_id, grid.revision)
	_check(remove_result.accepted and grid.get_occupant(Vector2i(3, 0)) == &"", "demolition releases occupied cell")
	_check(build.state.structures[second_id].lifecycle == StructureStateClass.Lifecycle.REMOVED, "demolition preserves structure identity")
	_check((int(build.get_connection_masks(first_id).get(Vector2i(2, 0), 0)) & 2) == 0, "neighbor connection refreshes after demolition")
	_check(grid.has_path(Vector2i(-8, 0), Vector2i(8, 0)), "navigation route recovers after demolition")

	var destroy_result = build.destroy_structure(&"destroy_wall_1", &"player", first_id, grid.revision)
	_check(destroy_result.accepted and grid.get_occupant(Vector2i(2, 0)) == &"", "destruction releases SOLID occupancy")
	_check(build.state.structures[first_id].lifecycle == StructureStateClass.Lifecycle.DESTROYED, "destruction records terminal state")
	_check(emitted_fact_types.has("STRUCTURE_REMOVED") and emitted_fact_types.has("STRUCTURE_DESTROYED"), "removal and destruction emit facts")

	var restore_result = build.place(&"restore_wall", &"player", &"wall", Vector2i(2, 0), 0, grid.revision)
	_check(restore_result.accepted and grid.get_occupant(Vector2i(2, 0)) != &"", "cleared cell can be rebuilt")
	_check(build.state.dirty_cells.has(Vector2i(3, 0)), "dirty set includes changed neighbors")

	_check(operation.request_end(OperationStateClass.EndReason.ABANDONED), "build operation accepts end")
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(app.current_operation == null, "build operation closes cleanly")
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.SETTLEMENT, "build slice enters Settlement")
	app.current_screen.get_node("SettlementScreen/Panel/Layout/Continue").emit_signal("pressed")
	await get_tree().process_frame
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.CAMPAIGN, "flow returns after build slice")
	_finish(app)

func _on_facts_emitted(facts: Array) -> void:
	for fact in facts:
		emitted_fact_types.append(String(fact.fact_type))

func _finish(app: AppRoot) -> void:
	app.free()
	print("SLICE D TESTS: %d passed, %d failed" % [checks - failures, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _check(condition: bool, name: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % name)
	else:
		failures += 1
		printerr("[FAIL] %s" % name)
