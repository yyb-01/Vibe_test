extends Node

signal player_health_changed(current_hp: int, max_hp: int)
signal ammo_changed(current_mag: int, reserve_ammo: int)

signal wave_started(wave_number: int)
signal wave_cleared(next_wave_delay: float)
signal zombie_count_changed(remaining_zombies: int)
signal zombie_died(zombie_pos: Vector2)

signal perk_selection_requested()
signal perk_selected(perk: Resource)
