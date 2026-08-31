class_name WeaponPistol
extends Weapon

func fire(player: Player, target_pos: Vector2) -> bool:
	if not super.fire(player, target_pos):
		return false

	var muzzle_pos := player.get_muzzle_global_position()
	var bullet = ObjectPoolManager.acquire("bullet", muzzle_pos)
	if bullet:
		var dir := (target_pos - muzzle_pos).normalized()
		bullet.direction = dir
		# Level scaling logic: base damage + 5 per level
		var scaled_damage = data.damage + ((current_level - 1) * 5)
		if evolved:
			scaled_damage *= 1.35
		bullet.damage = int(scaled_damage * player.damage_mult)
		bullet.pierce_count = player.pierce_add + (1 if evolved else 0)
		AudioManager.play_named("shot", -8.0, randf_range(0.94, 1.06))
	return true
