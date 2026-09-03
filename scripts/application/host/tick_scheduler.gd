class_name TickScheduler
extends RefCounted

# res://scripts/application/host/tick_scheduler.gd
# Orchestrates 60Hz simulation ticking, command ingestion, and replication dispatch.

const SimulationHostClass = preload("res://scripts/simulation/simulation_host.gd")
const HostEndpointClass = preload("res://scripts/application/host/host_endpoint.gd")
const ClientEndpointClass = preload("res://scripts/application/client/client_endpoint.gd")

var simulation_host: SimulationHostClass
var host_endpoint: HostEndpointClass
var client_endpoint: ClientEndpointClass
var is_running: bool = true

func _init(p_sim_host: SimulationHostClass, p_host_ep: HostEndpointClass, p_client_ep: ClientEndpointClass) -> void:
	simulation_host = p_sim_host
	host_endpoint = p_host_ep
	client_endpoint = p_client_ep

func tick_frame() -> Dictionary:
	if not is_running:
		return {}

	# 1. Ingest commands from network
	if host_endpoint != null:
		host_endpoint.poll_and_enqueue_commands()

	# 2. Advance authoritative simulation
	var step_res := simulation_host.step_one_tick()

	# 3. Broadcast outputs to network
	if host_endpoint != null:
		host_endpoint.broadcast_step_result(step_res)

	# 4. Client polls incoming packets
	if client_endpoint != null:
		client_endpoint.poll_network()

	return step_res
