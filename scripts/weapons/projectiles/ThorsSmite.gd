class_name ThorsSmite
extends Node2D

const STRIKE: PackedScene = preload("res://scenes/weapons/advanced/lightning_strike.tscn")
const BEAM: PackedScene = preload("res://scenes/weapons/advanced/electric_beam.tscn")

func on_spawn(init_source: Node = null, init_damage: float = 1.0, target_count: int = 5,
		extras: Dictionary = {}) -> void:
	activate(init_source, init_damage, target_count, String(extras.get("weapon_id", "thors_smite")))
	ObjectPoolManager.despawn(self)

func activate(init_source: Node, init_damage: float, target_count: int = 5,
		weapon_id: String = "thors_smite") -> void:
	var candidates: Array[Node2D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node2D and _is_visible_live_enemy(enemy as Node2D):
			candidates.append(enemy as Node2D)
	candidates.shuffle()
	var selected: Array[Node2D] = []
	for index in mini(maxi(1, target_count), candidates.size()):
		selected.append(candidates[index])
	var selected_positions: Array[Vector2] = []
	var selected_targets: Array[Node2D] = []
	for enemy in selected:
		if not is_instance_valid(enemy):
			continue
		var strike_position := enemy.global_position
		selected_positions.append(strike_position)
		selected_targets.append(enemy)
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", maxi(1, roundi(init_damage)), Vector2.ZERO, "lightning", weapon_id)
		ObjectPoolManager.spawn(STRIKE, strike_position, 0.0,
			[strike_position, 0.3, Color(0.5, 0.82, 1.0, 1.0)])
	for i in selected_positions.size():
		for j in range(i + 1, selected_positions.size()):
			if selected_positions[i].distance_to(selected_positions[j]) > 200.0:
				continue
			var from := selected_positions[i]
			var to := selected_positions[j]
			var target := selected_targets[j] if is_instance_valid(selected_targets[j]) else null
			ObjectPoolManager.spawn(BEAM, from, 0.0,
				[from, to, 1.0, init_damage * 0.15, target, init_source])

func _is_visible_live_enemy(enemy: Node2D) -> bool:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return false
	var health = enemy.get("health")
	if health == null or int(health) <= 0 or bool(enemy.get("is_dying")):
		return false
	var viewport := get_viewport()
	if viewport == null:
		return true
	var screen_position: Vector2 = viewport.get_canvas_transform() * enemy.global_position
	return viewport.get_visible_rect().has_point(screen_position)

func on_despawn() -> void:
	set_process(false)
	set_physics_process(false)
