class_name MainMenu
extends CanvasLayer

@onready var map_1_btn: Button = $TabContainer/PlayTab/PlayColumns/MapColumn/Map1Button
@onready var map_2_btn: Button = $TabContainer/PlayTab/PlayColumns/MapColumn/Map2Button
@onready var map_3_btn: Button = $TabContainer/PlayTab/PlayColumns/MapColumn/Map3Button
@onready var map_4_btn: Button = $TabContainer/PlayTab/PlayColumns/MapColumn/Map4Button

@onready var hp_upgrade_btn: Button = $TabContainer/ShopTab/VBoxContainer/HPUpgradeBtn
@onready var dmg_upgrade_btn: Button = $TabContainer/ShopTab/VBoxContainer/DmgUpgradeBtn
@onready var spd_upgrade_btn: Button = $TabContainer/ShopTab/VBoxContainer/SpdUpgradeBtn
@onready var gold_label: Label = $GoldLabel
@onready var progress_label: Label = $ProgressLabel
@onready var character_select: OptionButton = $TabContainer/PlayTab/PlayColumns/LoadoutColumn/CharacterSelect
@onready var character_info_label: Label = $TabContainer/PlayTab/PlayColumns/LoadoutColumn/CharacterInfoLabel
@onready var screen_shake_toggle: CheckButton = $TabContainer/ShopTab/VBoxContainer/ScreenShakeToggle
@onready var volume_slider: HSlider = $TabContainer/ShopTab/VBoxContainer/VolumeSlider

const CHARACTER_IDS := ["scavenger", "medic", "ranger", "bulwark", "pyro", "engineer", "reaper", "chronomancer"]
const CHARACTER_NAMES := [
	"Scavenger · 회수 공격형", "Medic · 생존 지원형", "Ranger · 기동 사격형",
	"Bulwark · 중장 방어형", "Pyro · 광역 소각형", "Engineer · 자동 포격형",
	"Reaper · 처형 돌격형", "Chronomancer · 시간 제어형"
]
const CHARACTER_DESCRIPTIONS := [
	"폐허의 약탈자 · HP +10, 피해 +8% · [E] 고철 폭탄: 광역 피해와 스크랩 획득",
	"응급 구조 전문가 · HP +35, 피해 -10% · [E] 응급 파동: 회복 및 일시 피해 경감",
	"기동 정찰병 · 속도 +35, 피해 +10% · [E] 집중 사격: 재장전/공격 속도 강화",
	"진압 방패병 · HP +60, 받는 피해 감소 · [E] 방벽 충격: 적을 밀쳐내고 보호막 획득",
	"소각 전문가 · 피해 +15%, HP -10 · [E] 화염 폭발: 넓은 범위 강력 피해",
	"전투 공병 · 재장전 단축 · [E] 센트리 일제사격: 여러 적 자동 공격",
	"처형자 · 속도/피해 증가, HP -20 · [E] 사신의 표식: 부상당한 적 즉시 처형",
	"시간 연구원 · 이동/재장전 강화 · [E] 시간 붕괴: 주변 적 피해 및 둔화"
]
const CHARACTER_SHEETS := [
	preload("res://assets/graphics/animated/player_scavenger_sheet_v1.png"), preload("res://assets/graphics/animated/player_medic_sheet_v1.png"),
	preload("res://assets/graphics/animated/player_ranger_sheet_v1.png"), preload("res://assets/graphics/animated/player_bulwark_sheet_v1.png"),
	preload("res://assets/graphics/animated/player_pyro_sheet_v1.png"), preload("res://assets/graphics/animated/player_engineer_sheet_v1.png"),
	preload("res://assets/graphics/animated/player_reaper_sheet_v1.png"), preload("res://assets/graphics/animated/player_chronomancer_sheet_v1.png")
]
const CHARACTER_STATS := ["HP ■■■  SPD ■■  DMG ■■■", "HP ■■■■  SPD ■■  DMG ■■", "HP ■■  SPD ■■■■  DMG ■■■", "HP ■■■■■  SPD ■  DMG ■■", "HP ■■  SPD ■■  DMG ■■■■", "HP ■■■  SPD ■■  DMG ■■■", "HP ■  SPD ■■■  DMG ■■■■", "HP ■■  SPD ■■■  DMG ■■■"]
const MAP_CARDS := [
	["폐허 지구", "보통", "생존자 호송", "res://assets/graphics/floor_quarantine_v3.png", "res://scenes/maps/map_1.tscn"],
	["봉쇄 교차로", "위험", "발전기 방어", "res://assets/graphics/floor_industrial_v3.png", "res://scenes/maps/map_2.tscn"],
	["침수 격리 지구", "고위험", "샘플 회수", "res://assets/graphics/floor_flooded_v3.png", "res://scenes/maps/map_3.tscn"],
	["지하 연구소", "극한", "중앙 단말 해킹", "res://assets/graphics/floor_lab_v3.png", "res://scenes/maps/map_4.tscn"]
]
const PET_IDS := ["rescue_hound", "toxic_crow", "lab_drone"]
const PET_NAMES := {
	"rescue_hound": "구조견 · 근접 돌진",
	"toxic_crow": "독성 까마귀 · 광역 공격",
	"lab_drone": "연구 드론 · 사격/회복"
}
var pet_select: OptionButton
var pet_info_label: Label
var difficulty_select: OptionButton
var challenge_select: OptionButton
var endless_toggle: CheckButton
var evolution_codex: AcceptDialog
var trait_dialog: AcceptDialog
var trait_tabs: TabContainer
var trait_summary: Label
var trait_progress: ProgressBar
var ui_scale_select: OptionButton

func _ready() -> void:
	map_1_btn.pressed.connect(func() -> void: _load_map("res://scenes/maps/map_1.tscn"))
	map_2_btn.pressed.connect(func() -> void: _load_map("res://scenes/maps/map_2.tscn"))
	map_3_btn.pressed.connect(func() -> void: _load_map("res://scenes/maps/map_3.tscn"))
	map_4_btn.pressed.connect(func() -> void: _load_map("res://scenes/maps/map_4.tscn"))

	hp_upgrade_btn.pressed.connect(_open_trait_tree)
	dmg_upgrade_btn.hide()
	spd_upgrade_btn.hide()
	character_select.item_selected.connect(_on_character_selected)
	screen_shake_toggle.toggled.connect(_on_screen_shake_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	for character_name in CHARACTER_NAMES:
		character_select.add_item(character_name)
	var selected_character_index := maxi(0, CHARACTER_IDS.find(SaveManager.selected_character))
	character_select.select(selected_character_index)
	_update_character_info(selected_character_index)
	_build_pet_selector()
	_build_run_settings()
	_build_ui_scale_setting()
	_build_visual_selectors()
	_build_evolution_codex()
	_build_weapon_statistics()
	_build_trait_tree()
	screen_shake_toggle.button_pressed = SaveManager.screen_shake_enabled
	volume_slider.value = SaveManager.master_volume
	AudioManager.set_master_volume(SaveManager.master_volume)

	EventBus.gold_changed.connect(_on_gold_changed)
	_update_shop_ui()
	_update_progress_ui()
	map_1_btn.grab_focus()
	$TabContainer.tab_changed.connect(_animate_tab)

func _build_visual_selectors() -> void:
	character_select.hide()
	var character_grid := GridContainer.new()
	character_grid.name = "CharacterGrid"
	character_grid.columns = 4
	character_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_grid.add_theme_constant_override("h_separation", 8)
	character_grid.add_theme_constant_override("v_separation", 8)
	character_select.get_parent().add_child(character_grid)
	character_select.get_parent().move_child(character_grid, 0)
	for index in CHARACTER_IDS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s\n%s" % [CHARACTER_NAMES[index].get_slice(" · ", 0), CHARACTER_STATS[index]]
		button.tooltip_text = CHARACTER_DESCRIPTIONS[index]
		button.icon = _portrait(CHARACTER_SHEETS[index] as Texture2D)
		button.add_theme_constant_override("icon_max_width", 54)
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 12)
		_style_selection_button(button, index == maxi(0, CHARACTER_IDS.find(SaveManager.selected_character)), Color(0.3, 0.9, 0.78, 1.0))
		button.pressed.connect(_select_character_card.bind(index, character_grid))
		character_grid.add_child(button)
	for button in [map_1_btn, map_2_btn, map_3_btn, map_4_btn]: button.hide()
	var map_column := map_1_btn.get_parent()
	for index in MAP_CARDS.size():
		var data := MAP_CARDS[index] as Array
		var button := Button.new()
		button.name = "MapCard%d" % (index + 1)
		button.custom_minimum_size = Vector2(258, 80)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%02d  %s  ·  [%s]\n주요 목표  %s" % [index + 1, data[0], data[1], data[2]]
		button.icon = load(String(data[3])) as Texture2D
		button.add_theme_constant_override("icon_max_width", 62)
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 13)
		_style_selection_button(button, false, Color(1.0, 0.5, 0.24, 1.0))
		button.pressed.connect(_load_map.bind(String(data[4])))
		map_column.add_child(button)

func _portrait(sheet: Texture2D) -> AtlasTexture:
	var portrait := AtlasTexture.new()
	portrait.atlas = sheet
	var frame_w := float(sheet.get_width()) / 4.0
	var frame_h := float(sheet.get_height()) / 4.0
	portrait.region = Rect2(0.0, 0.0, frame_w, frame_h)
	return portrait

func _style_selection_button(button: Button, selected: bool, accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent, 0.24 if selected else 0.08)
	style.border_color = accent if selected else Color(accent, 0.45)
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(7.0)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent, 0.28)
	hover.set_border_width_all(2)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)

func _select_character_card(index: int, grid: GridContainer) -> void:
	SaveManager.selected_character = CHARACTER_IDS[index]
	SaveManager.save_data()
	_update_character_info(index)
	for child_index in grid.get_child_count():
		_style_selection_button(grid.get_child(child_index) as Button, child_index == index, Color(0.3, 0.9, 0.78, 1.0))

func _animate_tab(tab_index: int) -> void:
	var page := $TabContainer.get_child(tab_index) as Control
	page.modulate.a = 0.0
	create_tween().tween_property(page, "modulate:a", 1.0, 0.18)

func _build_evolution_codex() -> void:
	var button := Button.new()
	button.text = "★ 진화 도감 (Codex)"
	button.custom_minimum_size = Vector2(400, 52)
	button.add_theme_font_size_override("font_size", 20)
	button.tooltip_text = "8종 무기의 5레벨 진화 조합을 확인합니다."
	hp_upgrade_btn.get_parent().add_child(button)

	evolution_codex = AcceptDialog.new()
	evolution_codex.title = "무기 진화 도감"
	evolution_codex.ok_button_text = "닫기"
	evolution_codex.min_size = Vector2i(860, 620)
	var lines: Array[String] = []
	for entry in Weapon.get_evolution_catalog():
		var requirements: Array = entry["requirements"]
		var recipe := "%s + %s" % [Weapon.get_perk_label(requirements[0]), Weapon.get_perk_label(requirements[1])]
		lines.append("%s  Lv5\n%s  →  ★ %s\n%s" % [entry["display"], recipe, entry["name"], entry["description"]])
	evolution_codex.dialog_text = "\n\n".join(lines)
	add_child(evolution_codex)
	button.pressed.connect(func() -> void: evolution_codex.popup_centered(Vector2i(860, 620)))

func _build_weapon_statistics() -> void:
	var button := Button.new()
	button.text = "📊 무기 전투 통계"
	button.custom_minimum_size = Vector2(400, 52)
	button.add_theme_font_size_override("font_size", 20)
	hp_upgrade_btn.get_parent().add_child(button)
	var dialog := AcceptDialog.new()
	dialog.title = "무기별 누적 통계"
	dialog.ok_button_text = "닫기"
	dialog.min_size = Vector2i(760, 560)
	add_child(dialog)
	button.pressed.connect(func() -> void:
		var lines: Array[String] = ["무기                         누적 피해       사용률        진화"]
		for entry in Weapon.get_evolution_catalog():
			var weapon_id := String(entry.weapon)
			var stats: Dictionary = SaveManager.weapon_stats.get(weapon_id, {"damage": 0, "runs": 0, "evolutions": 0})
			var usage := float(stats.runs) / float(maxi(1, SaveManager.total_runs)) * 100.0
			lines.append("%-24s %10d      %5.1f%% (%d회)    %d회" % [entry.display, int(stats.damage), usage, int(stats.runs), int(stats.evolutions)])
		dialog.dialog_text = "총 플레이 %d회 · 사용률은 해당 무기를 보유한 런 비율입니다.\n\n%s" % [SaveManager.total_runs, "\n".join(lines)]
		dialog.popup_centered(Vector2i(760, 560))
	)

func _build_trait_tree() -> void:
	hp_upgrade_btn.text = "🧬 영구 성장 특성 트리"
	hp_upgrade_btn.tooltip_text = "18개 영구 특성을 강화하거나 100% 환급합니다."
	trait_dialog = AcceptDialog.new()
	trait_dialog.title = "DEAD//SHIFT · 영구 성장 특성 트리"
	trait_dialog.ok_button_text = "닫기"
	trait_dialog.min_size = Vector2i(980, 680)
	add_child(trait_dialog)
	var content := VBoxContainer.new()
	content.position = Vector2(24, 18)
	content.custom_minimum_size = Vector2(920, 580)
	content.add_theme_constant_override("separation", 10)
	trait_dialog.add_child(content)
	trait_summary = Label.new()
	trait_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trait_summary.add_theme_font_size_override("font_size", 20)
	content.add_child(trait_summary)
	trait_progress = ProgressBar.new()
	trait_progress.max_value = 100.0
	trait_progress.show_percentage = true
	content.add_child(trait_progress)
	trait_tabs = TabContainer.new()
	trait_tabs.custom_minimum_size = Vector2(920, 455)
	trait_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(trait_tabs)
	var reset_button := Button.new()
	reset_button.text = "특성 전체 초기화 · 100% 골드 환급"
	reset_button.pressed.connect(_confirm_trait_reset)
	content.add_child(reset_button)

func _open_trait_tree() -> void:
	_refresh_trait_tree()
	trait_dialog.popup_centered(Vector2i(980, 680))

func _refresh_trait_tree() -> void:
	trait_summary.text = "보유 골드  %d G   ·   총 업그레이드 달성률" % SaveManager.gold
	trait_progress.value = SaveManager.get_upgrade_progress() * 100.0
	for child in trait_tabs.get_children():
		child.free()
	var categories := {"survival": "🛡 생존", "combat": "⚔ 전투", "utility": "🧲 유틸", "economy": "💰 경제"}
	for category_id in categories:
		var scroll := ScrollContainer.new()
		scroll.name = categories[category_id]
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 8)
		scroll.add_child(list)
		trait_tabs.add_child(scroll)
		for upgrade_id in SaveManager.UPGRADE_DEFINITIONS:
			var definition: Dictionary = SaveManager.UPGRADE_DEFINITIONS[upgrade_id]
			if String(definition.category) != category_id:
				continue
			var level := SaveManager.get_upgrade_level(upgrade_id)
			var max_level := int(definition.max)
			var button := Button.new()
			button.custom_minimum_size = Vector2(880, 72)
			button.text = "%s   Lv %d / %d\n%s · %s   |   %s" % [definition.name, level, max_level, definition.effect, definition.description, "MAX" if level >= max_level else "%d G" % SaveManager.get_upgrade_cost(upgrade_id)]
			button.disabled = level >= max_level or SaveManager.gold < SaveManager.get_upgrade_cost(upgrade_id)
			_style_selection_button(button, not button.disabled, Color(0.32, 0.88, 0.68, 1.0))
			button.pressed.connect(_buy_trait.bind(String(upgrade_id)))
			list.add_child(button)

func _buy_trait(upgrade_id: String) -> void:
	if SaveManager.buy_upgrade(upgrade_id):
		_refresh_trait_tree()
		_update_shop_ui()

func _confirm_trait_reset() -> void:
	var confirmation := ConfirmationDialog.new()
	confirmation.title = "경고 · 영구 성장 초기화"
	confirmation.dialog_text = "구매한 모든 특성이 초기화됩니다.\n사용한 골드는 100% 환급됩니다. 계속하시겠습니까?"
	confirmation.ok_button_text = "초기화 및 전액 환급"
	confirmation.confirmed.connect(func() -> void:
		SaveManager.reset_all_upgrades()
		_refresh_trait_tree()
		_update_shop_ui()
	)
	confirmation.canceled.connect(confirmation.queue_free)
	confirmation.confirmed.connect(confirmation.queue_free)
	add_child(confirmation)
	confirmation.popup_centered()

func _build_pet_selector() -> void:
	var container := character_info_label.get_parent()
	pet_select = OptionButton.new()
	pet_select.custom_minimum_size = Vector2(300, 44)
	pet_select.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pet_select.add_theme_font_size_override("font_size", 18)
	container.add_child(pet_select)
	container.move_child(pet_select, character_info_label.get_index() + 1)
	pet_info_label = Label.new()
	pet_info_label.custom_minimum_size = Vector2(420, 34)
	pet_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pet_info_label.add_theme_font_size_override("font_size", 14)
	pet_info_label.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0, 1.0))
	container.add_child(pet_info_label)
	container.move_child(pet_info_label, pet_select.get_index() + 1)
	pet_select.add_item("펫 미장착")
	pet_select.set_item_metadata(0, "")
	for pet_id in PET_IDS:
		if pet_id in SaveManager.pet_blueprints:
			pet_select.add_item(PET_NAMES[pet_id])
			pet_select.set_item_metadata(pet_select.item_count - 1, pet_id)
	var selected_index := 0
	for index in pet_select.item_count:
		if String(pet_select.get_item_metadata(index)) == SaveManager.selected_pet:
			selected_index = index
			break
	pet_select.select(selected_index)
	pet_select.item_selected.connect(_on_pet_selected)
	_update_pet_info(SaveManager.selected_pet)

func _on_pet_selected(index: int) -> void:
	SaveManager.selected_pet = String(pet_select.get_item_metadata(index))
	SaveManager.save_data()
	_update_pet_info(SaveManager.selected_pet)

func _update_pet_info(pet_id: String) -> void:
	match pet_id:
		"rescue_hound": pet_info_label.text = "근처 적에게 돌진해 강한 피해와 넉백을 줍니다."
		"toxic_crow": pet_info_label.text = "적 무리에 독성 폭발을 일으켜 범위 피해를 줍니다."
		"lab_drone": pet_info_label.text = "가까운 적을 사격하고 12초마다 플레이어를 회복합니다."
		_: pet_info_label.text = "맵 사건에서 설계도를 획득하면 펫을 장착할 수 있습니다."

func _build_run_settings() -> void:
	var container := character_info_label.get_parent()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	container.add_child(row)
	container.move_child(row, pet_info_label.get_index() + 1)
	difficulty_select = OptionButton.new()
	difficulty_select.custom_minimum_size = Vector2(135, 42)
	for entry in [["easy", "난이도: 쉬움"], ["normal", "난이도: 보통"], ["hard", "난이도: 어려움"], ["nightmare", "난이도: 악몽"]]:
		difficulty_select.add_item(entry[1])
		difficulty_select.set_item_metadata(difficulty_select.item_count - 1, entry[0])
	row.add_child(difficulty_select)
	difficulty_select.tooltip_text = "쉬움  체력72%/공격75%/밀도78%\n보통  기본 수치\n어려움  체력145%/공격135%/밀도128%\n악몽  체력215%/공격180%/밀도165%"
	challenge_select = OptionButton.new()
	challenge_select.custom_minimum_size = Vector2(185, 42)
	var challenges := [["none", "도전 과제: 없음"], ["untouchable", "철인"], ["elite_hunter", "정예 사냥꾼"], ["mission_master", "현장 전문가"], ["endless_15", "끝없는 밤"]]
	for entry in challenges:
		var completed_mark := " ✓" if String(entry[0]) in SaveManager.completed_challenges else ""
		challenge_select.add_item(String(entry[1]) + completed_mark)
		challenge_select.set_item_metadata(challenge_select.item_count - 1, entry[0])
	row.add_child(challenge_select)
	challenge_select.tooltip_text = "런당 하나의 목표를 추적합니다. 최초 달성 시 300골드를 획득하며 ✓로 기록됩니다."
	endless_toggle = CheckButton.new()
	endless_toggle.text = "무한 모드"
	endless_toggle.tooltip_text = "5분마다 더 강한 보스가 반복 등장하며 보스 처치 후에도 런이 계속됩니다."
	endless_toggle.button_pressed = SaveManager.endless_mode
	row.add_child(endless_toggle)
	_select_metadata(difficulty_select, SaveManager.selected_difficulty)
	_select_metadata(challenge_select, SaveManager.selected_challenge)
	difficulty_select.item_selected.connect(func(index: int) -> void:
		SaveManager.selected_difficulty = String(difficulty_select.get_item_metadata(index))
		SaveManager.save_data()
	)
	challenge_select.item_selected.connect(func(index: int) -> void:
		SaveManager.selected_challenge = String(challenge_select.get_item_metadata(index))
		SaveManager.save_data()
	)
	endless_toggle.toggled.connect(func(enabled: bool) -> void:
		SaveManager.endless_mode = enabled
		SaveManager.save_data()
	)

func _build_ui_scale_setting() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	$TabContainer/ShopTab/VBoxContainer.add_child(row)
	var label := Label.new()
	label.text = "UI 배율"
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	ui_scale_select = OptionButton.new()
	ui_scale_select.custom_minimum_size = Vector2(180, 42)
	for scale in [0.8, 0.9, 1.0, 1.1, 1.25]:
		ui_scale_select.add_item("%d%%" % roundi(scale * 100.0))
		ui_scale_select.set_item_metadata(ui_scale_select.item_count - 1, scale)
	row.add_child(ui_scale_select)
	_select_metadata(ui_scale_select, str(SaveManager.ui_scale))
	ui_scale_select.item_selected.connect(func(index: int) -> void:
		SaveManager.ui_scale = float(ui_scale_select.get_item_metadata(index))
		SaveManager.apply_ui_scale()
		SaveManager.save_data()
	)

func _select_metadata(option: OptionButton, value: String) -> void:
	for index in option.item_count:
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			return

func _on_gold_changed(_new_gold: int) -> void:
	_update_shop_ui()
	_update_progress_ui()

func _update_progress_ui() -> void:
	var best_seconds := int(SaveManager.best_time)
	progress_label.text = "런 %d회  ·  최고 웨이브 %02d  ·  최고 생존 %02d:%02d" % [SaveManager.total_runs, SaveManager.highest_wave, best_seconds / 60, best_seconds % 60]

func _on_character_selected(index: int) -> void:
	if index >= 0 and index < CHARACTER_IDS.size():
		SaveManager.selected_character = CHARACTER_IDS[index]
		_update_character_info(index)
		SaveManager.save_data()

func _update_character_info(index: int) -> void:
	if index >= 0 and index < CHARACTER_DESCRIPTIONS.size():
		character_info_label.text = CHARACTER_DESCRIPTIONS[index]

func _on_screen_shake_toggled(enabled: bool) -> void:
	SaveManager.screen_shake_enabled = enabled
	SaveManager.save_data()

func _on_volume_changed(value: float) -> void:
	SaveManager.master_volume = value
	AudioManager.set_master_volume(value)
	SaveManager.save_data()

func _update_shop_ui() -> void:
	gold_label.text = "골드  " + str(SaveManager.gold)
	hp_upgrade_btn.text = "🧬 영구 성장 특성 트리  ·  %.0f%%" % (SaveManager.get_upgrade_progress() * 100.0)

func _load_map(path: String) -> void:
	ModalManager.clear()
	RunStats.start_run(path.get_file().get_basename())

	# Clear Autoload states before launching a new game
	ObjectPoolManager.clear()
	SpatialGrid.clear()

	get_tree().change_scene_to_file(path)
