class_name PlayerState
extends RefCounted

# res://scripts/simulation/model/player_state.gd
# Authoritative state of a player connection in the simulation.

var player_id: int = 1
var controlled_entity_id: int = 0
var last_processed_sequence: int = 0
var expedition_bag_slots: Array[Dictionary] = [] # Array of {"item_id": StringName, "amount": int}
var equipment: Dictionary = {
	"primary": "pistol"
}

func _init(p_player_id: int = 1, p_controlled_entity_id: int = 0) -> void:
	player_id = p_player_id
	controlled_entity_id = p_controlled_entity_id
	expedition_bag_slots = []
	for i in range(8):
		expedition_bag_slots.append({"item_id": &"", "amount": 0})

func to_dict() -> Dictionary:
	var slots_data: Array = []
	for slot in expedition_bag_slots:
		slots_data.append({
			"item_id": str(slot.get("item_id", &"")),
			"amount": int(slot.get("amount", 0))
		})
	return {
		"player_id": player_id,
		"controlled_entity_id": controlled_entity_id,
		"last_processed_sequence": last_processed_sequence,
		"expedition_bag_slots": slots_data,
		"equipment": equipment.duplicate(true)
	}

func from_dict(d: Dictionary) -> void:
	if not (d is Dictionary):
		return
	player_id = int(d.get("player_id", 1))
	controlled_entity_id = int(d.get("controlled_entity_id", 0))
	last_processed_sequence = int(d.get("last_processed_sequence", 0))
	equipment = d.get("equipment", {"primary": "pistol"}).duplicate(true)

	expedition_bag_slots = []
	var raw_slots = d.get("expedition_bag_slots", [])
	if raw_slots is Array:
		for s in raw_slots:
			if s is Dictionary:
				expedition_bag_slots.append({
					"item_id": StringName(s.get("item_id", "")),
					"amount": int(s.get("amount", 0))
				})
	if expedition_bag_slots.size() < 8:
		for i in range(8 - expedition_bag_slots.size()):
			expedition_bag_slots.append({"item_id": &"", "amount": 0})
