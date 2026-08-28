class_name WeaponPistol
extends Weapon

func fire(player: Player, target_pos: Vector2) -> bool:
	if not super.fire(player, target_pos):
		return false

	var bullet = ObjectPoolManager.acquire("bullet", player.global_position)
	if bullet:
		var dir := (target_pos - player.global_position).normalized()
		bullet.direction = dir
		# Level scaling logic: base damage + 5 per level
		var scaled_damage = data.damage + ((current_level - 1) * 5)
		bullet.damage = int(scaled_damage * player.damage_mult)
		bullet.pierce_count = player.pierce_add
		AudioManager.play_sfx(null) # Placeholder
	return true
