class_name WeaponRailgun
extends Weapon

const SKILL_TRACER_SCRIPT: Script = preload("res://scripts/effects/skill_tracer.gd")

func fire(player: Player, target_pos: Vector2) -> bool:
	if not super.fire(player, target_pos):
		return false

	var muzzle_pos := player.get_muzzle_global_position()
	var direction := (target_pos - muzzle_pos).normalized()
	var bullet = ObjectPoolManager.acquire("bullet", muzzle_pos)
	if bullet:
		bullet.direction = direction
		var scaled_damage: float = data.damage + ((current_level - 1) * 12)
		if evolved:
			scaled_damage *= 1.5
		bullet.damage = int(scaled_damage * player.damage_mult)
		bullet.pierce_count = player.pierce_add + 3 + (2 if evolved else 0)
		bullet.critical_chance = 0.18
		bullet.impact_kind = "heavy"
		player.configure_projectile(bullet)
	var tracer := Line2D.new()
	tracer.set_script(SKILL_TRACER_SCRIPT)
	get_tree().current_scene.add_child(tracer)
	tracer.call("setup_arc", PackedVector2Array([muzzle_pos, muzzle_pos + direction * 980.0]), Color(0.3, 0.9, 1.0, 1.0), 9.0, 0.13)
	AudioManager.play_named("impact", -5.0, randf_range(0.72, 0.86))
	return true
