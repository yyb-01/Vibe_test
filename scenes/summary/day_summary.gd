class_name DaySummary
extends Control

# res://scenes/summary/day_summary.gd
# Day summary settlement UI per Section F.3 & F.4

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var result_label: Label = $Panel/VBoxContainer/ResultLabel
@onready var stats_container: VBoxContainer = $Panel/VBoxContainer/StatsContainer
@onready var continue_btn: Button = $Panel/VBoxContainer/ContinueBtn

func _ready() -> void:
	if continue_btn != null:
		continue_btn.pressed.connect(_on_continue_pressed)
	update_display()

func update_display() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return
		
	var result: Dictionary = gm.day_result
	var day_num: int = result.get("day", gm.day)
	var survived: bool = result.get("survived", true)
	
	if title_label != null:
		title_label.text = "DAY %d SUMMARY" % day_num
		
	if result_label != null:
		if survived:
			result_label.text = "SURVIVED! Base Defended Successfully."
			result_label.modulate = Color(0.3, 0.9, 0.4)
		else:
			var reason = result.get("reason", &"failed")
			result_label.text = "DEFEATED: %s\nRolling back to day start. 10%% resources converted to Legacy Scrap." % str(reason)
			result_label.modulate = Color(0.95, 0.3, 0.3)
			
	if stats_container != null:
		for child in stats_container.get_children():
			child.queue_free()
			
		var stats: Dictionary = result.get("stats", {})
		
		var lbl_zombies := Label.new()
		lbl_zombies.text = "Zombies Eliminated: %d" % stats.get("zombies_killed", 0)
		stats_container.add_child(lbl_zombies)
		
		var lbl_ammo := Label.new()
		lbl_ammo.text = "Ammunition Expended: %d" % stats.get("ammo_consumed", 0)
		stats_container.add_child(lbl_ammo)
		
		var lbl_lost := Label.new()
		lbl_lost.text = "Structures Lost: %d" % stats.get("structures_lost", 0)
		stats_container.add_child(lbl_lost)
		
		var harvested: Dictionary = stats.get("items_harvested", {})
		if not harvested.is_empty():
			var harvest_text = "Resources Farmed: "
			for k in harvested:
				harvest_text += "%s: %d, " % [k, harvested[k]]
			var lbl_harvest := Label.new()
			lbl_harvest.text = harvest_text.trim_suffix(", ")
			stats_container.add_child(lbl_harvest)
			
		if not survived:
			var lbl_scrap := Label.new()
			lbl_scrap.text = "Legacy Scrap Earned: +%d (Total: %d)" % [result.get("legacy_scrap_earned", 0), gm.legacy_scrap]
			lbl_scrap.modulate = Color(1.0, 0.85, 0.2)
			stats_container.add_child(lbl_scrap)

func _on_continue_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.confirm_summary()
