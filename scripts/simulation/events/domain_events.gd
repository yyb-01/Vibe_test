class_name DomainEvents
extends RefCounted

# res://scripts/simulation/events/domain_events.gd
# Definitive DTO domain event types containing only value types and EntityId.

enum EventType {
	ENTITY_SPAWNED = 2001,
	ENTITY_DESPAWNED = 2002,
	ABILITY_STARTED = 2003,
	PROJECTILE_SPAWNED = 2004,
	DAMAGE_RESOLVED = 2005,
	ENTITY_DIED = 2006,
	STRUCTURE_PLACED = 2007,
	STRUCTURE_REMOVED = 2008,
	INVENTORY_COMMITTED = 2009,
	PHASE_CHANGED = 2010,
	WAVE_STARTED = 2011,
	WAVE_PROGRESS = 2012,
	WAVE_COMPLETED = 2013,
	SAVE_COMMITTED = 2014
}

static func create_event(event_id: int, server_tick: int, event_type: int, payload: Dictionary) -> Dictionary:
	return {
		"event_id": event_id,
		"server_tick": server_tick,
		"event_type": event_type,
		"payload": payload
	}
