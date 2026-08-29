class_name WeaponSMG
extends Weapon

func fire(player: Player, target_pos: Vector2) -> bool:
	if not super.fire(player, target_pos):
		return false

	var bullet = ObjectPoolManager.acquire("bullet", player.global_position)
	if bullet:
		var dir := (target_pos - player.global_position).normalized()
		bullet.direction = dir.rotated(randf_range(-0.035, 0.035))
		var scaled_damage: float = data.damage + ((current_level - 1) * 2)
		if evolved:
			scaled_damage *= 1.25
		bullet.damage = int(scaled_damage * player.damage_mult)
		bullet.pierce_count = player.pierce_add + (1 if evolved else 0)
	AudioManager.play_named("shot", -11.0, randf_range(1.08, 1.18))
	return true
