class_name CombatPresenter
extends RefCounted

# res://scripts/presentation/event_presenters/combat_presenter.gd
# Listens to authoritative domain events to trigger local juice, VFX, hit flashes, and camera trauma.

const ClientEndpointClass = preload("res://scripts/application/client/client_endpoint.gd")
const EntityViewRegistryClass = preload("res://scripts/presentation/entity_view_registry.gd")
const JuiceHelperClass = preload("res://scripts/systems/juice_helper.gd")

var client_endpoint: ClientEndpointClass
var view_registry: EntityViewRegistryClass
var vfx_pool: Node = null
var camera_trauma: Node = null

func _init(p_client_ep: ClientEndpointClass, p_view_reg: EntityViewRegistryClass, p_vfx: Node = null, p_cam: Node = null) -> void:
	client_endpoint = p_client_ep
	view_registry = p_view_reg
	vfx_pool = p_vfx
	camera_trauma = p_cam

	if client_endpoint != null:
		client_endpoint.domain_event_received.connect(_on_domain_event)

func _on_domain_event(ev: Dictionary) -> void:
	var ev_type: int = int(ev.get("event_type", 0))
	var payload: Dictionary = ev.get("payload", {})

	match ev_type:
		2003: # ABILITY_STARTED
			var ability = payload.get("ability_id", "")
			var e_id = int(payload.get("entity_id", 0))
			var view = view_registry.get_view(e_id) if view_registry != null else null
			if view != null and is_instance_valid(view):
				if ability == "dash" and vfx_pool != null and vfx_pool.has_method("spawn_ghost_trail"):
					var vis = view.find_child("Visual", true, false)
					if vis is AnimatedSprite2D:
						vfx_pool.spawn_ghost_trail(vis, view.position)

		2005: # DAMAGE_RESOLVED
			var target_id = int(payload.get("target_entity_id", 0))
			var damage = float(payload.get("damage", 0.0))
			var is_crit = bool(payload.get("is_critical", false))
			var target_view = view_registry.get_view(target_id) if view_registry != null else null

			if target_view != null and is_instance_valid(target_view):
				# Hit flash
				var vis = target_view.find_child("Visual", true, false)
				if vis != null:
					JuiceHelperClass.apply_hit_flash(vis)

				# Floating damage text & impact VFX
				if vfx_pool != null:
					if vfx_pool.has_method("spawn_damage_text"):
						vfx_pool.spawn_damage_text(target_view.position, damage, is_crit)
					if vfx_pool.has_method("spawn_impact"):
						vfx_pool.spawn_impact(target_view.position, Vector2.UP)

			# Camera trauma on critical or player hits
			if is_crit and camera_trauma != null and camera_trauma.has_method("add_trauma"):
				camera_trauma.add_trauma(0.2)
