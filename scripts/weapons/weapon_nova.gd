class_name WeaponNova
extends Weapon

@export var projectile_count: int = 12

func fire(player: Player, _target_pos: Vector2) -> bool:
	if not super.fire(player, _target_pos):
		return false

	var count := projectile_count + (current_level - 1) * 2 + (4 if evolved else 0)
	var scaled_damage: float = data.damage + ((current_level - 1) * 4)
	if evolved:
		scaled_damage *= 1.3
	for i in range(count):
		var bullet = ObjectPoolManager.acquire("bullet", player.global_position)
		if bullet:
			bullet.direction = Vector2.RIGHT.rotated(TAU * float(i) / float(count))
			bullet.damage = int(scaled_damage * player.damage_mult)
			bullet.pierce_count = player.pierce_add + (1 if evolved else 0)
			player.configure_projectile(bullet)
	var impact = ObjectPoolManager.acquire("blood_impact", player.global_position)
	if impact and impact.has_method("configure"):
		impact.configure(Color(0.25, 0.9, 1.0, 1.0), 96.0 if evolved else 76.0)
	AudioManager.play_named("impact", -5.0, randf_range(0.82, 0.96))
	return true
