class_name WaveAISystem
extends RefCounted

# res://scripts/simulation/systems/wave_ai_system.gd
# Authoritative wave spawning, zombie AI navigation/targeting, and attack resolution.

const SimulationWorldClass = preload("res://scripts/simulation/model/simulation_world.gd")
const EntityStateClass = preload("res://scripts/simulation/model/entity_state.gd")
const DomainEventsClass = preload("res://scripts/simulation/events/domain_events.gd")
const GameStateMachineClass = preload("res://scripts/core/game_state_machine.gd")

var world: SimulationWorldClass

const ZOMBIE_SPEED: float = 90.0
const ATTACK_RANGE: float = 35.0
const ATTACK_COOLDOWN_TICKS: int = 60 # 1.0s at 60Hz
const ZOMBIE_DAMAGE: float = 10.0
const TICK_DELTA: float = 1.0 / 60.0

var wave_active: bool = false
var total_to_spawn: int = 0
var spawned_count: int = 0
var spawn_interval_ticks: int = 90 # 1.5s
var spawn_timer: int = 0
var wave_completed_emitted: bool = false

func _init(p_world: SimulationWorldClass) -> void:
	world = p_world

func start_wave(day: int, base_count: int, events: Array[Dictionary]) -> void:
	wave_active = true
	wave_completed_emitted = false
	var scale: float = 1.0 + float(day - 1) * 0.25
	total_to_spawn = int(ceil(float(base_count) * scale))
	spawned_count = 0
	spawn_timer = 0

	var ev_id = world.id_generator.generate_event_id()
	events.append(DomainEventsClass.create_event(
		ev_id,
		world.server_tick,
		DomainEventsClass.EventType.WAVE_STARTED,
		{
			"day": day,
			"total_count": total_to_spawn
		}
	))

func step_tick(events: Array[Dictionary]) -> void:
	if world.session_state.phase != GameStateMachineClass.State.NIGHT_DEFENSE:
		return

	if wave_active:
		# Process spawning
		if spawned_count < total_to_spawn:
			spawn_timer -= 1
			if spawn_timer <= 0:
				spawn_timer = spawn_interval_ticks
				_spawn_zombie(events)

	# Process AI movement and attack for active zombies
	var alive_zombies: int = 0
	var player_entity: EntityStateClass = null

	for e_id in world.entities:
		var e: EntityStateClass = world.entities[e_id]
		if e.definition_id == &"player" and e.is_alive():
			player_entity = e
			break

	var target_pos := Vector2.ZERO
	if player_entity != null:
		target_pos = player_entity.position

	for e_id in world.entities.keys():
		var zombie: EntityStateClass = world.entities.get(e_id, null)
		if zombie == null or not zombie.is_alive() or zombie.definition_id != &"zombie_basic":
			continue

		alive_zombies += 1

		# Cooldown tick
		var cd: int = int(zombie.cooldowns.get("attack", 0))
		if cd > 0:
			zombie.cooldowns["attack"] = cd - 1

		var to_target := target_pos - zombie.position
		var dist := to_target.length()

		if dist > ATTACK_RANGE:
			var move_dir := to_target.normalized()
			zombie.velocity = move_dir * ZOMBIE_SPEED
			zombie.position += zombie.velocity * TICK_DELTA
		else:
			zombie.velocity = Vector2.ZERO
			if cd <= 0 and player_entity != null and player_entity.is_alive():
				zombie.cooldowns["attack"] = ATTACK_COOLDOWN_TICKS
				# Attack player
				player_entity.health = maxf(0.0, player_entity.health - ZOMBIE_DAMAGE)
				var ev_id = world.id_generator.generate_event_id()
				events.append(DomainEventsClass.create_event(
					ev_id,
					world.server_tick,
					DomainEventsClass.EventType.DAMAGE_RESOLVED,
					{
						"target_entity_id": player_entity.entity_id,
						"attacker_entity_id": zombie.entity_id,
						"damage": ZOMBIE_DAMAGE,
						"remaining_hp": player_entity.health,
						"is_critical": false
					}
				))

	# Check wave progress and completion
	if wave_active:
		var ev_prog_id = world.id_generator.generate_event_id()
		events.append(DomainEventsClass.create_event(
			ev_prog_id,
			world.server_tick,
			DomainEventsClass.EventType.WAVE_PROGRESS,
			{
				"day": world.session_state.day,
				"spawned": spawned_count,
				"total": total_to_spawn,
				"alive": alive_zombies
			}
		))

		if spawned_count >= total_to_spawn and alive_zombies == 0 and not wave_completed_emitted:
			wave_active = false
			wave_completed_emitted = true
			var ev_comp_id = world.id_generator.generate_event_id()
			events.append(DomainEventsClass.create_event(
				ev_comp_id,
				world.server_tick,
				DomainEventsClass.EventType.WAVE_COMPLETED,
				{
					"day": world.session_state.day,
					"survived": true
				}
			))

func _spawn_zombie(events: Array[Dictionary]) -> void:
	var entity_id: int = world.id_generator.generate_entity_id()
	var zombie := EntityStateClass.new(entity_id, &"zombie_basic", 0)

	# Scale HP by day
	var base_hp: float = 50.0
	var scaled_hp: float = base_hp * (1.0 + float(world.session_state.day - 1) * 0.15)
	zombie.health = scaled_hp
	zombie.max_health = scaled_hp

	# Spawn at perimeter (radius 500)
	var angle := world.rng.randf_range("wave", 0.0, TAU)
	zombie.position = Vector2(cos(angle) * 500.0, sin(angle) * 300.0)

	world.add_entity(zombie)
	spawned_count += 1

	var ev_id = world.id_generator.generate_event_id()
	events.append(DomainEventsClass.create_event(
		ev_id,
		world.server_tick,
		DomainEventsClass.EventType.ENTITY_SPAWNED,
		{
			"entity_id": entity_id,
			"definition_id": "zombie_basic",
			"position": [zombie.position.x, zombie.position.y],
			"max_health": scaled_hp
		}
	))
