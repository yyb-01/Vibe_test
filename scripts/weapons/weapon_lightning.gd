class_name WeaponLightning
extends Weapon

@export var max_bounces: int = 3
@export var bounce_range: float = 300.0

func fire(player: Player, target_pos: Vector2) -> bool:
	if not super.fire(player, target_pos):
		return false

	# Lightning acts instantly on closest targets in a chain
	var enemies = SpatialGrid.get_nearby_entities(player.global_position)
	var valid_enemies = []
	for e in enemies:
		if is_instance_valid(e) and e.is_in_group("enemies"):
			valid_enemies.append(e)

	if valid_enemies.size() == 0:
		return true # Fired but hit nothing

	# Sort by distance
	valid_enemies.sort_custom(func(a, b): return player.global_position.distance_to(a.global_position) < player.global_position.distance_to(b.global_position))

	var current_target = valid_enemies[0]
	var hit_count = 0
	var total_bounces = max_bounces + player.pierce_add + (current_level - 1) + (2 if evolved else 0)
	var scaled_damage = data.damage + ((current_level - 1) * 10)
	if evolved:
		scaled_damage *= 1.25
	var final_damage = int(scaled_damage * player.damage_mult)

	var origin_pos = player.global_position

	while hit_count < total_bounces and is_instance_valid(current_target):
		if current_target.has_method("take_damage"):
			var dir = origin_pos.direction_to(current_target.global_position)
			current_target.take_damage(final_damage, dir)

		# Visual line (placeholder logic)
		# A real implementation would pool Line2D nodes and fade them out

		hit_count += 1
		origin_pos = current_target.global_position

		# Find next bounce target
		var next_target = null
		var min_dist = bounce_range
		for e in valid_enemies:
			if e != current_target and is_instance_valid(e):
				var d = origin_pos.distance_to(e.global_position)
				if d < min_dist:
					min_dist = d
					next_target = e

		if next_target:
			valid_enemies.erase(current_target) # Don't hit same target twice
			current_target = next_target
		else:
			break

	AudioManager.play_named("lightning", -6.0, randf_range(0.95, 1.05))
	return true
