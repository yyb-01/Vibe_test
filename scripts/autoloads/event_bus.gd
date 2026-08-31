extends Node

signal player_health_changed(current_hp: int, max_hp: int)
signal exp_changed(current_exp: int, required_exp: int, level: int)

signal zombie_died(zombie_pos: Vector2)
signal level_up()

signal perk_selection_requested()
signal perk_selected(perk: Resource)
signal camera_shake_requested()

signal gold_changed(total_gold: int)
signal scrap_changed(total_scrap: int)
signal wave_shop_requested(wave: int)
signal game_over(is_victory: bool)
signal inventory_updated(weapons: Array, passives: Array)
signal survivor_rescued(total_rescued: int)
signal companion_recruited(role: String)
signal quest_completed(quest_id: String, reward: int)
signal supply_cache_opened(total_opened: int)
signal wave_started(wave: int)
signal boss_status_changed(boss_name: String, health_ratio: float, phase: int)
signal boss_attack_warning(attack_name: String, active: bool)
signal mission_status_changed(title: String, status: String, progress: float)
signal mission_completed(title: String, reward: int)
signal boss_defeated()
signal combat_modifier_changed(title: String, description: String, duration: float)
