class_name Player
extends CharacterBody2D

@export var max_health: int = 100
@export var move_speed: float = 200.0
@export var invulnerability_duration: float = 0.35
var weapons: Array[Weapon] = []
var max_weapons: int = 6
var passives: Array[PerkData] = []
var max_passives: int = 6

var health: int
var current_exp: int = 0
var required_exp: int = 50
var current_level: int = 1

# Perk Multipliers
var damage_mult: float = 1.0
var speed_mult: float = 1.0
var reload_mult: float = 1.0
var pierce_add: int = 0
var auto_fire_enabled: bool = true
var character_id: String = "scavenger"
var active_synergies: Array[String] = []
var walk_time: float = 0.0
var animation_time: float = 0.0
var gun_recoil: float = 0.0
var sprite_base_scale: Vector2
var sprite_base_position: Vector2
var aim_angle: float = 0.0
var invulnerable: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Marker2D = $Sprite2D/Muzzle

func _ready() -> void:
	sprite_base_scale = sprite.scale
	sprite_base_position = sprite.position
	if sprite.material:
		sprite.material = sprite.material.duplicate()
	character_id = SaveManager.selected_character
	_apply_character_preset()
	if not RunStats.run_active:
		var scene_root := get_tree().current_scene
		if not is_instance_valid(scene_root):
			scene_root = get_parent()
		var scene_path: String = scene_root.scene_file_path if is_instance_valid(scene_root) else "map_1"
		RunStats.start_run(scene_path.get_file().get_basename())

	# Initialize default starting weapon
	var starting_weap_data = preload("res://data/perks/weap_pistol.tres")
	add_weapon(starting_weap_data.weapon_script, starting_weap_data.weapon_data)

	# Apply meta-progression
	max_health += SaveManager.upgrade_max_hp * 20
	damage_mult += SaveManager.upgrade_damage * 0.1
	speed_mult += SaveManager.upgrade_speed * 0.05

	health = max_health

	if not EventBus.perk_selected.is_connected(apply_perk):
		EventBus.perk_selected.connect(apply_perk)

	# Delay emitting signals slightly so HUD is ready
	call_deferred("_update_ui")

func _update_ui() -> void:
	EventBus.player_health_changed.emit(health, max_health)
	EventBus.exp_changed.emit(current_exp, required_exp, current_level)

func _physics_process(_delta: float) -> void:
	_handle_movement()
	_handle_shooting()
	_animate_topdown_body(_delta)

func _animate_topdown_body(delta: float) -> void:
	var moving := velocity.length() > 8.0
	animation_time += delta
	var target_position := sprite_base_position
	var target_scale := sprite_base_scale
	if moving:
		walk_time += delta * 11.5
		var step := sin(walk_time)
		var stride := absf(step)
		# A deliberately visible walk cycle: the complete armed character rises
		# and settles with each step, while its rifle remains locked in both hands.
		target_position += Vector2(-gun_recoil, -stride * 4.6).rotated(aim_angle)
		target_scale = sprite_base_scale * Vector2(1.0 + stride * 0.055, 1.0 - stride * 0.045)
	else:
		walk_time = lerpf(walk_time, 0.0, minf(delta * 8.0, 1.0))
		var breath := sin(animation_time * 2.2)
		target_position += Vector2(-gun_recoil, -breath * 1.4).rotated(aim_angle)
		target_scale = sprite_base_scale * Vector2(1.0 - breath * 0.014, 1.0 + breath * 0.014)

	# The whole survivor faces the aim direction because the gun is painted in
	# their hands. Physics and camera remain upright, and the muzzle marker is
	# a child of this sprite so firing direction cannot drift away from the rifle.
	sprite.position = sprite.position.lerp(target_position, minf(delta * 16.0, 1.0))
	sprite.scale = sprite.scale.lerp(target_scale, minf(delta * 14.0, 1.0))
	sprite.rotation = lerp_angle(sprite.rotation, aim_angle, minf(delta * 20.0, 1.0))
	gun_recoil = move_toward(gun_recoil, 0.0, delta * 48.0)

func get_muzzle_global_position() -> Vector2:
	return muzzle.global_position

func trigger_weapon_recoil(amount: float = 3.5) -> void:
	gun_recoil = maxf(gun_recoil, amount)

func _handle_movement() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * (move_speed * speed_mult)
	move_and_slide()

func _handle_shooting() -> void:
	# The armed survivor art faces local +X and rotates as one natural pose.
	var target_pos := get_global_mouse_position()
	if not target_pos.is_equal_approx(global_position):
		aim_angle = global_position.angle_to_point(target_pos)
	if not auto_fire_enabled and not Input.is_action_pressed("shoot"):
		return

	# Iterate over all weapons and attempt to fire
	for weapon in weapons:
		weapon.fire(self, target_pos)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_auto_fire"):
		auto_fire_enabled = not auto_fire_enabled
	if event.is_action_pressed("reload"):
		for weapon in weapons:
			weapon.reload(self)

func add_weapon(weapon_script: Script, data: WeaponData) -> void:
	if weapons.size() >= max_weapons:
		return
	var w = weapon_script.new()
	w.data = data
	add_child(w)
	weapons.append(w)
	EventBus.inventory_updated.emit(weapons, passives)

func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if health <= 0 or invulnerable:
		return

	invulnerable = true
	health -= amount
	RunStats.register_damage(amount)
	EventBus.camera_shake_requested.emit()
	EventBus.player_health_changed.emit(health, max_health)
	_play_hit_feedback(hit_direction)
	AudioManager.play_named("hurt", -4.0)
	var invulnerability_timer := get_tree().create_timer(invulnerability_duration)
	invulnerability_timer.timeout.connect(func() -> void: invulnerable = false)

	if health <= 0:
		die()

func _play_hit_feedback(hit_direction: Vector2) -> void:
	var impact = ObjectPoolManager.acquire("player_hit", global_position)
	if impact and hit_direction != Vector2.ZERO:
		impact.rotation = hit_direction.angle()

	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("flash_color", Color(1.0, 0.3, 0.2, 1.0))
		sprite.material.set_shader_parameter("active", true)
		var timer := get_tree().create_timer(0.09)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(sprite) and sprite.material is ShaderMaterial:
				sprite.material.set_shader_parameter("active", false)
		)

func die() -> void:
	set_physics_process(false)
	EventBus.game_over.emit(false)

func heal(amount: int) -> void:
	health += amount
	if health > max_health:
		health = max_health
	EventBus.player_health_changed.emit(health, max_health)
	print("Player healed! Health: ", health)

func add_exp(amount: int) -> void:
	current_exp += amount
	while current_exp >= required_exp:
		_level_up()
	EventBus.exp_changed.emit(current_exp, required_exp, current_level)

func _level_up() -> void:
	current_level += 1
	current_exp -= required_exp
	required_exp = int(float(required_exp) * 1.2) # Exponential exp curve

	EventBus.level_up.emit()
	EventBus.exp_changed.emit(current_exp, required_exp, current_level)

func apply_perk(perk: PerkData) -> void:
	if passives.size() >= max_passives:
		return
	for owned_perk in passives:
		if owned_perk.id == perk.id:
			return
	print("Applying perk: ", perk.perk_name)
	passives.append(perk)
	damage_mult *= perk.damage_mult
	speed_mult *= perk.speed_mult
	reload_mult *= perk.reload_speed_mult
	pierce_add += perk.pierce_add
	_check_synergies()

	if perk.max_hp_add > 0:
		max_health += perk.max_hp_add
		health += perk.max_hp_add
		EventBus.player_health_changed.emit(health, max_health)

	EventBus.inventory_updated.emit(weapons, passives)

func _apply_character_preset() -> void:
	match character_id:
		"medic":
			max_health += 35
			damage_mult *= 0.9
		"ranger":
			move_speed += 35
			damage_mult *= 1.1
			reload_mult *= 0.9
		_:
			max_health += 10
			damage_mult *= 1.08

func _check_synergies() -> void:
	var perk_ids: Array[String] = []
	for perk in passives:
		perk_ids.append(perk.id)

	if "heavy_caliber" in perk_ids and "piercing_rounds" in perk_ids and not "armor_breaker" in active_synergies:
		active_synergies.append("armor_breaker")
		damage_mult *= 1.15
		pierce_add += 1
	if "fast_hands" in perk_ids and "light_foot" in perk_ids and not "combat_medic" in active_synergies:
		active_synergies.append("combat_medic")
		reload_mult *= 0.85
		max_health += 15
		health += 15
