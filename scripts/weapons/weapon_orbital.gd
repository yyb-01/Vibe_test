class_name WeaponOrbital
extends Weapon

const SHIELD_TEXTURE := preload("res://assets/graphics/orbital_shield_v3.png")

var orbitals: Array[Area2D] = []
var angle: float = 0.0
@export var rotation_speed: float = PI

func _ready() -> void:
	_update_orbitals()

func upgrade() -> void:
	super.upgrade()
	_update_orbitals()

func _update_orbitals() -> void:
	# Clear old
	for o in orbitals:
		if is_instance_valid(o):
			o.queue_free()
	orbitals.clear()

	# Create new based on level (1 orbital per level)
	var count = current_level
	var parent_player = get_parent()
	if not parent_player is Player: return

	for i in range(count):
		var area = Area2D.new()
		area.collision_layer = 8
		area.collision_mask = 4 # Enemies
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 24.0
		shape.shape = circle
		area.add_child(shape)

		# Dedicated shield-drone art replaces the old debug-colored square.
		var shield_sprite := Sprite2D.new()
		shield_sprite.name = "ShieldSprite"
		shield_sprite.texture = SHIELD_TEXTURE
		shield_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shield_sprite.scale = Vector2.ONE * 0.05
		shield_sprite.z_index = 9
		area.add_child(shield_sprite)

		# Add to the global scene tree rather than the player, to prevent tree traversal/hierarchy crashes
		get_tree().current_scene.call_deferred("add_child", area)
		orbitals.append(area)

func _process(delta: float) -> void:
	super._process(delta)
	angle += rotation_speed * delta
	var player = get_parent() as Player
	if not player: return

	var radius = 100.0 + (current_level * 5.0) + (30.0 if evolved else 0.0)
	var scaled_damage = data.damage + (current_level * 5)
	if evolved:
		scaled_damage *= 1.4
	var final_damage = int(scaled_damage * player.damage_mult)

	for i in range(orbitals.size()):
		var o = orbitals[i]
		if is_instance_valid(o):
			var a = angle + (i * TAU / orbitals.size())
			# Sync to global position instead of relying on local player offset
			o.global_position = player.global_position + Vector2(cos(a), sin(a)) * radius
			var shield_sprite := o.get_node_or_null("ShieldSprite") as Sprite2D
			if shield_sprite:
				var energy_pulse := sin(Time.get_ticks_msec() * 0.008 + i * 1.7)
				shield_sprite.rotation += delta * 2.4
				shield_sprite.scale = Vector2.ONE * (0.05 + energy_pulse * 0.004)
				shield_sprite.modulate = Color(0.82, 1.0, 1.0, 0.92 + energy_pulse * 0.08)

			if cooldown_timer <= 0:
				var bodies = o.get_overlapping_bodies()
				var hit = false
				for body in bodies:
					if body.is_in_group("enemies") and body.has_method("take_damage"):
						var dir = player.global_position.direction_to(body.global_position)
						player.apply_build_hit(body, final_damage, dir, 0.04, "heavy" if evolved else "normal", data.weapon_name)
						hit = true
				if hit:
					cooldown_timer = data.fire_rate * player.reload_mult
					AudioManager.play_named("impact", -10.0, randf_range(0.95, 1.05))

func fire(_player: Player, _target_pos: Vector2) -> bool:
	return false # Orbital fires automatically via _process overlap checks
