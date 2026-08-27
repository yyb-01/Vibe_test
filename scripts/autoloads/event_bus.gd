extends Node

signal player_health_changed(current_hp: int, max_hp: int)
signal exp_changed(current_exp: int, required_exp: int, level: int)

signal zombie_died(zombie_pos: Vector2)
signal level_up()

signal perk_selection_requested()
signal perk_selected(perk: Resource)
signal camera_shake_requested()
