extends Node

const GEM := preload("res://scenes/items/exp_gem.tscn")
const MENU := preload("res://scenes/ui/main_menu.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	ObjectPoolManager.configure_pool(GEM, 1, 1, self)
	assert(SpatialGrid.item_cells.is_empty())
	var gem := ObjectPoolManager.spawn(GEM, Vector2.ZERO) as ExpGem
	ObjectPoolManager.release(gem)
	ObjectPoolManager.release(gem)
	assert(ObjectPoolManager.spawn(GEM, Vector2.ZERO) == null)
	await get_tree().process_frame
	assert(ObjectPoolManager.spawn(GEM, Vector2.ZERO) == gem)
	await get_tree().process_frame
	assert(gem.can_process() and not gem.get_node("CollisionShape2D").disabled)
	assert(gem.collision_layer == 8 and gem.collision_mask == 1)
	ObjectPoolManager.release(gem)
	ObjectPoolManager.clear()
	await get_tree().process_frame
	ObjectPoolManager.register_pool("exp_gem", GEM, self)
	for index in 1000:
		gem = ObjectPoolManager.acquire("exp_gem", Vector2.ZERO) as ExpGem
		gem.set_exp_amount(index + 1)
	await get_tree().process_frame
	assert(SpatialGrid.item_cells.size() == 1 and not SpatialGrid.is_clustering)
	gem = SpatialGrid.item_cells.keys()[0] as ExpGem
	assert(gem.exp_amount == 500500)
	ObjectPoolManager.clear()
	SpatialGrid.clear()
	await get_tree().process_frame
	assert(await _check_modals())
	assert(await _check_scenes())
	print("Runtime safety passed: pool quarantine, 1000 gems, modals, four map cards, fallback, return to menu.")
	get_tree().quit()

func _check_modals() -> bool:
	var first := Node.new()
	var queued := Node.new()
	var callback_owner := Node.new()
	add_child(first)
	add_child(queued)
	add_child(callback_owner)
	ModalManager.request(first, func(): pass)
	ModalManager.request(queued, callback_owner.queue_free)
	callback_owner.free()
	ModalManager.release(first)
	await get_tree().process_frame
	assert(not get_tree().paused and not ModalManager.has_active_modal())
	get_tree().paused = true
	ModalManager.release(first)
	assert(not get_tree().paused)
	first.free()
	queued.free()
	return true

func _check_scenes() -> bool:
	var menu := MENU.instantiate() as MainMenu
	get_tree().paused = true
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	assert(not get_tree().paused)
	assert(menu.map_grid.get_node("MapCard1").has_focus())
	var sheet: Texture2D = menu.CHARACTER_SHEETS[0]
	assert(menu._portrait(sheet).region == Rect2(Vector2.ZERO, sheet.get_size() / 4.0))
	for index in 5:
		await get_tree().process_frame
		await get_tree().process_frame
		if index < 4:
			var button := menu.map_grid.get_node("MapCard%d" % (index + 1)) as Button
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = button.get_global_rect().get_center()
			click.pressed = true
			get_viewport().push_input(click, true)
			click = click.duplicate() as InputEventMouseButton
			click.pressed = false
			get_viewport().push_input(click, true)
		else:
			menu._load_map("res://scenes/maps/missing.tscn")
		await get_tree().process_frame
		await get_tree().process_frame
		var map := get_tree().current_scene
		assert(map.scene_file_path == "res://scenes/maps/map_%d.tscn" % (index + 1 if index < 4 else 1))
		assert(RunStats.run_active and not get_tree().paused)
		var player := get_tree().get_first_node_in_group("player") as Player
		player.auto_fire_enabled = false
		player.invulnerable = true
		assert(await _check_player(player))
		var hud := map.get_node("HUD") as HUD
		assert(not hud.inventory_slots.get_global_rect().intersects(hud.build_toggle_button.get_global_rect()))
		assert(hud.weapon_slots.get_child_count() == 7 and hud.passive_slots.get_child_count() == 7)
		hud._show_return_confirmation()
		hud._confirm_return_to_menu()
		await get_tree().process_frame
		await get_tree().process_frame
		menu = get_tree().current_scene as MainMenu
		assert(menu != null and not get_tree().paused)
		assert(not AudioManager.bgm_player.playing)
		for sound_player in AudioManager.players:
			assert(not sound_player.playing)
		assert(ObjectPoolManager.active_pool.is_empty() and SpatialGrid.entity_cells.is_empty())
	return true

func _check_player(player: Player) -> bool:
	player.magnet_bonus = 60.0
	var pickup := ObjectPoolManager.acquire("exp_gem", player.global_position) as ExpGem
	assert(pickup.magnet_range >= 210.0)
	var previous_exp := player.current_exp
	for frame in 4:
		await get_tree().physics_frame
		await get_tree().process_frame
	assert(player.current_exp == previous_exp + 10)
	assert(pickup.get_meta("_pool_release_pending"))
	var origin := player.global_position
	player.velocity = Vector2(100000, 0)
	player._move_safely(300.0, 1.0 / 60.0)
	assert(player.global_position.distance_to(origin) <= 21.01)
	player.global_position = origin
	player.dash_time = 0.001
	player.dash_direction = Vector2.RIGHT
	player._physics_process(1.0 / 60.0)
	assert(player.velocity == Vector2.ZERO and player.dash_direction == Vector2.ZERO)
	for shot in 100:
		player.play_weapon_feedback("Pistol", origin + Vector2.RIGHT * 100)
	assert(player.muzzle_flashes.size() <= 12)
	var removed := Node2D.new()
	removed.free()
	assert(not player._is_active_enemy(removed))
	var mission := get_tree().get_first_node_in_group("mission_event") as MissionEvent
	mission._activate()
	get_tree().paused = true
	assert(mission.choice_layer.layer == 128 and mission.choice_layer.can_process())
	var buttons := mission.choice_layer.find_children("*", "Button", true, false)
	assert(buttons.size() == 3 and buttons[0].can_process())
	buttons[0].pressed.emit()
	await get_tree().process_frame
	assert(not player.input_locked and not get_tree().paused)
	return true
