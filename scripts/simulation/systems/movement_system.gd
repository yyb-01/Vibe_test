class_name MovementSystem
extends RefCounted

# res://scripts/simulation/systems/movement_system.gd
# Authoritative movement, acceleration, friction, and dash physics calculated per 60Hz tick.

const SimulationWorldClass = preload("res://scripts/simulation/model/simulation_world.gd")
const EntityStateClass = preload("res://scripts/simulation/model/entity_state.gd")
const DomainEventsClass = preload("res://scripts/simulation/events/domain_events.gd")

const MOVE_SPEED: float = 220.0
const ACCELERATION: float = 3200.0
const FRICTION: float = 2800.0
const DASH_SPEED: float = 760.0

const TICK_DELTA: float = 1.0 / 60.0

# 60Hz tick durations
const DASH_DURATION_TICKS: int = 12       # ~0.2s
const DASH_IFRAME_TICKS: int = 9          # ~0.15s
const DASH_COOLDOWN_TICKS: int = 27       # ~0.45s

var world: SimulationWorldClass

func _init(p_world: SimulationWorldClass) -> void:
	world = p_world

func handle_move_intent(entity_id: int, axis: Vector2) -> void:
	var entity: EntityStateClass = world.get_entity(entity_id)
	if entity == null or not entity.is_alive():
		return

	entity.custom_data["input_axis"] = [axis.x, axis.y]

func handle_dash(entity_id: int, direction: Vector2, events: Array[Dictionary]) -> bool:
	var entity: EntityStateClass = world.get_entity(entity_id)
	if entity == null or not entity.is_alive():
		return false

	var cd: int = int(entity.cooldowns.get("dash", 0))
	if cd > 0:
		return false

	var dash_dir := direction.normalized()
	if dash_dir == Vector2.ZERO:
		dash_dir = Vector2.RIGHT

	entity.custom_data["dash_ticks_left"] = DASH_DURATION_TICKS
	entity.custom_data["dash_iframe_ticks_left"] = DASH_IFRAME_TICKS
	entity.custom_data["dash_dir"] = [dash_dir.x, dash_dir.y]
	entity.cooldowns["dash"] = DASH_COOLDOWN_TICKS

	var ev_id = world.id_generator.generate_event_id()
	events.append(DomainEventsClass.create_event(
		ev_id,
		world.server_tick,
		DomainEventsClass.EventType.ABILITY_STARTED,
		{
			"entity_id": entity_id,
			"ability_id": "dash",
			"direction": [dash_dir.x, dash_dir.y]
		}
	))
	return true

func step_tick() -> void:
	for entity_id in world.entities:
		var entity: EntityStateClass = world.entities[entity_id]
		if not entity.is_alive():
			continue

		# Process cooldowns
		for ability in entity.cooldowns.keys():
			var remaining: int = int(entity.cooldowns[ability])
			if remaining > 0:
				entity.cooldowns[ability] = remaining - 1
			else:
				entity.cooldowns.erase(ability)

		# Check dash state
		var dash_ticks: int = int(entity.custom_data.get("dash_ticks_left", 0))
		var iframe_ticks: int = int(entity.custom_data.get("dash_iframe_ticks_left", 0))
		if iframe_ticks > 0:
			entity.custom_data["dash_iframe_ticks_left"] = iframe_ticks - 1

		if dash_ticks > 0:
			entity.custom_data["dash_ticks_left"] = dash_ticks - 1
			var raw_dir = entity.custom_data.get("dash_dir", [1.0, 0.0])
			var dash_dir := Vector2(float(raw_dir[0]), float(raw_dir[1]))
			entity.velocity = dash_dir * DASH_SPEED
		else:
			# Normal movement
			var axis_arr = entity.custom_data.get("input_axis", [0.0, 0.0])
			var input_axis := Vector2(float(axis_arr[0]), float(axis_arr[1]))
			if input_axis.length_squared() > 1.0:
				input_axis = input_axis.normalized()

			if input_axis != Vector2.ZERO:
				var target_vel := input_axis * MOVE_SPEED
				entity.velocity = entity.velocity.move_toward(target_vel, ACCELERATION * TICK_DELTA)
			else:
				entity.velocity = entity.velocity.move_toward(Vector2.ZERO, FRICTION * TICK_DELTA)

		# Advance position
		entity.position += entity.velocity * TICK_DELTA
