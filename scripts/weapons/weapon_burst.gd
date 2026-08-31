class_name WeaponBurst
extends Weapon

func fire(player: Player, target_pos: Vector2) -> bool:
	if not super.fire(player, target_pos):
		return false

	var dir := (target_pos - player.global_position).normalized()
	var shots := 3 + (1 if evolved else 0)
	var scaled_damage: float = data.damage + ((current_level - 1) * 3)
	if evolved:
		scaled_damage *= 1.15
	for i in range(shots):
		var bullet = ObjectPoolManager.acquire("bullet", player.global_position)
		if bullet:
			var offset: float = deg_to_rad(10.0) * (float(i) / maxf(1.0, float(shots - 1)) - 0.5)
			bullet.direction = dir.rotated(offset)
			bullet.damage = int(scaled_damage * player.damage_mult)
			bullet.pierce_count = player.pierce_add
	AudioManager.play_named("shotgun", -10.0, randf_range(1.08, 1.16))
	return true
