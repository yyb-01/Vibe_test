class_name WaveController
extends Node2D

# res://scenes/defense/wave_controller.gd
# Manages night wave spawning, tracking, victory/defeat conditions per Section E.2

const WaveDataClass = preload("res://scripts/data/wave_data.gd")
const WaveSpawnEntryDataClass = preload("res://scripts/data/wave_spawn_entry_data.gd")
const ZombieClass = preload("res://entities/zombies/zombie.gd")
const GameStateMachine = preload("res://scripts/core/game_state_machine.gd")

@export var wave_data: WaveDataClass
@export var spawner: Node2D
@export var enemies_container: Node2D
@export var night_modulate: CanvasModulate

var is_wave_active: bool = false
var total_to_spawn: int = 0
var spawned_count: int = 0
var alive_count: int = 0

var _entry_states: Array[Dictionary] = []
var _is_completed: bool = false
var _wave_token: int = 0

func _ready() -> void:
	if spawner == null:
		spawner = find_child("ZombieSpawner", true, false) as Node2D
	if enemies_container == null:
		enemies_container = find_child("Enemies", true, false) as Node2D
		if enemies_container == null:
			enemies_container = self

func start_wave(p_wave_data: WaveDataClass = null) -> void:
	if p_wave_data != null:
		wave_data = p_wave_data
	if wave_data == null:
		wave_data = load("res://data/waves/wave_day_1.tres")
		
	_clear_enemies()
	total_to_spawn = 0
	for entry in wave_data.entries:
		var base_count: int = int(entry.count) if entry != null else 0
		var gm := get_node_or_null("/root/GameManager")
		total_to_spawn += gm.get_scaled_zombie_count(base_count) if gm != null else base_count
	spawned_count = 0
	alive_count = 0
	is_wave_active = true
	_is_completed = false
	_wave_token += 1
	
	# Night lighting transition
	if night_modulate != null:
		var tween = create_tween()
		tween.tween_property(night_modulate, "color", Color(0.25, 0.3, 0.5, 1.0), 1.5)
		
	_entry_states.clear()
	for entry in wave_data.entries:
		var gm := get_node_or_null("/root/GameManager")
		var count: int = int(entry.count) if entry != null else 0
		count = gm.get_scaled_zombie_count(count) if gm != null else count
		_entry_states.append({
			"entry": entry,
			"remaining": count,
			"timer": entry.start_delay if "start_delay" in entry else 0.0,
			"interval": entry.spawn_interval if "spawn_interval" in entry else 1.0
		})
		
	var eb = get_node_or_null("/root/EventBus")
	if eb != null:
		eb.wave_started.emit(wave_data.day)
		eb.wave_progress.emit(spawned_count, total_to_spawn, alive_count)

func _process(delta: float) -> void:
	if not is_wave_active or _is_completed:
		return
		
	var all_entries_done: bool = true
	for state in _entry_states:
		if state["remaining"] > 0:
			all_entries_done = false
			state["timer"] -= delta
			if state["timer"] <= 0.0:
				if _spawn_from_entry(state):
					state["remaining"] -= 1
					state["timer"] = state["interval"]
				else:
					state["timer"] = 0.25
				
	# Check wave victory (all spawned and all dead)
	if all_entries_done and alive_count <= 0 and spawned_count >= total_to_spawn:
		_on_wave_victory()

func _spawn_from_entry(state: Dictionary) -> bool:
	if spawner == null or not spawner.has_method("spawn_zombie"):
		return false
	var entry = state["entry"]
	var dir_enum: int = entry.entry_direction if "entry_direction" in entry else 4
	
	var zombie = spawner.spawn_zombie(dir_enum, enemies_container)
	if zombie != null:
		spawned_count += 1
		alive_count += 1
		if zombie.has_signal("zombie_died"):
			zombie.zombie_died.connect(_on_zombie_died)
		var eb = get_node_or_null("/root/EventBus")
		if eb != null:
			eb.wave_progress.emit(spawned_count, total_to_spawn, alive_count)
		return true
	return false

func _on_zombie_died(_zombie: Node) -> void:
	alive_count = maxi(0, alive_count - 1)
	var eb = get_node_or_null("/root/EventBus")
	if eb != null:
		eb.wave_progress.emit(spawned_count, total_to_spawn, alive_count)
	
	if spawned_count >= total_to_spawn and alive_count <= 0:
		_on_wave_victory()

func _on_wave_victory() -> void:
	if _is_completed:
		return
	_is_completed = true
	is_wave_active = false
	
	# Restore lighting
	if night_modulate != null:
		var tween = create_tween()
		tween.tween_property(night_modulate, "color", Color(1.0, 1.0, 1.0, 1.0), 2.0)
		
	var eb = get_node_or_null("/root/EventBus")
	if eb != null:
		eb.wave_completed.emit(wave_data.day if wave_data != null else 1)
	
	# Transition game state to DAY_SUMMARY on success
	var delay: float = wave_data.completion_delay if wave_data != null else 2.0
	var token := _wave_token
	get_tree().create_timer(delay).timeout.connect(func():
		if token != _wave_token:
			return
		var gm = get_node_or_null("/root/GameManager")
		if gm != null and gm.current_state == GameStateMachine.State.NIGHT_DEFENSE:
			gm.complete_night(true)
	)

func _clear_enemies() -> void:
	if enemies_container == null:
		return
	for child in enemies_container.get_children():
		if child is ZombieClass:
			child.queue_free()
