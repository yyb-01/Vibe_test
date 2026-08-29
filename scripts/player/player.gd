class_name Player
extends CharacterBody2D

@export var max_health: int = 100
@export var move_speed: float = 200.0
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

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if sprite.material:
		sprite.material = sprite.material.duplicate()
	character_id = SaveManager.selected_character
	_apply_character_preset()
	if not RunStats.run_active:
		RunStats.start_run(get_tree().current_scene.scene_file_path.get_file().get_basename())

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

func _handle_movement() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * (move_speed * speed_mult)
	move_and_slide()

func _handle_shooting() -> void:
	# Always aim at the mouse cursor
	look_at(get_global_mouse_position())
	if not auto_fire_enabled and not Input.is_action_pressed("shoot"):
		return

	# Iterate over all weapons and attempt to fire
	var target_pos = get_global_mouse_position()
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
	if health <= 0:
		return

	health -= amount
	RunStats.register_damage(amount)
	EventBus.camera_shake_requested.emit()
	EventBus.player_health_changed.emit(health, max_health)
	_play_hit_feedback(hit_direction)
	AudioManager.play_named("hurt", -4.0)

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
