class_name Player
extends CharacterBody2D

const WALK_FRAME_A: Texture2D = preload("res://assets/graphics/player_walk_a_v4.png")
const WALK_FRAME_B: Texture2D = preload("res://assets/graphics/player_walk_b_v4.png")
const AIM_UP: Texture2D = preload("res://assets/graphics/player_aim_up_v1.png")
const AIM_DOWN: Texture2D = preload("res://assets/graphics/player_aim_down_v1.png")
const COMBAT_PET: PackedScene = preload("res://scenes/player/combat_pet.tscn")
const GUN_MOUNT_RIGHT := Vector2(38.0, -20.0)
const GUN_MOUNT_LEFT := Vector2(-38.0, 20.0)
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
var incoming_damage_mult: float = 1.0
var auto_fire_enabled: bool = true
var character_id: String = "scavenger"
var active_synergies: Array[String] = []
var walk_time: float = 0.0
var animation_time: float = 0.0
var gun_recoil: float = 0.0
var sprite_base_scale: Vector2
var sprite_base_position: Vector2
var aim_angle: float = 0.0
var facing: String = "right"
var invulnerable: bool = false
var skill_cooldown: float = 0.0
var skill_duration: float = 0.0
var skill_shield_duration: float = 0.0
var skill_restore: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var gun_pivot: Node2D = $GunPivot
@onready var gun_sprite: Sprite2D = $GunPivot/GunSprite
@onready var muzzle_anchor: Marker2D = $MuzzleAnchor

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
	_spawn_equipped_pet()

	if not EventBus.perk_selected.is_connected(apply_perk):
		EventBus.perk_selected.connect(apply_perk)

	# Delay emitting signals slightly so HUD is ready
	call_deferred("_update_ui")

func _spawn_equipped_pet() -> void:
	if RunStats.equipped_pet.is_empty():
		return
	var pet := COMBAT_PET.instantiate()
	pet.pet_id = RunStats.equipped_pet
	pet.owner_player = self
	pet.position = position
	get_parent().add_child(pet)

func _update_ui() -> void:
	EventBus.player_health_changed.emit(health, max_health)
	EventBus.exp_changed.emit(current_exp, required_exp, current_level)

func _physics_process(_delta: float) -> void:
	_update_unique_skill(_delta)
	_handle_movement()
	_handle_shooting()
	_animate_topdown_body(_delta)

func _animate_topdown_body(delta: float) -> void:
	var moving := velocity.length() > 8.0
	animation_time += delta
	var target_position := sprite_base_position
	var target_scale := sprite_base_scale
	_update_facing_from_aim()
	if moving:
		walk_time += delta * 9.5
		var frame_index := int(walk_time * 1.7) % 2
		sprite.texture = WALK_FRAME_A if frame_index == 0 else WALK_FRAME_B
		var stride := absf(sin(walk_time))
		target_position += Vector2(sin(walk_time * 0.5) * 1.2, -stride * 2.7)
	else:
		walk_time = lerpf(walk_time, 0.0, minf(delta * 8.0, 1.0))
		sprite.texture = WALK_FRAME_A
		var breath := sin(animation_time * 2.2)
		target_position += Vector2(0.0, -breath * 0.8)
	if facing == "up" or facing == "down":
		target_scale *= 0.86

	# The body never rotates with the cursor. It switches among dedicated poses,
	# while the muzzle keeps using the exact mouse direction for projectile aim.
	sprite.position = sprite.position.lerp(target_position, minf(delta * 16.0, 1.0))
	sprite.scale = sprite.scale.lerp(target_scale, minf(delta * 14.0, 1.0))
	sprite.rotation = 0.0
	_update_facing_pose(delta)
	gun_recoil = move_toward(gun_recoil, 0.0, delta * 48.0)

func get_muzzle_global_position() -> Vector2:
	return muzzle_anchor.global_position

func _update_facing_from_aim() -> void:
	var aim_direction := Vector2.RIGHT.rotated(aim_angle)
	if absf(aim_direction.y) > absf(aim_direction.x):
		facing = "up" if aim_direction.y < 0.0 else "down"
	else:
		facing = "left" if aim_direction.x < 0.0 else "right"

func _update_facing_pose(delta: float) -> void:
	var desired_gun_position := GUN_MOUNT_RIGHT
	var desired_gun_rotation := 0.0
	var muzzle_offset := Vector2(88.0, -35.0)
	gun_sprite.visible = true
	sprite.flip_h = false
	match facing:
		"left":
			sprite.texture = WALK_FRAME_A if velocity.length() <= 8.0 else sprite.texture
			sprite.flip_h = true
			desired_gun_position = GUN_MOUNT_LEFT
			desired_gun_rotation = PI
			muzzle_offset = Vector2(-88.0, -35.0)
		"up":
			sprite.texture = AIM_UP
			gun_sprite.visible = false
			desired_gun_position = Vector2.ZERO
			muzzle_offset = Vector2(0.0, -96.0)
		"down":
			sprite.texture = AIM_DOWN
			gun_sprite.visible = false
			desired_gun_position = Vector2.ZERO
			muzzle_offset = Vector2(0.0, 96.0)
		_:
			desired_gun_position = GUN_MOUNT_RIGHT
	gun_pivot.position = gun_pivot.position.lerp(desired_gun_position, minf(delta * 18.0, 1.0))
	gun_pivot.rotation = lerp_angle(gun_pivot.rotation, desired_gun_rotation, minf(delta * 18.0, 1.0))
	gun_pivot.position += Vector2(-gun_recoil, 0.0).rotated(gun_pivot.rotation)
	muzzle_anchor.position = muzzle_anchor.position.lerp(muzzle_offset + sprite.position, minf(delta * 22.0, 1.0))

func trigger_weapon_recoil(amount: float = 3.5) -> void:
	gun_recoil = maxf(gun_recoil, amount)

func _handle_movement() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * (move_speed * speed_mult)
	move_and_slide()

func _handle_shooting() -> void:
	# The rifle alone follows the full 360-degree mouse direction.
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
	if event.is_action_pressed("unique_skill"):
		use_unique_skill()

func add_weapon(weapon_script: Script, data: WeaponData) -> void:
	if weapons.size() >= max_weapons:
		return
	var w = weapon_script.new()
	w.data = data
	add_child(w)
	weapons.append(w)
	EventBus.inventory_updated.emit(weapons, passives)

func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if health <= 0 or invulnerable or skill_shield_duration > 0.0:
		return

	amount = maxi(1, int(ceil(float(amount) * incoming_damage_mult)))
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
		"bulwark":
			max_health += 60
			move_speed -= 20
			incoming_damage_mult *= 0.82
		"pyro":
			max_health -= 10
			damage_mult *= 1.15
		"engineer":
			max_health += 15
			reload_mult *= 0.88
		"reaper":
			max_health -= 20
			move_speed += 25
			damage_mult *= 1.22
		"chronomancer":
			move_speed += 15
			reload_mult *= 0.85
		_:
			max_health += 10
			damage_mult *= 1.08

func get_unique_skill_name() -> String:
	match character_id:
		"medic": return "응급 파동"
		"ranger": return "집중 사격"
		"bulwark": return "방벽 충격"
		"pyro": return "화염 폭발"
		"engineer": return "센트리 일제사격"
		"reaper": return "사신의 표식"
		"chronomancer": return "시간 붕괴"
		_: return "고철 폭탄"

func get_unique_skill_cooldown() -> float:
	return skill_cooldown

func use_unique_skill() -> bool:
	if skill_cooldown > 0.0 or health <= 0:
		return false
	match character_id:
		"medic":
			heal(38)
			_start_temporary_modifier("incoming", incoming_damage_mult, incoming_damage_mult * 0.65, 4.0)
			skill_cooldown = 18.0
		"ranger":
			_start_temporary_modifier("reload", reload_mult, reload_mult * 0.52, 6.0)
			skill_cooldown = 16.0
		"bulwark":
			_damage_enemies_in_radius(260.0, 26, 520.0)
			skill_shield_duration = 2.5
			skill_cooldown = 20.0
		"pyro":
			_damage_enemies_in_radius(340.0, 42, 180.0)
			skill_cooldown = 14.0
		"engineer":
			_attack_nearest_enemies(7, 24)
			skill_cooldown = 13.0
		"reaper":
			_execute_wounded_enemies(420.0)
			skill_cooldown = 15.0
		"chronomancer":
			_time_collapse(360.0)
			skill_cooldown = 19.0
		_:
			_damage_enemies_in_radius(285.0, 34, 300.0)
			RunStats.add_scrap(8)
			skill_cooldown = 15.0
	EventBus.camera_shake_requested.emit()
	AudioManager.play_named("level_up", -7.0, 1.08)
	return true

func _update_unique_skill(delta: float) -> void:
	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	skill_shield_duration = maxf(0.0, skill_shield_duration - delta)
	if skill_duration <= 0.0:
		return
	skill_duration = maxf(0.0, skill_duration - delta)
	if skill_duration <= 0.0:
		if skill_restore.has("reload"):
			reload_mult = float(skill_restore.reload)
		if skill_restore.has("incoming"):
			incoming_damage_mult = float(skill_restore.incoming)
		skill_restore.clear()

func _start_temporary_modifier(kind: String, original: float, boosted: float, duration: float) -> void:
	if not skill_restore.has(kind):
		skill_restore[kind] = original
	if kind == "reload":
		reload_mult = boosted
	elif kind == "incoming":
		incoming_damage_mult = boosted
	skill_duration = maxf(skill_duration, duration)

func _damage_enemies_in_radius(radius: float, base_damage: int, knockback_force: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= radius:
			var direction := global_position.direction_to(enemy.global_position)
			enemy.take_damage(int(float(base_damage) * damage_mult), direction)
			var current_knockback = enemy.get("knockback")
			if current_knockback is Vector2:
				enemy.set("knockback", current_knockback + direction * knockback_force)

func _attack_nearest_enemies(count: int, base_damage: int) -> void:
	var targets := get_tree().get_nodes_in_group("enemies")
	targets.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	for index in mini(count, targets.size()):
		var enemy = targets[index]
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(int(float(base_damage) * damage_mult), global_position.direction_to(enemy.global_position))

func _execute_wounded_enemies(radius: float) -> void:
	var executed := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or global_position.distance_to(enemy.global_position) > radius:
			continue
		var enemy_health := int(enemy.get("health"))
		var enemy_max_health := maxi(1, int(enemy.get("max_health")))
		var damage := enemy_health + 1 if float(enemy_health) / float(enemy_max_health) <= 0.35 else int(18.0 * damage_mult)
		enemy.take_damage(damage, global_position.direction_to(enemy.global_position))
		if damage > enemy_health:
			executed += 1
	if executed > 0:
		heal(executed * 6)

func _time_collapse(radius: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or global_position.distance_to(enemy.global_position) > radius:
			continue
		enemy.take_damage(int(20.0 * damage_mult), global_position.direction_to(enemy.global_position))
		var speed_value = enemy.get("move_speed")
		if speed_value != null:
			var original_speed := float(speed_value)
			enemy.set("move_speed", original_speed * 0.38)
			get_tree().create_timer(4.0).timeout.connect(_restore_enemy_speed.bind(enemy, original_speed))

func _restore_enemy_speed(enemy: Node, original_speed: float) -> void:
	if is_instance_valid(enemy):
		enemy.set("move_speed", original_speed)

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
