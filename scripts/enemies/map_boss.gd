class_name MapBoss
extends CharacterBody2D

@export_enum("Quarantine Warden", "Foundry Juggernaut", "Mire Leviathan", "Director Null") var boss_id: int = 0
@export var boss_name: String = "격리 감시관"
@export var max_health: int = 120
@export var move_speed: float = 72.0
@export var attack_damage: int = 18

@onready var sprite: Sprite2D = $Sprite2D

var health: int
var player: Player
var phase: int = 1
var attack_timer: float = 2.4
var telegraph_timer: float = 0.0
var attack_mode: String = ""
var charge_timer: float = 0.0
var contact_cooldown: float = 0.0
var dying: bool = false
var base_sprite_scale: Vector2
var visual_time: float = 0.0
var endless_index: int = 0
var previous_position: Vector2
var trail_timer: float = 0.0

const BOSS_SKILL_EFFECT: Script = preload("res://scripts/effects/boss_skill_effect.gd")

const BOSS_COLORS := [
	Color(1.0, 0.58, 0.18, 1.0),
	Color(1.0, 0.26, 0.08, 1.0),
	Color(0.48, 1.0, 0.22, 1.0),
	Color(0.68, 0.34, 1.0, 1.0)
]

func _ready() -> void:
	z_index = 9
	base_sprite_scale = sprite.scale
	if sprite.material:
		sprite.material = sprite.material.duplicate()
	VisualShadow.attach(self, Vector2(112.0, 34.0), Vector2(0.0, 102.0))
	health = max_health
	player = get_tree().get_first_node_in_group("player") as Player
	previous_position = global_position
	SpatialGrid.insert(self)
	EventBus.boss_status_changed.emit(boss_name, 1.0, phase)

func configure(health_multiplier: float, damage_multiplier: float, hacked: bool, cycle: int) -> void:
	endless_index = cycle
	max_health = maxi(1, roundi(float(max_health) * health_multiplier * (0.76 if hacked else 1.0)))
	health = max_health
	attack_damage = maxi(1, roundi(float(attack_damage) * damage_multiplier))
	attack_timer = 2.8
	EventBus.boss_status_changed.emit(boss_name, 1.0, phase)

func _physics_process(delta: float) -> void:
	if dying:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if not is_instance_valid(player):
			return

	visual_time += delta
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	_update_phase()
	_update_visuals(delta)

	if charge_timer > 0.0:
		charge_timer -= delta
		trail_timer -= delta
		if trail_timer <= 0.0:
			trail_timer = 0.08
			_spawn_skill_effect("charge", global_position, 130.0, 0.32, 0, velocity.normalized())
		move_and_slide()
		_update_spatial_position()
		_check_contact_hit(1.35)
		queue_redraw()
		return

	if telegraph_timer > 0.0:
		telegraph_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		_update_spatial_position()
		if telegraph_timer <= 0.0:
			_execute_attack()
		queue_redraw()
		return

	_move_for_profile(delta)
	_update_spatial_position()
	attack_timer -= delta
	if attack_timer <= 0.0:
		_begin_attack()
	_check_contact_hit(1.0)
	queue_redraw()

func _move_for_profile(delta: float) -> void:
	var distance := global_position.distance_to(player.global_position)
	var desired_distance := [145.0, 170.0, 285.0, 250.0][boss_id]
	var direction := global_position.direction_to(player.global_position)
	if distance > desired_distance + 35.0:
		velocity = velocity.move_toward(direction * move_speed * (1.0 + 0.1 * float(phase - 1)), 420.0 * delta)
	elif distance < desired_distance - 35.0:
		velocity = velocity.move_toward(-direction * move_speed * 0.65, 420.0 * delta)
	else:
		var tangent := direction.orthogonal() * (1.0 if sin(visual_time * 0.7) >= 0.0 else -1.0)
		velocity = velocity.move_toward(tangent * move_speed * 0.55, 320.0 * delta)
	move_and_slide()

func _update_spatial_position() -> void:
	SpatialGrid.update_entity(self, previous_position, global_position)
	previous_position = global_position

func _update_phase() -> void:
	var ratio := float(health) / float(maxi(1, max_health))
	var next_phase := 3 if ratio <= 0.34 else (2 if ratio <= 0.67 else 1)
	if next_phase != phase:
		phase = next_phase
		attack_timer = 0.7
		_spawn_impact(BOSS_COLORS[boss_id], 190.0 + float(phase) * 25.0)
	EventBus.boss_status_changed.emit(boss_name, ratio, phase)

func _begin_attack() -> void:
	var choices: Array[String]
	match boss_id:
		0: choices = ["shield_charge", "warden_slam", "reinforcements"] if phase >= 2 else ["shield_charge", "warden_slam"]
		1: choices = ["forge_wave", "vent_barrage", "overheat"] if phase >= 2 else ["forge_wave", "vent_barrage"]
		2: choices = ["acid_fan", "toxic_pool", "brood_call"] if phase >= 2 else ["acid_fan", "toxic_pool"]
		_: choices = ["null_blink", "void_barrage", "specimen_call"] if phase >= 2 else ["null_blink", "void_barrage"]
	attack_mode = choices.pick_random()
	telegraph_timer = 0.8 if attack_mode not in ["shield_charge", "null_blink"] else 0.62
	attack_timer = maxf(1.8, 4.4 - float(phase) * 0.55)
	EventBus.boss_attack_warning.emit(_attack_display_name(), true)

func _execute_attack() -> void:
	EventBus.boss_attack_warning.emit(_attack_display_name(), false)
	match attack_mode:
		"shield_charge":
			velocity = global_position.direction_to(player.global_position) * (610.0 + float(phase) * 55.0)
			charge_timer = 0.72
			trail_timer = 0.0
		"warden_slam": _radial_hit(245.0, 1.15, Color(1.0, 0.62, 0.18, 1.0))
		"reinforcements": _summon_enemies("zombie_runner", 2 + phase)
		"forge_wave": _radial_hit(320.0, 1.25, Color(1.0, 0.22, 0.06, 1.0))
		"vent_barrage": _fire_radial(7 + phase * 2, 0.0)
		"overheat":
			_radial_hit(210.0, 1.5, Color(1.0, 0.35, 0.04, 1.0))
			_spawn_skill_effect("fire", global_position, 210.0, 2.8, maxi(1, roundi(float(attack_damage) * 0.28)))
			_fire_radial(10 + phase * 2, PI / 10.0)
		"acid_fan": _fire_fan(5 + phase, 0.72)
		"toxic_pool":
			_spawn_impact(Color(0.42, 1.0, 0.12, 1.0), 285.0)
			_spawn_skill_effect("toxic", global_position, 285.0, 4.5, maxi(1, roundi(float(attack_damage) * 0.34)))
		"brood_call": _summon_enemies("zombie_spitter" if phase == 2 else "zombie_bloater", 2 + phase)
		"null_blink": _blink_strike()
		"void_barrage": _fire_radial(10 + phase * 3, visual_time)
		"specimen_call":
			_summon_enemies("zombie_runner", 2 + phase)
			_fire_radial(6 + phase * 2, PI / 8.0)
	attack_mode = ""

func _attack_display_name() -> String:
	match attack_mode:
		"shield_charge": return "방패 파쇄 돌진"
		"warden_slam": return "진압 충격파"
		"reinforcements": return "격리 병력 호출"
		"forge_wave": return "용광로 지진"
		"vent_barrage": return "압력 밸브 난사"
		"overheat": return "임계 과열"
		"acid_fan": return "부식성 토사"
		"toxic_pool": return "오염 범람"
		"brood_call": return "수몰 군체 호출"
		"null_blink": return "영점 전이"
		"void_barrage": return "보이드 탄막"
		"specimen_call": return "실험체 해방"
		_: return "보스 공격"

func _radial_hit(radius: float, multiplier: float, color: Color) -> void:
	if global_position.distance_to(player.global_position) <= radius:
		player.take_damage(roundi(float(attack_damage) * multiplier), global_position.direction_to(player.global_position))
	_spawn_impact(color, radius)

func _fire_radial(count: int, angle_offset: float) -> void:
	for index in count:
		var direction := Vector2.RIGHT.rotated(angle_offset + TAU * float(index) / float(count))
		_spawn_projectile(direction)

func _fire_fan(count: int, spread: float) -> void:
	var center := global_position.direction_to(player.global_position).angle()
	for index in count:
		var ratio := 0.5 if count <= 1 else float(index) / float(count - 1)
		_spawn_projectile(Vector2.RIGHT.rotated(center + lerpf(-spread, spread, ratio)))

func _spawn_projectile(direction: Vector2) -> void:
	var projectile = ObjectPoolManager.acquire("acid_projectile", global_position + direction * 80.0)
	if projectile:
		projectile.direction = direction
		projectile.damage = maxi(1, roundi(float(attack_damage) * 0.62))
		projectile.speed = 260.0 + float(phase) * 24.0
		if projectile is CanvasItem:
			projectile.modulate = BOSS_COLORS[boss_id]

func _summon_enemies(pool_id: String, count: int) -> void:
	for index in count:
		var spawn_position := global_position + Vector2.RIGHT.rotated(TAU * float(index) / float(count)) * randf_range(150.0, 230.0)
		var summon = ObjectPoolManager.acquire(pool_id, spawn_position)
		if summon:
			summon.set_meta("pool_id", pool_id)
			if summon.has_method("set_scaled_max_health"):
				summon.set_scaled_max_health(1.0 + float(phase) * 0.45)

func _blink_strike() -> void:
	_spawn_skill_effect("blink", global_position, 150.0, 0.55)
	var offset := -player.velocity.normalized() * 150.0
	if offset == Vector2.ZERO:
		offset = Vector2.RIGHT.rotated(randf() * TAU) * 150.0
	global_position = player.global_position + offset
	_spawn_skill_effect("blink", global_position, 190.0, 0.7)
	_radial_hit(185.0, 1.2, Color(0.68, 0.34, 1.0, 1.0))
	_fire_radial(6 + phase * 2, visual_time)

func _check_contact_hit(multiplier: float) -> void:
	if contact_cooldown > 0.0:
		return
	if global_position.distance_to(player.global_position) <= 118.0:
		player.take_damage(roundi(float(attack_damage) * multiplier), global_position.direction_to(player.global_position))
		contact_cooldown = 0.8

func _spawn_impact(color: Color, radius: float) -> void:
	var impact = ObjectPoolManager.acquire("blood_impact", global_position)
	if impact and impact.has_method("configure"):
		impact.configure(color, radius)
	AudioManager.play_named("impact", -3.0, randf_range(0.72, 0.9))

func _spawn_skill_effect(kind: String, effect_position: Vector2, radius: float, duration: float, damage: int = 0, direction: Vector2 = Vector2.RIGHT) -> void:
	var effect := BOSS_SKILL_EFFECT.new() as BossSkillEffect
	get_tree().current_scene.add_child(effect)
	effect.global_position = effect_position
	effect.setup(kind, BOSS_COLORS[boss_id], radius, duration, damage, direction)

func _update_visuals(delta: float) -> void:
	var pulse := 1.0 + sin(visual_time * (3.2 + float(phase))) * 0.018
	var target_scale := base_sprite_scale * pulse
	sprite.scale = sprite.scale.lerp(target_scale, minf(delta * 8.0, 1.0))
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0

func take_damage(amount: int, knockback_direction: Vector2 = Vector2.ZERO, hit_kind: String = "normal") -> void:
	if dying:
		return
	var applied := mini(maxi(0, amount), health)
	health -= applied
	RunStats.register_combat_hit(applied, hit_kind)
	if knockback_direction != Vector2.ZERO and charge_timer <= 0.0:
		velocity += knockback_direction * 18.0
	if sprite.material:
		sprite.material.set_shader_parameter("active", true)
		get_tree().create_timer(0.1).timeout.connect(func():
			if is_instance_valid(sprite) and sprite.material:
				sprite.material.set_shader_parameter("active", false)
		)
	if health <= 0:
		_die()

func _die() -> void:
	if dying:
		return
	dying = true
	health = 0
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	SpatialGrid.remove(self)
	RunStats.register_kill()
	RunStats.add_scrap(40 + boss_id * 5)
	EventBus.zombie_died.emit(global_position)
	EventBus.boss_status_changed.emit("", -1.0, 0)
	EventBus.boss_attack_warning.emit("", false)
	EventBus.boss_defeated.emit()
	_spawn_impact(BOSS_COLORS[boss_id], 360.0)
	if RunStats.endless_mode:
		SaveManager.add_gold(250 + boss_id * 50)
		ObjectPoolManager.acquire("exp_gem", global_position)
	else:
		SaveManager.add_gold(1000 + boss_id * 150)
		EventBus.game_over.emit(true)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.8)
	tween.tween_property(sprite, "scale", base_sprite_scale * 1.22, 0.8)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _draw() -> void:
	if telegraph_timer <= 0.0:
		return
	var color := BOSS_COLORS[boss_id]
	var alpha := 0.35 + sin(visual_time * 18.0) * 0.12
	match attack_mode:
		"shield_charge":
			var target := to_local(player.global_position)
			draw_line(Vector2.ZERO, target.normalized() * 620.0, Color(color, alpha), 42.0, true)
		"null_blink":
			draw_circle(to_local(player.global_position), 185.0, Color(color, alpha * 0.45))
		"acid_fan":
			var direction := global_position.direction_to(player.global_position)
			for offset in [-0.72, 0.0, 0.72]:
				draw_line(Vector2.ZERO, direction.rotated(offset) * 480.0, Color(color, alpha), 9.0, true)
		_:
			var radius := 320.0 if attack_mode in ["forge_wave", "toxic_pool"] else 245.0
			draw_circle(Vector2.ZERO, radius, Color(color, alpha * 0.32))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, 0.9), 8.0, true)
