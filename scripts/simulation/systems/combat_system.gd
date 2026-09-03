class_name CombatSystem
extends RefCounted

# res://scripts/simulation/systems/combat_system.gd
# Authoritative combat mechanics: shooting, melee cones, damage calculation, and death resolution.

const SimulationWorldClass = preload("res://scripts/simulation/model/simulation_world.gd")
const EntityStateClass = preload("res://scripts/simulation/model/entity_state.gd")
const DomainEventsClass = preload("res://scripts/simulation/events/domain_events.gd")

const SHOOT_COOLDOWN_TICKS: int = 12   # 0.2s at 60Hz
const MELEE_COOLDOWN_TICKS: int = 19   # ~0.32s at 60Hz
const BULLET_DAMAGE: float = 25.0
const MELEE_DAMAGE: float = 38.0
const MELEE_RADIUS: float = 86.0
const MELEE_CONE_ANGLE_RAD: float = deg_to_rad(90.0)

const CRIT_CHANCE: float = 0.12
const CRIT_MULT: float = 1.75

var world: SimulationWorldClass

func _init(p_world: SimulationWorldClass) -> void:
	world = p_world

func handle_shoot(entity_id: int, aim_dir: Vector2, events: Array[Dictionary]) -> bool:
	var shooter: EntityStateClass = world.get_entity(entity_id)
	if shooter == null or not shooter.is_alive():
		return false

	var cd: int = int(shooter.cooldowns.get("shoot", 0))
	if cd > 0:
		return false

	shooter.cooldowns["shoot"] = SHOOT_COOLDOWN_TICKS
	world.session_state.day_stats["ammo_consumed"] = int(world.session_state.day_stats.get("ammo_consumed", 0)) + 1

	var dir := aim_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var ev_id = world.id_generator.generate_event_id()
	events.append(DomainEventsClass.create_event(
		ev_id,
		world.server_tick,
		DomainEventsClass.EventType.ABILITY_STARTED,
		{
			"entity_id": entity_id,
			"ability_id": "shoot",
			"direction": [dir.x, dir.y]
		}
	))

	# Authoritative Ray/Sweep hit resolution against active enemies
	var closest_target: EntityStateClass = null
	var closest_dist: float = 800.0

	for other_id in world.entities:
		if other_id == entity_id:
			continue
		var target: EntityStateClass = world.entities[other_id]
		if not target.is_alive() or target.definition_id == &"player":
			continue

		var to_target := target.position - shooter.position
		var dist := to_target.length()
		if dist > closest_dist:
			continue

		# Check line of fire (forward dot and perpendicular distance)
		var proj := to_target.dot(dir)
		if proj <= 0.0:
			continue
		var perp := (to_target - dir * proj).length()
		if perp <= 24.0: # hit radius
			closest_dist = dist
			closest_target = target

	if closest_target != null:
		var is_crit := world.rng.randf("combat") < CRIT_CHANCE
		var dmg := BULLET_DAMAGE * (CRIT_MULT if is_crit else 1.0)
		apply_damage(closest_target.entity_id, entity_id, dmg, is_crit, events)

	return true

func handle_melee(entity_id: int, aim_dir: Vector2, events: Array[Dictionary]) -> int:
	var attacker: EntityStateClass = world.get_entity(entity_id)
	if attacker == null or not attacker.is_alive():
		return 0

	var cd: int = int(attacker.cooldowns.get("melee", 0))
	if cd > 0:
		return 0

	attacker.cooldowns["melee"] = MELEE_COOLDOWN_TICKS

	var dir := aim_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var ev_id = world.id_generator.generate_event_id()
	events.append(DomainEventsClass.create_event(
		ev_id,
		world.server_tick,
		DomainEventsClass.EventType.ABILITY_STARTED,
		{
			"entity_id": entity_id,
			"ability_id": "melee",
			"direction": [dir.x, dir.y]
		}
	))

	var half_angle := MELEE_CONE_ANGLE_RAD * 0.5
	var hit_count: int = 0

	for other_id in world.entities.keys():
		if other_id == entity_id:
			continue
		var target: EntityStateClass = world.entities.get(other_id, null)
		if target == null or not target.is_alive() or target.definition_id == &"player":
			continue

		var to_target := target.position - attacker.position
		var dist := to_target.length()
		if dist > MELEE_RADIUS:
			continue

		var angle_diff := absf(dir.angle_to(to_target))
		if angle_diff <= half_angle:
			var is_crit := world.rng.randf("combat") < CRIT_CHANCE
			var dmg := MELEE_DAMAGE * (CRIT_MULT if is_crit else 1.0)
			apply_damage(target.entity_id, entity_id, dmg, is_crit, events)
			hit_count += 1

	return hit_count

func apply_damage(
	target_entity_id: int,
	attacker_entity_id: int,
	amount: float,
	is_critical: bool,
	events: Array[Dictionary]
) -> void:
	var target: EntityStateClass = world.get_entity(target_entity_id)
	if target == null or not target.is_alive():
		return

	# Check iframe
	var iframe_ticks: int = int(target.custom_data.get("dash_iframe_ticks_left", 0))
	if iframe_ticks > 0:
		return

	target.health = maxf(0.0, target.health - amount)

	var ev_id = world.id_generator.generate_event_id()
	events.append(DomainEventsClass.create_event(
		ev_id,
		world.server_tick,
		DomainEventsClass.EventType.DAMAGE_RESOLVED,
		{
			"target_entity_id": target_entity_id,
			"attacker_entity_id": attacker_entity_id,
			"damage": amount,
			"remaining_hp": target.health,
			"is_critical": is_critical
		}
	))

	if target.health <= 0.0:
		target.lifecycle = EntityStateClass.Lifecycle.DESPAWNING
		if target.definition_id != &"player" and target.definition_id != &"base_core":
			world.session_state.day_stats["zombies_killed"] = int(world.session_state.day_stats.get("zombies_killed", 0)) + 1

		var death_ev_id = world.id_generator.generate_event_id()
		events.append(DomainEventsClass.create_event(
			death_ev_id,
			world.server_tick,
			DomainEventsClass.EventType.ENTITY_DIED,
			{
				"entity_id": target_entity_id,
				"killer_entity_id": attacker_entity_id
			}
		))
