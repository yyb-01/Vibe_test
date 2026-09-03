class_name EntityViewRegistry
extends RefCounted

# res://scripts/presentation/entity_view_registry.gd
# Maps authoritative EntityId to Presentation Node Views and manages view lifecycles.

const ClientEndpointClass = preload("res://scripts/application/client/client_endpoint.gd")

var client_endpoint: ClientEndpointClass
var entity_views: Dictionary = {} # EntityId: int -> Node
var actors_parent_node: Node = null

func _init(p_client_ep: ClientEndpointClass, p_parent: Node = null) -> void:
	client_endpoint = p_client_ep
	actors_parent_node = p_parent
	if client_endpoint != null:
		client_endpoint.state_delta_received.connect(_on_state_delta)
		client_endpoint.domain_event_received.connect(_on_domain_event)

func register_view(entity_id: int, node: Node) -> void:
	if node != null:
		entity_views[entity_id] = node

func unregister_view(entity_id: int) -> void:
	entity_views.erase(entity_id)

func get_view(entity_id: int) -> Node:
	return entity_views.get(entity_id, null)

func _on_state_delta(delta: Dictionary) -> void:
	var raw_entities = delta.get("entities", [])
	if raw_entities is Array:
		for e_dict in raw_entities:
			if e_dict is Dictionary:
				var e_id: int = int(e_dict.get("entity_id", 0))
				var view: Node = entity_views.get(e_id, null)
				if view != null and is_instance_valid(view):
					_update_view_from_state(view, e_dict)

func _update_view_from_state(view: Node, state_dict: Dictionary) -> void:
	var pos_arr = state_dict.get("position", null)
	if pos_arr is Array and pos_arr.size() >= 2 and "position" in view:
		var target_pos := Vector2(float(pos_arr[0]), float(pos_arr[1]))
		# Soft lerp or direct set
		view.position = target_pos

	var hp = state_dict.get("health", null)
	if hp != null and "current_health" in view:
		view.current_health = float(hp)

func _on_domain_event(ev: Dictionary) -> void:
	var ev_type: int = int(ev.get("event_type", 0))
	var payload: Dictionary = ev.get("payload", {})

	match ev_type:
		2002, 2006: # ENTITY_DESPAWNED or ENTITY_DIED
			var e_id: int = int(payload.get("entity_id", 0))
			var view: Node = entity_views.get(e_id, null)
			if view != null and is_instance_valid(view):
				if view.has_method("die"):
					view.die()
				else:
					view.queue_free()
			entity_views.erase(e_id)
