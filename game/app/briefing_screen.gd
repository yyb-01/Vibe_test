class_name BriefingScreen
extends Control

const StructureDefinitionClass = preload("res://game/content/definitions/structure_definition.gd")
const TerrainDefinitionClass = preload("res://game/content/definitions/terrain_definition.gd")

signal start_requested(action_id: StringName, operation_id: StringName, loadout_item_ids: Array, blueprint_ids: Array, terrain_id: StringName, risk_id: StringName)
signal campaign_requested

var operation_id: StringName = &""
var loadout_item_ids: Array = []
var blueprint_ids: Array = []
var terrain_id: StringName = &""
var risk_id: StringName = &"standard"
var _action_sequence := 0

func _ready() -> void:
	$Panel/Layout/StartOperation.pressed.connect(_on_start_operation_pressed)
	$Panel/Layout/Back.pressed.connect(_on_back_pressed)
	$Panel/Layout/BlueprintSelect.item_selected.connect(_on_blueprint_selected)
	$Panel/Layout/TerrainSelect.item_selected.connect(_on_terrain_selected)

func configure(catalog, campaign_state, next_operation_id: StringName) -> void:
	operation_id = next_operation_id
	var operation = catalog.get_definition(operation_id)
	if operation == null:
		$Panel/Layout/Operation.text = "작전을 찾을 수 없습니다"
		$Panel/Layout/StartOperation.disabled = true
		return
	loadout_item_ids = operation.starting_item_ids.duplicate()
	blueprint_ids.clear()
	terrain_id = StringName(operation.terrain_id)
	$Panel/Layout/TerrainSelect.clear()
	var terrain_ids: Array = []
	for definition_value in catalog.all_definitions():
		var terrain = definition_value
		if terrain == null or terrain.get_script() != TerrainDefinitionClass:
			continue
		var next_terrain_id := StringName(terrain.id)
		terrain_ids.append(next_terrain_id)
		var index: int = $Panel/Layout/TerrainSelect.get_item_count()
		$Panel/Layout/TerrainSelect.add_item(String(terrain.display_name))
		$Panel/Layout/TerrainSelect.set_item_metadata(index, next_terrain_id)
	if not terrain_ids.has(terrain_id) and not terrain_ids.is_empty():
		terrain_id = terrain_ids[0]
	for index in range($Panel/Layout/TerrainSelect.get_item_count()):
		if StringName($Panel/Layout/TerrainSelect.get_item_metadata(index)) == terrain_id:
			$Panel/Layout/TerrainSelect.select(index)
			break
	$Panel/Layout/BlueprintSelect.clear()
	for value in campaign_state.unlocked_blueprint_ids:
		var blueprint_id := StringName(value)
		var blueprint = catalog.get_definition(blueprint_id)
		if blueprint == null or blueprint.get_script() != StructureDefinitionClass:
			continue
		blueprint_ids.append(blueprint_id)
		var index: int = $Panel/Layout/BlueprintSelect.get_item_count()
		$Panel/Layout/BlueprintSelect.add_item(String(blueprint.display_name))
		$Panel/Layout/BlueprintSelect.set_item_metadata(index, blueprint_id)
	if not blueprint_ids.is_empty():
		$Panel/Layout/BlueprintSelect.select(0)
	$Panel/Layout/Operation.text = "작전: %s" % String(operation.display_name)
	$Panel/Layout/Terrain.text = "Terrain: %s" % String(terrain_id)
	$Panel/Layout/Loadout.text = "Loadout: %s" % _names(loadout_item_ids)
	$Panel/Layout/Blueprints.text = "Blueprint: %s" % _names(blueprint_ids)
	$Panel/Layout/Risk.text = "위험 조건: standard"

func show_action_result(result) -> void:
	$Panel/Layout/ActionStatus.text = "StartOperationAction: %s" % String(result.reason_code)

func _on_start_operation_pressed() -> void:
	_action_sequence += 1
	start_requested.emit(StringName("start_operation_%d" % _action_sequence), operation_id, loadout_item_ids, blueprint_ids, terrain_id, risk_id)

func _on_back_pressed() -> void:
	campaign_requested.emit()

func _on_blueprint_selected(index: int) -> void:
	if index < 0 or index >= $Panel/Layout/BlueprintSelect.get_item_count():
		return
	var selected_id := StringName($Panel/Layout/BlueprintSelect.get_item_metadata(index))
	var ordered: Array = [selected_id]
	for item_index in range($Panel/Layout/BlueprintSelect.get_item_count()):
		var blueprint_id := StringName($Panel/Layout/BlueprintSelect.get_item_metadata(item_index))
		if blueprint_id != selected_id:
			ordered.append(blueprint_id)
	blueprint_ids = ordered
	$Panel/Layout/Blueprints.text = "Blueprint: %s" % _names(blueprint_ids)

func _on_terrain_selected(index: int) -> void:
	if index < 0 or index >= $Panel/Layout/TerrainSelect.get_item_count():
		return
	terrain_id = StringName($Panel/Layout/TerrainSelect.get_item_metadata(index))
	$Panel/Layout/Terrain.text = "Terrain: %s" % String(terrain_id)

func _names(values: Array) -> String:
	if values.is_empty():
		return "없음"
	var names := PackedStringArray()
	for value in values:
		names.append(String(value))
	return ", ".join(names)
