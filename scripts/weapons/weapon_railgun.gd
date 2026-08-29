class_name WeaponRailgun
extends Weapon

func fire(player: Player, target_pos: Vector2) -> bool:
	if not super.fire(player, target_pos):
		return false

	var bullet = ObjectPoolManager.acquire("bullet", player.global_position)
	if bullet:
		bullet.direction = (target_pos - player.global_position).normalized()
		var scaled_damage: float = data.damage + ((current_level - 1) * 12)
		if evolved:
			scaled_damage *= 1.5
		bullet.damage = int(scaled_damage * player.damage_mult)
		bullet.pierce_count = player.pierce_add + 3 + (2 if evolved else 0)
	AudioManager.play_named("impact", -5.0, randf_range(0.72, 0.86))
	return true
