class_name WeaponLightning
extends Weapon

const SKILL_TRACER_SCRIPT: Script = preload("res://scripts/effects/skill_tracer.gd")

@export var max_bounces: int = 3
@export var bounce_range: float = 300.0

func fire(player: Player, target_pos: Vector2) -> bool:
	if not super.fire(player, target_pos):
		return false

	# Lightning acts instantly on closest targets in a chain
	var enemies = SpatialGrid.get_nearby_entities(player.global_position, bounce_range)
	var valid_enemies = []
	for e in enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion() and e.is_in_group("enemies") and player.global_position.distance_to(e.global_position) <= bounce_range and e.get("is_dying") != true and e.get("health") != null and int(e.get("health")) > 0:
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
	var arc_points := PackedVector2Array([origin_pos])

	while hit_count < total_bounces and is_instance_valid(current_target):
		var hit_position: Vector2 = current_target.global_position
		if current_target.has_method("take_damage"):
			var dir = origin_pos.direction_to(hit_position)
			player.apply_build_hit(current_target, final_damage, dir, 0.1, "normal", data.weapon_name)
			arc_points.append(hit_position)

		hit_count += 1
		origin_pos = hit_position

		# Find next bounce target
		valid_enemies.erase(current_target)
		var next_target = null
		var min_dist = bounce_range
		for e in valid_enemies:
			if is_instance_valid(e) and not e.is_queued_for_deletion() and e.get("is_dying") != true and e.get("health") != null and int(e.get("health")) > 0:
				var d = origin_pos.distance_to(e.global_position)
				if d < min_dist:
					min_dist = d
					next_target = e

		if next_target:
			current_target = next_target
		else:
			break

	if arc_points.size() > 1:
		var arc := Line2D.new()
		arc.set_script(SKILL_TRACER_SCRIPT)
		var scene_root := get_tree().current_scene
		if not is_instance_valid(scene_root):
			return true
		scene_root.add_child(arc)
		arc.call("setup_arc", arc_points, Color(0.35, 0.95, 1.0, 1.0), 7.0, 0.22)

	AudioManager.play_named("lightning", -6.0, randf_range(0.95, 1.05))
	return true
