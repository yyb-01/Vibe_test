class_name WeaponShotgun
extends Weapon

@export var pellet_count: int = 3
@export var spread_angle: float = 30.0 # Degrees

func fire(player: Player, target_pos: Vector2) -> bool:
	if not super.fire(player, target_pos):
		return false

	var dir := (target_pos - player.global_position).normalized()
	var actual_pellets = pellet_count + (current_level - 1) + (2 if evolved else 0)
	var scaled_damage = data.damage + ((current_level - 1) * 3)
	if evolved:
		scaled_damage *= 1.2

	for i in range(actual_pellets):
		var bullet = ObjectPoolManager.acquire("bullet", player.global_position)
		if bullet:
			var angle_offset = deg_to_rad(spread_angle) * (float(i) / max(1, actual_pellets - 1) - 0.5)
			if actual_pellets == 1: angle_offset = 0
			bullet.direction = dir.rotated(angle_offset)
			bullet.damage = int(scaled_damage * player.damage_mult)
			bullet.pierce_count = player.pierce_add

	AudioManager.play_named("shotgun", -7.0, randf_range(0.92, 1.02))
	return true
