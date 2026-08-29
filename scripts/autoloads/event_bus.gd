extends Node

signal player_health_changed(current_hp: int, max_hp: int)
signal exp_changed(current_exp: int, required_exp: int, level: int)

signal zombie_died(zombie_pos: Vector2)
signal level_up()

signal perk_selection_requested()
signal perk_selected(perk: Resource)
signal camera_shake_requested()

signal gold_changed(total_gold: int)
signal game_over(is_victory: bool)
signal inventory_updated(weapons: Array, passives: Array)
signal survivor_rescued(total_rescued: int)
signal quest_completed(quest_id: String, reward: int)
signal supply_cache_opened(total_opened: int)
signal wave_started(wave: int)
