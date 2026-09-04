class_name ContentCatalog
extends Node

const StructureDefinitionClass = preload("res://game/content/definitions/structure_definition.gd")

var catalog_hash: String = ""
var is_built: bool = false
var _definitions: Dictionary = {}

func build(manifest: ContentManifest) -> bool:
	_definitions.clear()
	catalog_hash = ""
	is_built = false
	if manifest == null or manifest.definitions == null:
		return false

	var signature := PackedStringArray()
	for definition_value in manifest.all_definitions():
		var definition := definition_value as ContentDefinition
		if definition == null:
			return false
		var id := StringName(definition.id)
		if String(id).is_empty() or _definitions.has(id):
			return false
		_definitions[id] = definition
		var item := definition as ItemDefinition
		if item != null:
			signature.append("item:%s:%d" % [String(id), item.max_stack])
			continue
		var terrain := definition as TerrainDefinition
		if terrain != null:
			signature.append("terrain:%s:%s:%s" % [String(id), terrain.walkable, terrain.buildable])
			continue
		var operation := definition as OperationDefinition
		if operation != null:
			signature.append("operation:%s:%s" % [String(id), str([operation.seed, operation.terrain_id, operation.map_size, operation.player_spawn, operation.core_position, operation.player_speed, operation.player_pack_capacity, operation.core_storage_capacity, operation.core_max_health, operation.enemy_definition_id, operation.enemy_spawn_cell, operation.enemy_spawn_entries, operation.enemy_spawn_waves, operation.objective_id, operation.objective_fact_type, operation.objective_item_id, operation.objective_amount, operation.threat_fact_types, operation.threat_pressure_per_action, operation.threat_pressure_threshold, operation.threat_event_duration_ticks, operation.pickup_entries])])
			continue
		var enemy := definition as EnemyDefinition
		if enemy != null:
			signature.append("enemy:%s:%s:%d:%d:%d:%s:%d" % [String(id), String(enemy.presentation_id), enemy.max_health, enemy.attack_damage, enemy.attack_cooldown_ticks, String(enemy.drop_item_id), enemy.drop_amount])
			continue
		var structure = definition if definition.get_script() == StructureDefinitionClass else null
		if structure != null:
			signature.append("structure:%s:%s:%s:%s:%s:%s:%d:%d" % [String(id), str(structure.footprint), str(structure.occupied_channels), String(structure.connection_group), str(structure.compatible_groups), String(structure.cost_item_id), structure.cost_amount, structure.max_health])
			continue
		return false
	signature.sort()
	catalog_hash = str("\n".join(signature).hash())
	is_built = true
	return true

func has_definition(id: StringName) -> bool:
	return _definitions.has(id)

func get_definition(id: StringName) -> ContentDefinition:
	return _definitions.get(id) as ContentDefinition

func all_definitions() -> Array:
	return _definitions.values()

func definition_count() -> int:
	return _definitions.size()
