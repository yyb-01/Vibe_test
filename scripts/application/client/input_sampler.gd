class_name InputSampler
extends RefCounted

# res://scripts/application/client/input_sampler.gd
# Samples hardware inputs into serializable command envelopes.

const SimulationCommandsClass = preload("res://scripts/simulation/commands/simulation_commands.gd")
const CommandGatewayClass = preload("res://scripts/application/client/command_gateway.gd")

var gateway: CommandGatewayClass
var player_id: int = 1
var controlled_entity_id: int = 0

var last_move_axis: Vector2 = Vector2.ZERO
var last_aim_angle: float = 0.0

func _init(p_gateway: CommandGatewayClass, p_player_id: int = 1, p_controlled_entity_id: int = 0) -> void:
	gateway = p_gateway
	player_id = p_player_id
	controlled_entity_id = p_controlled_entity_id

func sample_continuous_inputs(predicted_tick: int, aim_world_dir: Vector2) -> void:
	if gateway == null:
		return

	var axis := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if axis != last_move_axis:
		last_move_axis = axis
		var cmd = SimulationCommandsClass.create_move_intent(player_id, controlled_entity_id, axis, 0, predicted_tick)
		gateway.submit(cmd)

	var angle := aim_world_dir.angle()
	if not is_equal_approx(angle, last_aim_angle):
		last_aim_angle = angle
		var cmd = SimulationCommandsClass.create_aim_intent(player_id, controlled_entity_id, angle, 0, predicted_tick)
		gateway.submit(cmd)

func send_action(action_id: StringName, pressed: bool, target_hint: Vector2, predicted_tick: int) -> int:
	if gateway == null:
		return 0
	var cmd = SimulationCommandsClass.create_ability_command(
		player_id,
		controlled_entity_id,
		action_id,
		pressed,
		target_hint,
		0,
		predicted_tick
	)
	return gateway.submit(cmd)
