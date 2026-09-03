class_name ExpeditionHUD
extends Control

# res://ui/hud/expedition_hud.gd
# HUD for EXPEDITION phase showing bag inventory, extraction guidance, and hold progress

@onready var bag_label: Label = $Panel/VBoxContainer/BagLabel
@onready var extract_prompt_label: Label = $ExtractionPanel/VBoxContainer/PromptLabel
@onready var extract_progress_bar: ProgressBar = $ExtractionPanel/VBoxContainer/ProgressBar
@onready var extract_button: Button = $ExtractionPanel/VBoxContainer/ExtractButton
@onready var extraction_panel: Panel = $ExtractionPanel
@onready var distance_label: Label = $DistanceLabel

var _current_extraction_zone: ExtractionZone = null
var _player_ref: Node2D = null

func _ready() -> void:
	if extract_button != null:
		extract_button.pressed.connect(_on_extract_button_pressed)
		
	var eb = get_node_or_null("/root/EventBus")
	if eb != null:
		eb.inventory_changed.connect(_on_inventory_changed)
		
	update_bag_display()
	set_extraction_active(false)

func _process(_delta: float) -> void:
	if not visible:
		return
		
	# Update distance indicator to extraction zone
	if _player_ref != null and distance_label != null:
		var target_pos := Vector2.ZERO
		if _current_extraction_zone != null:
			target_pos = _current_extraction_zone.global_position
		var dist: float = _player_ref.global_position.distance_to(target_pos)
		if dist > 80.0:
			distance_label.visible = true
			distance_label.text = "🚁 Extraction Point: %dm away" % int(dist / 10.0)
		else:
			distance_label.visible = false

func setup_player(p_player: Node2D, p_extraction_zone: ExtractionZone = null) -> void:
	_player_ref = p_player
	_current_extraction_zone = p_extraction_zone
	if _current_extraction_zone != null:
		if not _current_extraction_zone.extraction_progress.is_connected(_on_extraction_progress):
			_current_extraction_zone.extraction_progress.connect(_on_extraction_progress)
		if not _current_extraction_zone.extraction_started.is_connected(_on_extraction_started):
			_current_extraction_zone.extraction_started.connect(_on_extraction_started)
		if not _current_extraction_zone.extraction_canceled.is_connected(_on_extraction_canceled):
			_current_extraction_zone.extraction_canceled.connect(_on_extraction_canceled)

func update_bag_display() -> void:
	if bag_label == null:
		return
	var im = get_node_or_null("/root/InventoryManager")
	if im == null or im.expedition_bag == null:
		bag_label.text = "🎒 Bag: Empty"
		return
		
	var slots = im.expedition_bag.slots
	var items_text: Array[String] = []
	for slot in slots:
		var item_id = slot.get("item_id", &"")
		var amount = slot.get("amount", 0)
		if item_id != &"" and amount > 0:
			items_text.append("%s: %d" % [String(item_id).capitalize(), amount])
			
	if items_text.is_empty():
		bag_label.text = "🎒 Bag: Empty (Harvest Wood/Stone/Food)"
	else:
		bag_label.text = "🎒 Bag: " + ", ".join(items_text)

func set_extraction_active(p_inside: bool) -> void:
	if extraction_panel != null:
		extraction_panel.visible = p_inside
	if not p_inside and extract_progress_bar != null:
		extract_progress_bar.value = 0.0

func _on_inventory_changed(_container: StringName) -> void:
	update_bag_display()

func _on_extraction_started() -> void:
	set_extraction_active(true)
	if extract_prompt_label != null:
		extract_prompt_label.text = "RETURNING TO BASE..."

func _on_extraction_progress(current_time: float, total_time: float) -> void:
	set_extraction_active(true)
	if extract_progress_bar != null:
		extract_progress_bar.value = (current_time / total_time) * 100.0
	if extract_prompt_label != null:
		extract_prompt_label.text = "RETURNING... Hold [E] (%.1fs / %.1fs)" % [current_time, total_time]

func _on_extraction_canceled() -> void:
	if extract_progress_bar != null:
		extract_progress_bar.value = 0.0
	if extract_prompt_label != null:
		extract_prompt_label.text = "EXTRACTION ZONE: Hold [E] or Click to Return"

func _on_extract_button_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.complete_expedition(true)
