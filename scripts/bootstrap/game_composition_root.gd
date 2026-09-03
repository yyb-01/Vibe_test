class_name GameCompositionRoot
extends Node

# res://scripts/bootstrap/game_composition_root.gd
# Top-level composition root wiring simulation host, loopback transport, endpoints, and presentation.

const SimulationHostClass = preload("res://scripts/simulation/simulation_host.gd")
const SerializedLoopbackTransportClass = preload("res://scripts/infrastructure/transport/serialized_loopback_transport.gd")
const MessageCodecClass = preload("res://scripts/application/protocol/message_codec.gd")
const HostEndpointClass = preload("res://scripts/application/host/host_endpoint.gd")
const CommandGatewayClass = preload("res://scripts/application/client/command_gateway.gd")
const ClientEndpointClass = preload("res://scripts/application/client/client_endpoint.gd")
const InputSamplerClass = preload("res://scripts/application/client/input_sampler.gd")
const TickSchedulerClass = preload("res://scripts/application/host/tick_scheduler.gd")
const EntityViewRegistryClass = preload("res://scripts/presentation/entity_view_registry.gd")
const CombatPresenterClass = preload("res://scripts/presentation/event_presenters/combat_presenter.gd")
const LocalSaveStoreClass = preload("res://scripts/infrastructure/persistence/local_save_store.gd")
const EntityStateClass = preload("res://scripts/simulation/model/entity_state.gd")

var simulation_host: SimulationHostClass
var client_transport: SerializedLoopbackTransportClass
var host_transport: SerializedLoopbackTransportClass
var codec: MessageCodecClass

var host_endpoint: HostEndpointClass
var command_gateway: CommandGatewayClass
var client_endpoint: ClientEndpointClass
var input_sampler: InputSamplerClass
var tick_scheduler: TickSchedulerClass

var entity_view_registry: EntityViewRegistryClass
var combat_presenter: CombatPresenterClass
var save_store: LocalSaveStoreClass

var is_active: bool = false

func _init() -> void:
	setup_architecture()

func setup_architecture() -> void:
	codec = MessageCodecClass.new()
	var pair := SerializedLoopbackTransportClass.create_pair(1, 0)
	client_transport = pair[0]
	host_transport = pair[1]

	simulation_host = SimulationHostClass.new()
	host_endpoint = HostEndpointClass.new(host_transport, codec, simulation_host)

	command_gateway = CommandGatewayClass.new(client_transport, codec, 1)
	client_endpoint = ClientEndpointClass.new(client_transport, codec, command_gateway)

	input_sampler = InputSamplerClass.new(command_gateway, 1, 100) # Player entity ID: 100
	tick_scheduler = TickSchedulerClass.new(simulation_host, host_endpoint, client_endpoint)

	entity_view_registry = EntityViewRegistryClass.new(client_endpoint)
	combat_presenter = CombatPresenterClass.new(client_endpoint, entity_view_registry)
	save_store = LocalSaveStoreClass.new()

	# Register initial player entity in simulation host
	var player_state := EntityStateClass.new(100, &"player", 1)
	player_state.health = 100.0
	player_state.max_health = 100.0
	simulation_host.world.add_entity(player_state)
	simulation_host.world.players[1].controlled_entity_id = 100

	is_active = true

func _physics_process(_delta: float) -> void:
	if not is_active or tick_scheduler == null:
		return
	tick_scheduler.tick_frame()

func link_presentation_nodes(vfx_node: Node, cam_node: Node, actors_node: Node) -> void:
	if combat_presenter != null:
		combat_presenter.vfx_pool = vfx_node
		combat_presenter.camera_trauma = cam_node
	if entity_view_registry != null:
		entity_view_registry.actors_parent_node = actors_node
