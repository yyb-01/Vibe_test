class_name ContentValidator
extends RefCounted

const StructureDefinitionClass = preload("res://game/content/definitions/structure_definition.gd")

func validate(manifest: ContentManifest) -> PackedStringArray:
	var errors := PackedStringArray()
	if manifest == null:
		errors.append("MANIFEST_MISSING")
		return errors
	if manifest.definitions == null or manifest.definitions.is_empty():
		errors.append("MANIFEST_EMPTY")

	var definitions_by_id: Dictionary = {}
	var item_count := 0
	var terrain_count := 0
	var operation_count := 0
	var structure_count := 0
	var enemy_count := 0
	for index in range(manifest.definitions.size()):
		var definition := manifest.definitions[index] as ContentDefinition
		if definition == null:
			errors.append("DEFINITION_INVALID:%d" % index)
			continue
		var id := StringName(definition.id)
		if String(id).is_empty():
			errors.append("DEFINITION_ID_MISSING:%d" % index)
		elif definitions_by_id.has(id):
			errors.append("DEFINITION_ID_DUPLICATE:%s" % String(id))
		else:
			definitions_by_id[id] = definition
		var item := definition as ItemDefinition
		if item != null and item.max_stack < 1:
			errors.append("ITEM_STACK_INVALID:%s" % String(id))
		if item != null:
			item_count += 1
		var terrain := definition as TerrainDefinition
		if terrain != null:
			terrain_count += 1
		var operation := definition as OperationDefinition
		if operation != null:
			operation_count += 1
		var enemy := definition as EnemyDefinition
		if enemy != null:
			enemy_count += 1
		var structure = definition if definition.get_script() == StructureDefinitionClass else null
		if structure != null:
			structure_count += 1
		if item == null and terrain == null and operation == null and structure == null and enemy == null:
			errors.append("DEFINITION_TYPE_INVALID:%d" % index)

	if item_count == 0:
		errors.append("ITEM_DEFINITION_MISSING")
	if terrain_count == 0:
		errors.append("TERRAIN_DEFINITION_MISSING")
	if operation_count == 0:
		errors.append("OPERATION_DEFINITION_MISSING")
	if structure_count == 0:
		errors.append("STRUCTURE_DEFINITION_MISSING")
	if enemy_count == 0:
		errors.append("ENEMY_DEFINITION_MISSING")

	for definition in manifest.definitions:
		var enemy := definition as EnemyDefinition
		if enemy == null:
			continue
		if String(enemy.presentation_id).is_empty():
			errors.append("ENEMY_PRESENTATION_ID_MISSING:%s" % String(enemy.id))
		if enemy.max_health <= 0:
			errors.append("ENEMY_HEALTH_INVALID:%s" % String(enemy.id))
		if enemy.attack_damage <= 0 or enemy.attack_cooldown_ticks <= 0:
			errors.append("ENEMY_ATTACK_INVALID:%s" % String(enemy.id))
		if enemy.drop_amount > 0:
			var drop_item := definitions_by_id.get(StringName(enemy.drop_item_id)) as ItemDefinition
			if drop_item == null:
				errors.append("ENEMY_DROP_ITEM_MISSING:%s" % String(enemy.id))

	for definition in manifest.definitions:
		var structure = definition if definition.get_script() == StructureDefinitionClass else null
		if structure == null:
			continue
		if structure.footprint.is_empty():
			errors.append("STRUCTURE_FOOTPRINT_EMPTY:%s" % String(structure.id))
		elif not structure.footprint.has(Vector2i.ZERO):
			errors.append("STRUCTURE_ANCHOR_MISSING:%s" % String(structure.id))
		if structure.occupied_channels.is_empty():
			errors.append("STRUCTURE_CHANNELS_MISSING:%s" % String(structure.id))
		if String(structure.connection_group).is_empty():
			errors.append("STRUCTURE_CONNECTION_GROUP_MISSING:%s" % String(structure.id))
		if structure.cost_amount <= 0:
			errors.append("STRUCTURE_COST_INVALID:%s" % String(structure.id))
		if structure.max_health <= 0:
			errors.append("STRUCTURE_HEALTH_INVALID:%s" % String(structure.id))
		var cost_item := StringName(structure.cost_item_id)
		if not definitions_by_id.has(cost_item) or not (definitions_by_id[cost_item] is ItemDefinition):
			errors.append("STRUCTURE_COST_ITEM_MISSING:%s" % String(cost_item))

	for definition in manifest.definitions:
		var operation := definition as OperationDefinition
		if operation == null:
			continue
		var terrain_id := StringName(operation.terrain_id)
		if not definitions_by_id.has(terrain_id) or not (definitions_by_id[terrain_id] is TerrainDefinition):
			errors.append("OPERATION_TERRAIN_MISSING:%s" % String(terrain_id))
		if operation.map_size.x <= 0.0 or operation.map_size.y <= 0.0:
			errors.append("OPERATION_MAP_SIZE_INVALID:%s" % String(operation.id))
		if operation.player_speed <= 0.0:
			errors.append("OPERATION_PLAYER_SPEED_INVALID:%s" % String(operation.id))
		if operation.player_pack_capacity <= 0:
			errors.append("OPERATION_PACK_CAPACITY_INVALID:%s" % String(operation.id))
		if operation.core_storage_capacity <= 0:
			errors.append("OPERATION_CORE_CAPACITY_INVALID:%s" % String(operation.id))
		if operation.core_max_health <= 0:
			errors.append("OPERATION_CORE_HEALTH_INVALID:%s" % String(operation.id))
		var enemy_definition := definitions_by_id.get(StringName(operation.enemy_definition_id)) as EnemyDefinition
		if enemy_definition == null:
			errors.append("OPERATION_ENEMY_DEFINITION_MISSING:%s" % String(operation.enemy_definition_id))
		var half_width := int(ceil(operation.map_size.x / 32.0)) / 2
		var half_height := int(ceil(operation.map_size.y / 32.0)) / 2
		var enemy_ids: Dictionary = {}
		if operation.enemy_spawn_entries.is_empty():
			enemy_ids[&"enemy_01"] = true
			if operation.enemy_spawn_cell.x < -half_width or operation.enemy_spawn_cell.x >= half_width or operation.enemy_spawn_cell.y < -half_height or operation.enemy_spawn_cell.y >= half_height:
				errors.append("OPERATION_ENEMY_SPAWN_OUT_OF_BOUNDS:%s" % String(operation.id))
		else:
			for spawn_value in operation.enemy_spawn_entries:
				if typeof(spawn_value) != TYPE_DICTIONARY:
					errors.append("OPERATION_ENEMY_SPAWN_INVALID:%s" % String(operation.id))
					continue
				var spawn_entry: Dictionary = spawn_value
				var spawn_id := StringName(spawn_entry.get("id", ""))
				var spawn_definition_id := StringName(spawn_entry.get("definition_id", ""))
				var spawn_cell: Vector2i = spawn_entry.get("spawn_cell", Vector2i.ZERO)
				if String(spawn_id).is_empty() or enemy_ids.has(spawn_id):
					errors.append("OPERATION_ENEMY_SPAWN_ID_INVALID:%s" % String(operation.id))
				else:
					enemy_ids[spawn_id] = true
				var spawn_enemy := definitions_by_id.get(spawn_definition_id) as EnemyDefinition
				if spawn_enemy == null:
					errors.append("OPERATION_ENEMY_SPAWN_DEFINITION_MISSING:%s" % String(spawn_definition_id))
				if spawn_cell.x < -half_width or spawn_cell.x >= half_width or spawn_cell.y < -half_height or spawn_cell.y >= half_height:
					errors.append("OPERATION_ENEMY_SPAWN_OUT_OF_BOUNDS:%s" % String(operation.id))
		var wave_ids: Dictionary = {}
		for wave_value in operation.enemy_spawn_waves:
			if typeof(wave_value) != TYPE_DICTIONARY:
				errors.append("OPERATION_WAVE_INVALID:%s" % String(operation.id))
				continue
			var wave: Dictionary = wave_value
			var wave_id := StringName(wave.get("id", ""))
			var pressure_tier := int(wave.get("pressure_tier", 0))
			if String(wave_id).is_empty() or wave_ids.has(wave_id):
				errors.append("OPERATION_WAVE_ID_INVALID:%s" % String(operation.id))
			else:
				wave_ids[wave_id] = true
			if pressure_tier <= 0:
				errors.append("OPERATION_WAVE_TIER_INVALID:%s" % String(operation.id))
			var wave_entries = wave.get("spawn_entries", [])
			if typeof(wave_entries) != TYPE_ARRAY or wave_entries.is_empty():
				errors.append("OPERATION_WAVE_ENTRIES_MISSING:%s" % String(operation.id))
				continue
			for spawn_value in wave_entries:
				if typeof(spawn_value) != TYPE_DICTIONARY:
					errors.append("OPERATION_WAVE_SPAWN_INVALID:%s" % String(operation.id))
					continue
				var spawn_entry: Dictionary = spawn_value
				var spawn_id := StringName(spawn_entry.get("id", ""))
				var spawn_definition_id := StringName(spawn_entry.get("definition_id", ""))
				var spawn_cell: Vector2i = spawn_entry.get("spawn_cell", Vector2i.ZERO)
				if String(spawn_id).is_empty() or enemy_ids.has(spawn_id):
					errors.append("OPERATION_WAVE_SPAWN_ID_INVALID:%s" % String(operation.id))
				else:
					enemy_ids[spawn_id] = true
				var spawn_enemy := definitions_by_id.get(spawn_definition_id) as EnemyDefinition
				if spawn_enemy == null:
					errors.append("OPERATION_WAVE_SPAWN_DEFINITION_MISSING:%s" % String(spawn_definition_id))
				if spawn_cell.x < -half_width or spawn_cell.x >= half_width or spawn_cell.y < -half_height or spawn_cell.y >= half_height:
					errors.append("OPERATION_WAVE_SPAWN_OUT_OF_BOUNDS:%s" % String(operation.id))
		if String(operation.objective_id).is_empty():
			errors.append("OPERATION_OBJECTIVE_ID_MISSING:%s" % String(operation.id))
		if operation.objective_fact_type != &"ITEM_SECURED":
			errors.append("OPERATION_OBJECTIVE_FACT_UNSUPPORTED:%s" % String(operation.id))
		if operation.objective_amount <= 0:
			errors.append("OPERATION_OBJECTIVE_AMOUNT_INVALID:%s" % String(operation.id))
		var objective_item := definitions_by_id.get(StringName(operation.objective_item_id)) as ItemDefinition
		if objective_item == null:
			errors.append("OPERATION_OBJECTIVE_ITEM_MISSING:%s" % String(operation.id))
		if operation.threat_fact_types.is_empty():
			errors.append("OPERATION_THREAT_FACTS_MISSING:%s" % String(operation.id))
		if operation.threat_pressure_per_action <= 0 or operation.threat_pressure_threshold <= 0 or operation.threat_event_duration_ticks <= 0:
			errors.append("OPERATION_THREAT_POLICY_INVALID:%s" % String(operation.id))
		if operation.pickup_entries.is_empty():
			errors.append("OPERATION_PICKUPS_MISSING:%s" % String(operation.id))
		var pickup_ids: Dictionary = {}
		for pickup_value in operation.pickup_entries:
			if typeof(pickup_value) != TYPE_DICTIONARY:
				errors.append("OPERATION_PICKUP_INVALID:%s" % String(operation.id))
				continue
			var pickup_id := StringName(pickup_value.get("id", ""))
			var pickup_item_id := StringName(pickup_value.get("item_id", ""))
			var pickup_amount := int(pickup_value.get("amount", 0))
			if String(pickup_id).is_empty() or pickup_ids.has(pickup_id):
				errors.append("OPERATION_PICKUP_ID_INVALID:%s" % String(operation.id))
			else:
				pickup_ids[pickup_id] = true
			var pickup_item := definitions_by_id.get(pickup_item_id) as ItemDefinition
			if pickup_item == null:
				errors.append("OPERATION_PICKUP_ITEM_MISSING:%s" % String(pickup_item_id))
			elif pickup_amount <= 0 or pickup_amount > pickup_item.max_stack:
				errors.append("OPERATION_PICKUP_STACK_INVALID:%s" % String(operation.id))
		for item_id_value in operation.starting_item_ids:
			var item_id := StringName(item_id_value)
			if not definitions_by_id.has(item_id) or not (definitions_by_id[item_id] is ItemDefinition):
				errors.append("OPERATION_ITEM_MISSING:%s" % String(item_id))

	return errors
