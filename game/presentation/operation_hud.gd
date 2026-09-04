class_name OperationHUD
extends Control

const OperationStateClass = preload("res://game/operation/operation_state.gd")

@onready var presenter = get_node("../OperationPresenter")
@onready var controller = get_node("../../OperationController")
@onready var terrain_status: Label = $StatusPanel/Layout/TerrainStatus
@onready var objective_status: Label = $StatusPanel/Layout/ObjectiveStatus
@onready var threat_status: Label = $StatusPanel/Layout/ThreatStatus
@onready var inventory_status: Label = $StatusPanel/Layout/InventoryStatus
@onready var build_status: Label = $StatusPanel/Layout/BuildStatus
@onready var blueprint_select: OptionButton = $StatusPanel/Layout/BlueprintSelect
@onready var extraction_status: Label = $StatusPanel/Layout/ExtractionStatus
@onready var prompt: Label = $StatusPanel/Layout/Prompt
@onready var action_status: Label = $StatusPanel/Layout/ActionStatus
@onready var build_wall: Button = $StatusPanel/Layout/BuildWall
@onready var confirm_build: Button = $StatusPanel/Layout/ConfirmBuild
@onready var cancel_build: Button = $StatusPanel/Layout/CancelBuild
@onready var extract: Button = $StatusPanel/Layout/Extract
@onready var high_contrast: CheckButton = $StatusPanel/Layout/HighContrast
@onready var status_panel: PanelContainer = $StatusPanel

var _preview_cell := Vector2i.ZERO
var _preview_revision := -1
var _action_sequence := 0
var _high_contrast := false
var _blueprint_signature := ""

func _ready() -> void:
	build_wall.pressed.connect(_on_build_wall_pressed)
	confirm_build.pressed.connect(_on_confirm_build_pressed)
	cancel_build.pressed.connect(_on_cancel_build_pressed)
	extract.pressed.connect(_on_extract_pressed)
	high_contrast.toggled.connect(_on_high_contrast_toggled)
	blueprint_select.item_selected.connect(_on_blueprint_selected)
	_apply_contrast(false)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if presenter == null:
		return
	var model: Dictionary = presenter.read_model()
	var objective: Dictionary = model.get("objective", {})
	var threat: Dictionary = model.get("threat", {})
	var inventory: Dictionary = model.get("inventory", {})
	var build: Dictionary = model.get("build", {})
	var extraction: Dictionary = model.get("extraction", {})
	_refresh_blueprints()
	var active := int(model.get("lifecycle", -1)) == OperationStateClass.Lifecycle.ACTIVE
	var objective_done := int(objective.get("state", -1)) == 3
	var terrain_id := StringName(model.get("terrain_id", &""))
	var terrain = controller.build.catalog.get_definition(terrain_id) if controller != null and controller.build.catalog != null else null
	terrain_status.text = "지형: %s" % (String(terrain.display_name) if terrain != null else String(terrain_id))
	objective_status.text = "목표 [%s]: %d/%d %s" % [String(objective.get("id", "-")), int(objective.get("progress", 0)), int(objective.get("target", 0)), "[완료]" if objective_done else "[진행]"]
	var event_id: String = String(threat.get("event_id", ""))
	var event_text := "없음" if event_id.is_empty() else "%s / %d틱" % [event_id, int(threat.get("remaining", 0))]
	threat_status.text = "위협: 압박 %d (등급 %d)\n텔레그래프: %s" % [int(threat.get("pressure", 0)), int(threat.get("tier", 0)), event_text]
	inventory_status.text = "물자: 운반 %s | 확보 %s" % [_items_text(inventory.get("carried", {})), _items_text(inventory.get("secured", {}))]
	var preview_text := _reason_text(StringName(build.get("preview_reason", &"")))
	var route_text := "경로 경고: 현재 적 경로와 겹침" if build.get("route_warning", false) else "경로: 현재 적 경로와 분리"
	var selected_id := String(build.get("selected_definition_id", &"wall"))
	var cost_item_id := String(build.get("cost_item_id", &"wood"))
	build_status.text = "건축 %s: %s %d (가용 %d)\nPreview: %s\n%s" % [selected_id, cost_item_id, int(build.get("cost_amount", 0)), int(build.get("available_amount", 0)), preview_text, route_text]
	build_wall.text = "Preview %s" % selected_id
	confirm_build.text = "Confirm %s" % selected_id
	extraction_status.text = "탈출: [가능]" if extraction.get("eligible", false) else "탈출: [잠김 — 목표 완료 필요]"
	prompt.text = "안내: " + String(model.get("prompt", {}).get("text", ""))
	build_wall.disabled = not active
	confirm_build.disabled = not active or not bool(build.get("preview_accepted", false))
	cancel_build.disabled = not bool(build.get("preview_accepted", false)) and String(build.get("preview_reason", "")).is_empty()
	extract.disabled = not active or not extraction.get("eligible", false)

func _on_build_wall_pressed() -> void:
	if controller == null or controller.build.state == null:
		return
	var cell: Vector2i = presenter.read_model().get("player", {}).get("cell", Vector2i.ZERO) + Vector2i(1, 0)
	_preview_cell = cell
	_preview_revision = controller.build.state.grid.revision
	var plan: Dictionary = controller.build.preview_structure(&"player", controller.build.selected_definition_id, cell, 0, _preview_revision)
	action_status.text = "Preview Action: %s" % _reason_text(plan.get("reason", &""))
	_refresh()

func _on_confirm_build_pressed() -> void:
	var result = controller.build.place(_next_action_id("hud_build"), &"player", controller.build.selected_definition_id, _preview_cell, 0, _preview_revision)
	action_status.text = "Build Action: %s" % _reason_text(result.reason_code)
	_preview_revision = controller.build.state.grid.revision
	_refresh()

func _on_cancel_build_pressed() -> void:
	controller.build.preview.clear()
	_preview_revision = -1
	action_status.text = "Preview Action: 취소됨"
	_refresh()

func _on_extract_pressed() -> void:
	var result = controller.request_extraction(_next_action_id("hud_extract"))
	action_status.text = "Extraction Action: %s" % _reason_text(result.reason_code)
	_refresh()

func _on_high_contrast_toggled(enabled: bool) -> void:
	_high_contrast = enabled
	_apply_contrast(enabled)

func _on_blueprint_selected(index: int) -> void:
	if controller == null or index < 0 or index >= blueprint_select.get_item_count():
		return
	var definition_id := StringName(blueprint_select.get_item_metadata(index))
	if controller.build.select_definition(definition_id):
		action_status.text = "Blueprint: %s" % String(definition_id)
	_refresh()

func _refresh_blueprints() -> void:
	if controller == null:
		return
	var ids: Array = controller.available_blueprint_ids
	var signature := str(ids)
	if signature == _blueprint_signature:
		return
	_blueprint_signature = signature
	blueprint_select.clear()
	for value in ids:
		var definition_id := StringName(value)
		var definition = controller.build.catalog.get_definition(definition_id) if controller.build.catalog != null else null
		blueprint_select.add_item(String(definition.display_name) if definition != null else String(definition_id))
		blueprint_select.set_item_metadata(blueprint_select.get_item_count() - 1, definition_id)
	if blueprint_select.get_item_count() == 0:
		return
	var selected_id: StringName = controller.build.selected_definition_id
	for index in range(blueprint_select.get_item_count()):
		if StringName(blueprint_select.get_item_metadata(index)) == selected_id:
			blueprint_select.select(index)
			return
	blueprint_select.select(0)

func _apply_contrast(enabled: bool) -> void:
	var foreground := Color.WHITE if enabled else Color("d8e2dc")
	for node in [terrain_status, objective_status, threat_status, inventory_status, build_status, extraction_status, prompt, action_status]:
		node.add_theme_color_override("font_color", foreground)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("000000") if enabled else Color("102027")
	style.border_color = Color.WHITE if enabled else Color("52706c")
	style.set_border_width_all(3 if enabled else 1)
	status_panel.add_theme_stylebox_override("panel", style)
	high_contrast.text = "고대비: 켜짐" if enabled else "고대비: 꺼짐"

func _next_action_id(prefix: String) -> StringName:
	_action_sequence += 1
	return StringName("%s_%d" % [prefix, _action_sequence])

func _items_text(items: Dictionary) -> String:
	if items.is_empty():
		return "없음"
	var parts := PackedStringArray()
	var keys: Array = items.keys()
	keys.sort()
	for item_id in keys:
		parts.append("%s x%d" % [String(item_id), int(items[item_id])])
	return ", ".join(parts)

func _reason_text(code: StringName) -> String:
	match code:
		&"ACCEPTED": return "승인"
		&"NOT_ENOUGH_RESOURCE": return "거절 — 자원 부족"
		&"OCCUPIED": return "거절 — 점유된 Cell"
		&"OUT_OF_BOUNDS": return "거절 — 맵 밖"
		&"RESERVED": return "거절 — 예약된 Cell"
		&"STALE_PREVIEW": return "거절 — 오래된 Preview"
		&"OBJECTIVE_INCOMPLETE": return "거절 — 목표 미완료"
		&"WRONG_OPERATION_STATE": return "거절 — 현재 상태에서 불가"
		&"ACTION_INVALID": return "거절 — 잘못된 Action"
		_: return String(code) if not String(code).is_empty() else "대기"
