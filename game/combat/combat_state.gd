class_name CombatState
extends RefCounted

var health_by_entity: Dictionary = {}
var enemies: Dictionary = {}
var attacks: Dictionary = {}
var defeated_entities: Dictionary = {}
var core_cell: Vector2i
var protected_target_cell: Vector2i
var navigation_revision: int = -1
var revision: int = 0
