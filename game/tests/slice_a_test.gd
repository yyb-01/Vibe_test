extends Node

const AppRootScene = preload("res://game/app/app_root.tscn")
const AppFlowStateClass = preload("res://game/app/app_flow_state.gd")
const ContentManifestClass = preload("res://game/content/content_manifest.gd")
const ContentValidatorClass = preload("res://game/content/content_validator.gd")
const ItemDefinitionClass = preload("res://game/content/definitions/item_definition.gd")
const OperationDefinitionClass = preload("res://game/content/definitions/operation_definition.gd")

var failures: int = 0
var checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var validator := ContentValidatorClass.new()
	var valid_manifest := load("res://game/content/content_manifest.tres") as ContentManifest
	_check(validator.validate(valid_manifest).is_empty(), "valid manifest passes validation")

	var invalid_manifest := ContentManifestClass.new()
	var duplicate := ItemDefinitionClass.new()
	duplicate.id = &"duplicate"
	invalid_manifest.definitions = [duplicate, duplicate]
	_check(not validator.validate(invalid_manifest).is_empty(), "duplicate IDs fail validation")

	var missing_reference := OperationDefinitionClass.new()
	missing_reference.id = &"broken"
	missing_reference.terrain_id = &"missing"
	invalid_manifest.definitions = [missing_reference]
	_check(not validator.validate(invalid_manifest).is_empty(), "missing references fail validation")

	var invalid_app := AppRootScene.instantiate() as AppRoot
	invalid_app.content_manifest = invalid_manifest
	get_tree().root.add_child(invalid_app)
	await get_tree().process_frame
	_check(not invalid_app.booted, "invalid content does not boot")
	_check(invalid_app.current_screen.get_node_or_null("MainMenu") == null, "invalid content does not enter Main Menu")
	invalid_app.free()

	var app := AppRootScene.instantiate() as AppRoot
	get_tree().root.add_child(app)
	await get_tree().process_frame
	_check(app.booted, "valid content boots AppRoot")
	_check(app.app_flow_state.current_screen == AppFlowStateClass.Screen.MAIN_MENU, "boot enters Main Menu")
	_check(app.current_screen.get_node_or_null("MainMenu") != null, "Main Menu screen is mounted")
	_check(app.content_catalog.has_definition(&"outpost"), "catalog indexes operation definition")
	_check(not app.content_catalog.catalog_hash.is_empty(), "catalog hash is generated")
	app.free()

	print("SLICE A TESTS: %d passed, %d failed" % [checks - failures, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _check(condition: bool, name: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % name)
	else:
		failures += 1
		printerr("[FAIL] %s" % name)
