class_name Player
extends CharacterBody2D

const CHARACTER_SHEETS := {
	"scavenger": preload("res://assets/graphics/animated/player_scavenger_sheet_v1.png"),
	"medic": preload("res://assets/graphics/animated/player_medic_sheet_v1.png"),
	"ranger": preload("res://assets/graphics/animated/player_ranger_sheet_v1.png"),
	"bulwark": preload("res://assets/graphics/animated/player_bulwark_sheet_v1.png"),
	"pyro": preload("res://assets/graphics/animated/player_pyro_sheet_v1.png"),
	"engineer": preload("res://assets/graphics/animated/player_engineer_sheet_v1.png"),
	"reaper": preload("res://assets/graphics/animated/player_reaper_sheet_v1.png"),
	"chronomancer": preload("res://assets/graphics/animated/player_chronomancer_sheet_v1.png")
}
# The generated sheets have slightly different occupied bounds even after their
# frame widths are normalized. Keep the cast visually consistent while letting
# the heavy and supernatural silhouettes read a little larger.
const CHARACTER_VISUAL_SCALE := {
	"scavenger": 1.0,
	"medic": 1.0,
	"ranger": 1.0,
	"bulwark": 1.15,
	"pyro": 0.98,
	"engineer": 1.03,
	"reaper": 1.03,
	"chronomancer": 1.03
}
const CHARACTER_TINT := {
	"scavenger": Color(1.0, 0.97, 0.9),
	"medic": Color(0.9, 1.0, 0.92),
	"ranger": Color(0.88, 0.96, 1.0),
	"bulwark": Color(0.84, 0.92, 1.0),
	"pyro": Color(1.0, 0.88, 0.76),
	"engineer": Color(1.0, 0.95, 0.76),
	"reaper": Color(1.0, 0.82, 0.86),
	"chronomancer": Color(0.92, 0.84, 1.0)
}
const COMBAT_PET: PackedScene = preload("res://scenes/player/combat_pet.tscn")
const MUZZLE_FLASH_SCRIPT: Script = preload("res://scripts/effects/muzzle_flash.gd")
const UNIQUE_SKILL_EFFECT_SCRIPT: Script = preload("res://scripts/effects/unique_skill_effect.gd")
const GUN_MOUNT_RIGHT := Vector2(38.0, -20.0)
const GUN_MOUNT_LEFT := Vector2(-38.0, -20.0)
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
var gun_kick_angle: float = 0.0
var sprite_base_scale: Vector2
var sprite_base_position: Vector2
var aim_angle: float = 0.0
var facing: String = "right"
var invulnerable: bool = false
var skill_cooldown: float = 0.0
var skill_duration: float = 0.0
var skill_shield_duration: float = 0.0
var skill_restore: Dictionary = {}
var critical_chance_add: float = 0.0
var critical_damage_mult: float = 1.75
var execute_threshold: float = 0.0
var health_regen_per_second: float = 0.0
var skill_cooldown_rate: float = 1.0
var regen_accumulator: float = 0.0
var synergy_kill_counter: int = 0
var revive_available: bool = false
var dash_cooldown: float = 0.0
var dash_time: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
const MOVEMENT_SAFETY_MARGIN := 16.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var gun_pivot: Node2D = $GunPivot
@onready var gun_sprite: Sprite2D = $GunPivot/GunSprite
@onready var muzzle: Marker2D = $GunPivot/GunSprite/Muzzle

func _ready() -> void:
	sprite_base_scale = sprite.scale
	sprite_base_position = sprite.position
	if sprite.material:
		sprite.material = sprite.material.duplicate()
	character_id = SaveManager.selected_character
	_apply_character_preset()
	_configure_character_sprite()
	VisualShadow.attach(self, Vector2(60.0, 19.0) if character_id == "bulwark" else Vector2(52.0, 17.0), Vector2(0.0, 52.0))
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
	max_health += SaveManager.get_upgrade_level("max_hp") * 15
	damage_mult += SaveManager.get_upgrade_level("damage") * 0.06
	speed_mult += SaveManager.get_upgrade_level("speed") * 0.04
	health_regen_per_second += SaveManager.get_upgrade_level("health_regen") * 0.2
	invulnerability_duration += SaveManager.get_upgrade_level("i_frames") * 0.05
	critical_chance_add += SaveManager.get_upgrade_level("crit_chance") * 0.03
	critical_damage_mult += SaveManager.get_upgrade_level("crit_damage") * 0.15
	reload_mult *= 1.0 - SaveManager.get_upgrade_level("fire_rate") * 0.04
	pierce_add += SaveManager.get_upgrade_level("piercing")
	revive_available = SaveManager.get_upgrade_level("revive") > 0

	health = max_health
	if SaveManager.get_upgrade_level("start_passive") > 0:
		_apply_random_start_passive()
	_spawn_equipped_pet()

	if not EventBus.perk_selected.is_connected(apply_perk):
		EventBus.perk_selected.connect(apply_perk)
	if not EventBus.zombie_died.is_connected(_on_enemy_defeated):
		EventBus.zombie_died.connect(_on_enemy_defeated)

	# Delay emitting signals slightly so HUD is ready
	call_deferred("_update_ui")

func _spawn_equipped_pet() -> void:
	var pet_id := RunStats.equipped_pet
	if pet_id.is_empty():
		pet_id = SaveManager.selected_pet
	if pet_id.is_empty():
		return
	var pet := COMBAT_PET.instantiate()
	pet.pet_id = pet_id
	pet.owner_player = self
	pet.position = position
	get_parent().add_child.call_deferred(pet)

func _update_ui() -> void:
	EventBus.player_health_changed.emit(health, max_health)
	EventBus.exp_changed.emit(current_exp, required_exp, current_level)

func _physics_process(_delta: float) -> void:
	dash_cooldown = maxf(0.0, dash_cooldown - _delta)
	var was_dashing := dash_time > 0.0
	dash_time = maxf(0.0, dash_time - _delta)
	if was_dashing and dash_time <= 0.0:
		velocity = Vector2.ZERO
	_update_unique_skill(_delta)
	_update_build_effects(_delta)
	_handle_movement(_delta)
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
		var frame_index := int(walk_time * 1.7) % 4
		_set_character_frame(frame_index)
		var stride := absf(sin(walk_time))
		target_position += Vector2(sin(walk_time * 0.5) * 1.2, -stride * 2.7)
	else:
		walk_time = lerpf(walk_time, 0.0, minf(delta * 8.0, 1.0))
		_set_character_frame(0)
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
	gun_kick_angle = move_toward(gun_kick_angle, 0.0, delta * 2.8)

func get_muzzle_global_position() -> Vector2:
	return muzzle.global_position

func _update_facing_from_aim() -> void:
	var aim_direction := Vector2.RIGHT.rotated(aim_angle)
	if absf(aim_direction.y) > absf(aim_direction.x):
		facing = "up" if aim_direction.y < 0.0 else "down"
	else:
		facing = "left" if aim_direction.x < 0.0 else "right"

func _update_facing_pose(_delta: float) -> void:
	var aim_vec := global_position.direction_to(get_global_mouse_position())
	if aim_vec == Vector2.ZERO:
		aim_vec = Vector2.RIGHT.rotated(aim_angle)
	var aiming_left := aim_vec.x < 0.0
	gun_sprite.visible = true
	gun_sprite.flip_h = false
	sprite.flip_h = aiming_left
	gun_pivot.scale.y = -1.0 if aiming_left else 1.0
	gun_pivot.position = (GUN_MOUNT_LEFT if aiming_left else GUN_MOUNT_RIGHT) - aim_vec * gun_recoil
	gun_pivot.rotation = aim_vec.angle() + gun_kick_angle
	gun_pivot.z_index = 8 if facing == "up" else 12

func _configure_character_sprite() -> void:
	var original_width := float(maxi(1, sprite.texture.get_width()))
	var sheet: Texture2D = CHARACTER_SHEETS.get(character_id, CHARACTER_SHEETS["scavenger"])
	var cell_width := float(sheet.get_width()) / 4.0
	sprite.texture = sheet
	sprite.region_enabled = true
	var visual_scale := float(CHARACTER_VISUAL_SCALE.get(character_id, 1.0))
	sprite_base_scale *= (original_width / cell_width) * visual_scale
	sprite.scale = sprite_base_scale
	sprite.modulate = CHARACTER_TINT.get(character_id, Color.WHITE)
	_set_character_frame(0)

func _set_character_frame(frame_index: int) -> void:
	if not sprite.region_enabled or not sprite.texture:
		return
	var cell_size := Vector2(float(sprite.texture.get_width()) / 4.0, float(sprite.texture.get_height()) / 4.0)
	var row := 1
	if facing == "down": row = 0
	elif facing == "up": row = 3
	sprite.region_rect = Rect2(Vector2(float(frame_index % 4) * cell_size.x, float(row) * cell_size.y), cell_size)

func trigger_weapon_recoil(amount: float = 3.5) -> void:
	gun_recoil = maxf(gun_recoil, amount)

func play_weapon_feedback(weapon_name: String, target_pos: Vector2) -> void:
	var recoil := 3.5
	var shake := 0.18
	var flash_size := 24.0
	var flash_color := Color(1.0, 0.78, 0.32, 1.0)
	match weapon_name:
		"Shotgun":
			recoil = 8.5
			shake = 0.72
			flash_size = 42.0
			flash_color = Color(1.0, 0.45, 0.16, 1.0)
		"Railgun":
			recoil = 11.0
			shake = 1.0
			flash_size = 52.0
			flash_color = Color(0.28, 0.92, 1.0, 1.0)
		"SMG":
			recoil = 2.0
			shake = 0.1
			flash_size = 17.0
		"Burst Rifle":
			recoil = 5.0
			shake = 0.38
			flash_size = 29.0
		"Lightning":
			recoil = 2.5
			shake = 0.28
			flash_color = Color(0.4, 0.9, 1.0, 1.0)
		"Shock Nova":
			recoil = 6.0
			shake = 0.55
			flash_size = 36.0
			flash_color = Color(0.35, 1.0, 0.82, 1.0)
		"Orbital":
			return
	trigger_weapon_recoil(recoil)
	gun_kick_angle = deg_to_rad(recoil * 0.75) * (1.0 if facing == "left" else -1.0)
	EventBus.camera_shake_requested.emit(shake)
	var flash := Node2D.new()
	flash.set_script(MUZZLE_FLASH_SCRIPT)
	get_tree().current_scene.add_child(flash)
	flash.call("setup", get_muzzle_global_position(), get_muzzle_global_position().direction_to(target_pos), flash_color, flash_size)

func _handle_movement(delta: float) -> void:
	if dash_time > 0.0:
		var dash_speed := move_speed * speed_mult * 3.2
		velocity = (dash_direction * dash_speed).limit_length(dash_speed)
		_move_safely(dash_speed, delta)
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var max_allowed_speed := move_speed * speed_mult * 1.5
	velocity = (input_dir * (move_speed * speed_mult)).limit_length(max_allowed_speed)
	_move_safely(max_allowed_speed, delta)

func _move_safely(max_speed: float, delta: float) -> void:
	var previous_position := global_position
	move_and_slide()
	var displacement := global_position - previous_position
	var max_displacement := max_speed * delta + MOVEMENT_SAFETY_MARGIN
	if displacement.length_squared() > max_displacement * max_displacement:
		global_position = previous_position + displacement.limit_length(max_displacement)
		velocity = Vector2.ZERO

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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_start_dash()
		elif event.keycode == KEY_E:
			use_unique_skill()
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
	RunStats.register_weapon(data.weapon_name)
	EventBus.inventory_updated.emit(weapons, passives)

func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO, source: String = "알 수 없는 위협", attack: String = "피해") -> void:
	if health <= 0 or invulnerable or skill_shield_duration > 0.0:
		return

	amount = maxi(1, int(ceil(float(amount) * incoming_damage_mult)))
	invulnerable = true
	health -= amount
	RunStats.register_damage(amount, source, attack, health <= 0)
	EventBus.camera_shake_requested.emit(clampf(float(amount) / 18.0, 0.65, 1.4))
	EventBus.player_health_changed.emit(health, max_health)
	_play_hit_feedback(hit_direction)
	AudioManager.play_named("hurt", -4.0)

	if health <= 0:
		if revive_available:
			_revive()
		else:
			die()
	else:
		get_tree().create_timer(invulnerability_duration).timeout.connect(func() -> void: invulnerable = false)

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
	if amount <= 0:
		return
	var recovered := mini(amount, max_health - health)
	if recovered <= 0:
		return
	health += recovered
	EventBus.player_health_changed.emit(health, max_health)

	var num = ObjectPoolManager.acquire("damage_number", global_position + Vector2(0, -42))
	if num and num.has_method("configure"):
		num.configure(recovered, "heal")

	if sprite and sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("flash_color", Color(0.2, 1.0, 0.45, 1.0))
		sprite.material.set_shader_parameter("active", true)
		var timer := get_tree().create_timer(0.12)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(sprite) and sprite.material is ShaderMaterial:
				sprite.material.set_shader_parameter("active", false)
		)
	AudioManager.play_named("pickup", -2.0, 1.25)

func add_exp(amount: int) -> void:
	current_exp += roundi(float(amount) * (1.0 + SaveManager.get_upgrade_level("exp_gain") * 0.05))
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

func get_unique_skill_max_cooldown() -> float:
	match character_id:
		"medic": return 18.0
		"ranger": return 16.0
		"bulwark": return 20.0
		"pyro": return 14.0
		"engineer": return 13.0
		"reaper": return 15.0
		"chronomancer": return 19.0
		_: return 15.0

func use_unique_skill() -> bool:
	if skill_cooldown > 0.0 or health <= 0:
		return false
	_spawn_unique_skill_effect()
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
	EventBus.camera_shake_requested.emit(1.15)
	AudioManager.play_named("level_up", -7.0, 1.08)
	return true

func _spawn_unique_skill_effect() -> void:
	var effect := Node2D.new()
	effect.set_script(UNIQUE_SKILL_EFFECT_SCRIPT)
	get_tree().current_scene.add_child(effect)
	var target_points := PackedVector2Array()
	if character_id in ["engineer", "reaper"]:
		var targets := get_tree().get_nodes_in_group("enemies")
		targets.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
		for index in mini(7, targets.size()):
			var target = targets[index]
			if is_instance_valid(target) and (character_id != "reaper" or global_position.distance_to(target.global_position) <= 420.0):
				target_points.append(target.global_position)
	effect.call("setup", character_id, global_position, target_points)

func _update_unique_skill(delta: float) -> void:
	skill_cooldown = maxf(0.0, skill_cooldown - delta * skill_cooldown_rate)
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
		enemy.take_damage(damage, global_position.direction_to(enemy.global_position), "execute" if damage > enemy_health else "normal")
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

func configure_projectile(projectile: Node) -> void:
	projectile.set("critical_chance", clampf(float(projectile.get("critical_chance")) + critical_chance_add, 0.0, 0.65))
	projectile.set("critical_damage_multiplier", critical_damage_mult)
	projectile.set("execute_threshold", execute_threshold)

func apply_build_hit(target: Node, amount: int, direction: Vector2, base_critical_chance: float = 0.0, impact_kind: String = "normal", weapon_id: String = "") -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	var final_damage := amount
	var hit_kind := impact_kind
	var target_health = target.get("health")
	var target_max_health = target.get("max_health")
	if execute_threshold > 0.0 and target_health != null and target_max_health != null and float(target_health) / float(maxi(1, int(target_max_health))) <= execute_threshold:
		final_damage = int(target_health) + 1
		hit_kind = "execute"
	elif randf() < clampf(base_critical_chance + critical_chance_add, 0.0, 0.65):
		final_damage = roundi(float(amount) * critical_damage_mult)
		hit_kind = "critical"
	target.take_damage(final_damage, direction, hit_kind, weapon_id)

func _start_dash() -> void:
	if get_tree().paused or dash_cooldown > 0.0 or health <= 0:
		return
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction == Vector2.ZERO:
		return
	dash_direction = input_direction.normalized()
	dash_time = 0.16
	dash_cooldown = 2.4 * (1.0 - SaveManager.get_upgrade_level("dash_cooldown") * 0.08)
	invulnerable = true
	get_tree().create_timer(dash_time).timeout.connect(func() -> void: invulnerable = false)

func _revive() -> void:
	revive_available = false
	health = maxi(1, roundi(max_health * 0.3))
	invulnerable = true
	EventBus.player_health_changed.emit(health, max_health)
	_damage_enemies_in_radius(300.0, 60, 650.0)
	EventBus.camera_shake_requested.emit(1.4)
	get_tree().create_timer(1.5).timeout.connect(func() -> void: invulnerable = false)

func _apply_random_start_passive() -> void:
	var candidates: Array[PerkData] = []
	for file_name in DirAccess.get_files_at("res://data/perks"):
		var resource := load("res://data/perks/" + file_name)
		if resource is PerkData:
			candidates.append(resource)
	if not candidates.is_empty():
		apply_perk(candidates.pick_random())

func _update_build_effects(delta: float) -> void:
	if health_regen_per_second <= 0.0 or health <= 0 or health >= max_health:
		return
	regen_accumulator += health_regen_per_second * delta
	if regen_accumulator >= 1.0:
		var heal_amount := int(regen_accumulator)
		regen_accumulator -= float(heal_amount)
		heal(heal_amount)

func _on_enemy_defeated(_position: Vector2) -> void:
	if "blood_engine" not in active_synergies:
		return
	synergy_kill_counter += 1
	if synergy_kill_counter >= 5:
		synergy_kill_counter = 0
		heal(4)

func get_active_build_labels() -> Array[String]:
	var labels: Array[String] = []
	for synergy in active_synergies:
		match synergy:
			"armor_breaker": labels.append("장갑 파쇄자")
			"combat_medic": labels.append("기동 의무병")
			"gunrunner": labels.append("런 앤 건")
			"execution_protocol": labels.append("처형 교리")
			"overclock": labels.append("과부하 전술")
			"field_survivor": labels.append("불굴의 생존자")
			"scavenger_economy": labels.append("폐허 경제")
			"blood_engine": labels.append("피의 엔진")
	return labels

func get_next_build_hint() -> String:
	var perk_ids: Array[String] = []
	for perk in passives:
		perk_ids.append(perk.id)
	var recipes := [
		["heavy_caliber", "piercing_rounds", "장갑 파쇄자"],
		["hollow_point", "executioner", "처형 교리"],
		["fast_hands", "momentum", "런 앤 건"],
		["adrenaline", "stabilizer", "과부하 전술"],
		["reinforced_vest", "trauma_kit", "불굴의 생존자"],
		["scavenged_ammo", "field_rations", "폐허 경제"],
		["medic_kit", "light_foot", "기동 의무병"],
		["bloodlust", "field_rations", "피의 엔진"]
	]
	for recipe in recipes:
		var has_first := String(recipe[0]) in perk_ids
		var has_second := String(recipe[1]) in perk_ids
		if has_first != has_second:
			return "%s 완성: %s 필요" % [recipe[2], _perk_display_name(String(recipe[1] if has_first else recipe[0]))]
	return ""

func _perk_display_name(perk_id: String) -> String:
	match perk_id:
		"heavy_caliber": return "대구경 탄환"
		"piercing_rounds": return "철갑탄"
		"hollow_point": return "할로우 포인트"
		"executioner": return "처형 프로토콜"
		"fast_hands": return "빠른 손놀림"
		"momentum": return "가속 전술"
		"adrenaline": return "아드레날린"
		"stabilizer": return "반동 제어기"
		"reinforced_vest": return "복합 장갑"
		"trauma_kit": return "외상 키트"
		"scavenged_ammo": return "회수 탄약"
		"field_rations": return "야전 식량"
		"medic_kit": return "응급 키트"
		"light_foot": return "가벼운 발걸음"
		"bloodlust": return "피의 굶주림"
		_: return perk_id

func _check_synergies() -> void:
	var perk_ids: Array[String] = []
	for perk in passives:
		perk_ids.append(perk.id)

	if "heavy_caliber" in perk_ids and "piercing_rounds" in perk_ids and not "armor_breaker" in active_synergies:
		active_synergies.append("armor_breaker")
		damage_mult *= 1.15
		pierce_add += 1
	if "medic_kit" in perk_ids and "light_foot" in perk_ids and not "combat_medic" in active_synergies:
		active_synergies.append("combat_medic")
		reload_mult *= 0.9
		health_regen_per_second += 0.75
	if "fast_hands" in perk_ids and "momentum" in perk_ids and not "gunrunner" in active_synergies:
		active_synergies.append("gunrunner")
		reload_mult *= 0.8
		speed_mult *= 1.12
		critical_chance_add += 0.05
	if "hollow_point" in perk_ids and "executioner" in perk_ids and not "execution_protocol" in active_synergies:
		active_synergies.append("execution_protocol")
		critical_chance_add += 0.12
		execute_threshold = maxf(execute_threshold, 0.2)
	if "adrenaline" in perk_ids and "stabilizer" in perk_ids and not "overclock" in active_synergies:
		active_synergies.append("overclock")
		skill_cooldown_rate *= 1.35
		damage_mult *= 1.08
	if "reinforced_vest" in perk_ids and "trauma_kit" in perk_ids and not "field_survivor" in active_synergies:
		active_synergies.append("field_survivor")
		incoming_damage_mult *= 0.82
		health_regen_per_second += 1.25
	if "scavenged_ammo" in perk_ids and "field_rations" in perk_ids and not "scavenger_economy" in active_synergies:
		active_synergies.append("scavenger_economy")
		RunStats.scrap_multiplier *= 1.4
		pierce_add += 1
	if "bloodlust" in perk_ids and "field_rations" in perk_ids and not "blood_engine" in active_synergies:
		active_synergies.append("blood_engine")
		damage_mult *= 1.12
