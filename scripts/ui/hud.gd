## Game interface, designed to be simple and thumb-friendly:
##   top    : planet name + day, resource chips with icons,
##   bottom : 4 big buttons (pause, speed, build, settings),
##   sheets : build menu, cell card, settings (one at a time).
## Building is 2 taps: pick a building, then a green cell on the planet.
extends CanvasLayer

signal close_requested
signal placement_started(cells: Array)
signal placement_ended
signal appearance_changed

const Haptics := preload("res://scripts/platform/haptics.gd")
const Economy := preload("res://scripts/simulation/economy.gd")
const UiKit := preload("res://scripts/ui/ui_kit.gd")
const Design := preload("res://scripts/ui/design.gd")
const StartMenu := preload("res://scripts/ui/start_menu.gd")
const Objectives := preload("res://scripts/simulation/objectives.gd")
const Events := preload("res://scripts/simulation/events.gd")
const ICON_DIR := "res://assets/icons/ui/"

const BASE_PADDING := 14.0
const REFRESH_INTERVAL := 0.25
# Colors come from the design system (scripts/ui/design.gd).
const TEXT := Design.INK
const MUTED := Design.INK_SOFT
const WARN := Design.WARN
const GOOD := Design.GOOD
const BAD := Design.BAD
const PANEL_BG := Design.CREAM
const SPEEDS := [1, 2, 4]

var _margin: MarginContainer
var _title: Label
var _chips := {}           # resource -> {"value": Label, "rate": Label}
var _toast: Label
var _toast_tween: Tween
var _hint: Label
var _pause_button: Button
var _speed_button: Button
var _build_button: Button
var _settings_button: Button
var _bottom_bar: Control

# Sheets (only one visible at a time).
var _sheets: Array[Control] = []
var _build_sheet: PanelContainer
var _build_sheet_title: Label
var _build_list: VBoxContainer
var _cell_card: PanelContainer
var _cell_title: Label
var _cell_text: Label
var _cell_build_button: Button
var _demolish_button: Button
var _settings_sheet: PanelContainer
var _needs_sheet: PanelContainer
var _needs_text: RichTextLabel
var _needs_row: PanelContainer
var _category_buttons := {}  # category id -> Button
var _category := "housing"
var _banner: PanelContainer
var _banner_label: Label

var _cell := -1             # Cell shown in the card.
var _target_cell := -1      # Build menu opened from a cell ("build here").
var _placing := ""          # Building being placed (2-tap flow).
var _confirm_demolish := false
var _confirm_new_world := false
var _new_world_size := 8
var _last_speed := 1
var _refresh_timer := 0.0
var _blocking: Array[Control] = []

# Tutorial, goals, events, start screen.
var _tutorial_panel: PanelContainer
var _tutorial_text: Label
var _tutorial_count: Label
var _tutorial_next: Button
var _tutorial_steps: Array = []
var _tutorial_flags := {}
var _pulse_tween: Tween
var _pulsing: Control
var _goals_button: Button
var _goals_sheet: PanelContainer
var _goals_list: VBoxContainer
var _event_sheet: PanelContainer
var _event_title: Label
var _event_text: Label
var _event_choices: VBoxContainer
var _upgrade_button: Button
var _start_menu: Control
var _settings_tab := "planet"
var _village_tab := "townhall"
var _village_signature := ""


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	_margin.add_child(column)

	_title = _label("", 18, TEXT)
	_title.add_theme_font_override("font", Design.title_font())
	column.add_child(_title)
	column.add_child(_build_chip_row(["food", "water", "wood", "stone"]))
	_needs_row = _build_needs_row()
	column.add_child(_needs_row)
	_toast = _label("", 15, TEXT)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_stylebox_override("normal", Design.panel(Color("fff3c4"), 18, 10))
	_toast.visible = false
	column.add_child(_toast)
	_tutorial_panel = _build_tutorial_panel()
	column.add_child(_tutorial_panel)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	_banner = _build_banner()
	column.add_child(_banner)
	_build_sheet = _build_build_sheet()
	column.add_child(_build_sheet)
	_cell_card = _build_cell_card()
	column.add_child(_cell_card)
	_settings_sheet = _build_settings_sheet()
	column.add_child(_settings_sheet)
	_needs_sheet = _build_needs_sheet()
	column.add_child(_needs_sheet)
	_goals_sheet = _build_goals_sheet()
	column.add_child(_goals_sheet)
	_event_sheet = _build_event_sheet()
	column.add_child(_event_sheet)
	_sheets.append_array([_build_sheet, _cell_card, _settings_sheet, _needs_sheet, _goals_sheet, _event_sheet])

	_hint = _label(tr("HINT_DRAG"), 13, MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	_bottom_bar = _build_bottom_bar()
	column.add_child(_bottom_bar)

	_start_menu = StartMenu.new()
	root.add_child(_start_menu)
	_start_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_menu.tutorial_requested.connect(restart_tutorial)
	_start_menu.closed.connect(func(): GameState.start_menu_shown = true)
	_start_menu.visible = not GameState.start_menu_shown
	_start_menu.visibility_changed.connect(func(): _margin.visible = not _start_menu.visible)
	_margin.visible = not _start_menu.visible
	_blocking.append_array([_bottom_bar, _banner, _build_sheet, _cell_card, _settings_sheet, _needs_sheet, _needs_row,
		_tutorial_panel, _goals_sheet, _event_sheet, _start_menu])
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	GameState.ticked.connect(_refresh_title)
	GameState.sim.economy.alert.connect(_on_alert)
	GameState.sim.objective_completed.connect(_on_objective_completed)
	GameState.sim.economy.construction_done.connect(_on_construction_done)
	GameState.sim.economy.level_up.connect(_show_level_up)
	GameState.sim.economy.training_done.connect(_on_training_done)
	GameState.sim.event_started.connect(_show_event)
	var steps_file: Dictionary = GameState.config.get("tutorial", {})
	_tutorial_steps = steps_file.get("steps", [])
	_last_speed = GameState.sim.speed if GameState.sim.speed > 0 else 1
	_refresh_title()
	_refresh_chips()
	_refresh_speed_buttons()
	if GameState.pending_offline_days > 0:
		_show_toast(tr("OFFLINE_WELCOME") % GameState.pending_offline_days)
		GameState.pending_offline_days = 0
	_greet_new_version()
	_refresh_tutorial()
	if GameState.sim.pending_event != "":
		_show_event.call_deferred(GameState.sim.pending_event)


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer < REFRESH_INTERVAL:
		return
	_refresh_timer = 0.0
	_refresh_chips()
	_check_tutorial()
	if _goals_sheet.visible:
		_update_goals_sheet()
	if _cell_card.visible:
		_update_cell_card()
	if _build_sheet.visible:
		_update_build_cards()
	if _needs_sheet.visible:
		_update_needs_sheet()


## True when `point` (viewport coordinates) is over an interactive UI element.
func blocks_point(point: Vector2) -> bool:
	for control in _blocking:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return true
	return false


# =============================================================================
# Top: title and resource chips
# =============================================================================

func _build_chip_row(resources: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for res in resources:
		row.add_child(_chip(res))
	return row


func _chip(res: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", Design.panel(Design.CARD, 16, 5))
	chip.clip_contents = true
	chip.custom_minimum_size = Vector2(40, 0)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(line)
	line.add_child(_icon(res, 20))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", -4)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(texts)
	var value := _label("", 15, TEXT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(value)
	var rate := _label("", 10, MUTED)
	rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(rate)
	_chips[res] = {"value": value, "rate": rate}
	return chip


## Population, happiness and health. Tapping it opens the "needs" screen.
func _build_needs_row() -> PanelContainer:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_toggle_needs_sheet())
	var row := _build_chip_row(["people", "happy", "health"])
	holder.add_child(row)
	return holder


func _refresh_chips() -> void:
	var eco = GameState.sim.economy
	for res in ["food", "water", "wood", "stone"]:
		var chip: Dictionary = _chips[res]
		var rate := float(eco.rates.get(res, 0.0))
		chip.value.text = str(floori(eco.stock(res)))
		chip.rate.text = (_format_signed(rate) + tr("PER_DAY")) if absf(rate) >= 0.05 else "—"
		chip.rate.add_theme_color_override("font_color", GOOD if rate > 0.05 else (BAD if rate < -0.05 else MUTED))
		var empty: bool = (res == "food" or res == "water") and eco.stock(res) <= 0.0
		chip.value.add_theme_color_override("font_color", BAD if empty else TEXT)
	var people: Dictionary = _chips["people"]
	people.value.text = "%d/%d" % [eco.population, eco.housing()]
	people.rate.text = tr("WORKERS_SHORT") % [eco.employed(), eco.jobs()]
	_set_gauge(_chips["happy"], eco.happiness, eco.target_of(eco.happiness_factors()))
	_set_gauge(_chips["health"], eco.health, eco.target_of(eco.health_factors()))


## Shows a 0-100 gauge and where it is heading.
func _set_gauge(chip: Dictionary, value: float, target: float) -> void:
	chip.value.text = "%d %%" % roundi(value)
	chip.value.add_theme_color_override("font_color", BAD if value < 30.0 else (WARN if value < 50.0 else TEXT))
	if target > value + 1.0:
		chip.rate.text = tr("TREND_UP")
		chip.rate.add_theme_color_override("font_color", GOOD)
	elif target < value - 1.0:
		chip.rate.text = tr("TREND_DOWN")
		chip.rate.add_theme_color_override("font_color", BAD)
	else:
		chip.rate.text = tr("TREND_STABLE")
		chip.rate.add_theme_color_override("font_color", MUTED)


func _refresh_title() -> void:
	_title.text = "%s · %s" % [GameState.sim.custom.get("planet_name", ""), tr("DAY_N") % GameState.sim.day()]


## After an update, says which version is now installed (once).
func _greet_new_version() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var last := str(UserSettings.get_value("last_version"))
	if version == "" or version == last:
		return
	UserSettings.set_value("last_version", version)
	_show_toast(tr("UPDATE_INSTALLED") % version)


func _on_alert(key: String) -> void:
	_show_toast(tr(key))
	Haptics.medium()


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(4.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 1.0)
	_toast_tween.tween_callback(func(): _toast.visible = false)


# =============================================================================
# Bottom bar: pause, speed, build, settings
# =============================================================================

func _build_bottom_bar() -> PanelContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	_pause_button = _icon_button("pause", "", Vector2(48, 54))
	_pause_button.pressed.connect(_on_pause_pressed)
	bar.add_child(_pause_button)
	_speed_button = _icon_button("", "x1", Vector2(48, 54))
	_speed_button.pressed.connect(_on_speed_pressed)
	bar.add_child(_speed_button)
	_build_button = _icon_button("build", tr("BUILD"), Vector2(0, 54))
	_build_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Design.make_primary(_build_button, 22)
	_build_button.add_theme_font_size_override("font_size", 16)
	_build_button.add_theme_constant_override("icon_max_width", 22)
	_build_button.add_theme_constant_override("h_separation", 4)
	_build_button.pressed.connect(_on_build_pressed)
	bar.add_child(_build_button)
	_goals_button = _icon_button("townhall", "", Vector2(48, 54))
	_goals_button.pressed.connect(_on_goals_pressed)
	bar.add_child(_goals_button)
	_settings_button = _icon_button("settings", "", Vector2(48, 54))
	_settings_button.pressed.connect(_on_settings_pressed)
	bar.add_child(_settings_button)
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", Design.panel(Design.CREAM, 30, 6))
	pill.add_child(bar)
	return pill


func _on_pause_pressed() -> void:
	var sim = GameState.sim
	sim.set_speed(_last_speed if sim.speed == 0 else 0)
	Haptics.light()
	_refresh_speed_buttons()


func _on_speed_pressed() -> void:
	var index := SPEEDS.find(_last_speed)
	_last_speed = SPEEDS[(index + 1) % SPEEDS.size()]
	GameState.sim.set_speed(_last_speed)
	_tutorial_flags["speed"] = true
	Haptics.light()
	_refresh_speed_buttons()


func _refresh_speed_buttons() -> void:
	var paused: bool = GameState.sim.speed == 0
	_pause_button.icon = _texture("play" if paused else "pause")
	_speed_button.text = "x%d" % _last_speed
	_speed_button.modulate = Color(1, 1, 1, 0.5) if paused else Color.WHITE


func _on_build_pressed() -> void:
	if _placing != "":
		_end_placement()
		return
	if _build_sheet.visible:
		_close_sheets()
		return
	_open_build_sheet(-1)


func _on_settings_pressed() -> void:
	if _settings_sheet.visible:
		_close_sheets()
		return
	_end_placement()
	_confirm_new_world = false
	_refresh_settings_sheet()
	_show_sheet(_settings_sheet)
	close_requested.emit()


# =============================================================================
# Sheets
# =============================================================================

func _show_sheet(sheet: Control) -> void:
	for s in _sheets:
		s.visible = s == sheet
	_hint.visible = false
	_tutorial_panel.visible = not _current_step().is_empty() and (sheet == _build_sheet or sheet == _cell_card)


func _close_sheets() -> void:
	for s in _sheets:
		s.visible = false
	_hint.visible = _placing == ""
	_tutorial_panel.visible = not _current_step().is_empty()


func _sheet(title_label: Label) -> Array:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Design.panel(PANEL_BG, 28, 16))
	panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.add_theme_font_override("font", Design.title_font())
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title_label)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(44, 44)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(func():
		_close_sheets()
		close_requested.emit())
	header.add_child(close)
	return [panel, box]


# --- Build menu ---------------------------------------------------------------

func _build_build_sheet() -> PanelContainer:
	_build_sheet_title = _label("", 20, TEXT)
	var parts := _sheet(_build_sheet_title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	parts[1].add_child(tabs)
	var group := ButtonGroup.new()
	var categories: Array = GameState.config.get("building_categories", [])
	for cat in categories:
		var tab := Button.new()
		tab.toggle_mode = true
		tab.button_group = group
		tab.text = tr(str(cat.name_key))
		tab.custom_minimum_size = Vector2(0, 40)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.clip_text = true
		tab.add_theme_font_size_override("font_size", 12)
		tab.add_theme_stylebox_override("normal", Design.panel(Design.CARD, 14, 3))
		tab.add_theme_stylebox_override("hover", Design.panel(Design.CARD, 14, 3))
		tab.add_theme_stylebox_override("pressed", Design.outlined(Design.CORAL_SOFT, Design.CORAL, 14, 3))
		tab.add_theme_stylebox_override("hover_pressed", Design.outlined(Design.CORAL_SOFT, Design.CORAL, 14, 3))
		tab.pressed.connect(func():
			_category = str(cat.id)
			_open_build_sheet(_target_cell)
			Haptics.light())
		tabs.add_child(tab)
		_category_buttons[str(cat.id)] = tab
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 230)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts[1].add_child(scroll)
	_build_list = VBoxContainer.new()
	_build_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_build_list)
	return parts[0]


## Opens the build menu. With a cell: builds right there; without: 2-tap flow.
func _open_build_sheet(cell: int) -> void:
	_end_placement()
	_target_cell = cell
	_build_sheet_title.text = tr("BUILD_HERE") if cell >= 0 else tr("BUILD_WHAT")
	var eco_b = GameState.sim.economy
	if not eco_b.townhall_levels.is_empty():
		_build_sheet_title.text += "\n" + tr("BUILDERS_FREE") % [eco_b.free_builders(), eco_b.builders()]
	for child in _build_list.get_children():
		_build_list.remove_child(child)
		child.queue_free()
	var eco = GameState.sim.economy
	var ids: Array = eco.defs.keys()
	ids.sort_custom(func(a, b): return int(eco.defs[a].get("order", 99)) < int(eco.defs[b].get("order", 99)))
	for cat_id in _category_buttons:
		_category_buttons[cat_id].set_pressed_no_signal(cat_id == _category)
	for id in ids:
		if str(eco.defs[id].get("category", "housing")) != _category or not eco.defs[id].get("buildable", true):
			continue
		if cell >= 0 and eco.can_build(cell, id) in [Economy.ERR_TERRAIN, Economy.ERR_DEPOSIT]:
			continue
		_build_list.add_child(_build_card(id))
	_update_build_cards()
	_show_sheet(_build_sheet)


## A wide card: icon, name, short effect, cost.
func _build_card(id: String) -> Button:
	var bdef: Dictionary = GameState.sim.economy.defs[id]
	var card := Button.new()
	card.name = id
	card.custom_minimum_size = Vector2(0, 62)
	card.clip_text = true
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.icon = _texture(id)
	card.expand_icon = false
	card.add_theme_constant_override("icon_max_width", 40)
	card.add_theme_constant_override("h_separation", 12)
	card.text = _card_text(id, "")
	card.pressed.connect(_on_build_card_pressed.bind(id))
	return card


## Name and cost, then either the effect or why it can't be built yet.
func _card_text(id: String, reason: String) -> String:
	var eco = GameState.sim.economy
	var bdef: Dictionary = eco.defs[id]
	var second := tr(str(bdef.get("short_key", "")))
	if reason == Economy.ERR_LOCKED:
		second = tr("LOCKED_AT") % eco.unlock_level(id)
	elif reason == Economy.ERR_LIMIT:
		second = tr("LIMIT_REACHED") % [eco.building_count(id), eco.building_limit(id)]
	elif reason == Economy.ERR_BUILDERS:
		second = tr("BUILD_ERR_BUILDERS")
	elif not eco.townhall_levels.is_empty():
		second += "  (%d/%d)" % [eco.building_count(id), eco.building_limit(id)]
	return "%s  ·  %s\n%s" % [tr(str(bdef.get("name_key", id))), _cost_text(bdef.get("cost", {})), second]


func _update_build_cards() -> void:
	var eco = GameState.sim.economy
	for card in _build_list.get_children():
		var id := str(card.name)
		var reason := ""
		if eco.building_limit(id) <= 0:
			reason = Economy.ERR_LOCKED
		elif eco.building_count(id) >= eco.building_limit(id):
			reason = Economy.ERR_LIMIT
		elif float(eco.defs[id].get("build_days", 0.0)) > 0.0 and not eco.townhall_levels.is_empty() and eco.free_builders() <= 0:
			reason = Economy.ERR_BUILDERS
		elif _target_cell >= 0:
			reason = eco.can_build(_target_cell, id)
		elif not eco.can_afford(eco.defs[id].get("cost", {})):
			reason = Economy.ERR_COST
		(card as Button).disabled = reason != ""
		(card as Button).text = _card_text(id, reason)


func _on_build_card_pressed(id: String) -> void:
	var eco = GameState.sim.economy
	if _target_cell >= 0:
		if eco.build(_target_cell, id):
			Haptics.medium()
			GameState.sim.check_objectives()
			_show_toast(tr("BUILT") % tr(str(eco.defs[id].get("name_key", id))))
		_close_sheets()
		close_requested.emit()
		return
	var cells := _valid_cells(id)
	if cells.is_empty():
		_show_toast(tr("BUILD_NO_SPOT"))
		return
	_placing = id
	_close_sheets()
	_banner_label.text = tr("PLACE_HINT") % tr(str(eco.defs[id].get("name_key", id)))
	_banner.visible = true
	_hint.visible = false
	close_requested.emit()
	placement_started.emit(cells)
	Haptics.light()


func _valid_cells(id: String) -> Array:
	var eco = GameState.sim.economy
	var cells: Array = []
	for i in GameState.sim.planet.cell_count():
		if eco.can_build(i, id) == "":
			cells.append(i)
	return cells


func _build_banner() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Design.panel(Design.TEAL_SOFT, 20, 12))
	panel.visible = false
	var row := HBoxContainer.new()
	panel.add_child(row)
	_banner_label = _label("", 15, TEXT)
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_banner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_banner_label)
	var cancel := Button.new()
	cancel.text = tr("CANCEL")
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.pressed.connect(_end_placement)
	row.add_child(cancel)
	return panel


func _end_placement() -> void:
	if _placing == "":
		return
	_placing = ""
	_banner.visible = false
	_hint.visible = true
	placement_ended.emit()


# --- Cell card ----------------------------------------------------------------

## Called when the player taps a cell on the planet.
func on_cell_tapped(cell: int) -> void:
	if _placing != "":
		var eco = GameState.sim.economy
		var id := _placing
		var reason: String = eco.can_build(cell, id)
		if reason == "" and eco.build(cell, id):
			Haptics.medium()
			GameState.sim.check_objectives()
			_show_toast(tr("BUILT") % tr(str(eco.defs[id].get("name_key", id))))
			_end_placement()
		else:
			_show_toast(tr(reason))
		close_requested.emit()
		return
	_cell = cell
	_tutorial_flags["select"] = true
	_confirm_demolish = false
	_update_cell_card()
	_show_sheet(_cell_card)
	Haptics.light()


func hide_cell() -> void:
	if _cell_card.visible:
		_close_sheets()
	_cell = -1


func _build_cell_card() -> PanelContainer:
	_cell_title = _label("", 20, TEXT)
	var parts := _sheet(_cell_title)
	var box: VBoxContainer = parts[1]
	_cell_text = _label("", 15, MUTED)
	_cell_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cell_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_cell_text)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	_cell_build_button = _icon_button("build", tr("BUILD_HERE"), Vector2(0, 50))
	_cell_build_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cell_build_button.pressed.connect(func():
		if _cell == GameState.sim.economy.village_center:
			_village_tab = "townhall"
			_on_goals_pressed()
		else:
			_open_build_sheet(_cell))
	actions.add_child(_cell_build_button)
	_upgrade_button = _icon_button("build", "", Vector2(0, 50))
	_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	actions.add_child(_upgrade_button)
	_demolish_button = Button.new()
	_demolish_button.custom_minimum_size = Vector2(0, 50)
	_demolish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_demolish_button.pressed.connect(_on_demolish_pressed)
	actions.add_child(_demolish_button)
	return parts[0]


func _update_cell_card() -> void:
	if _cell < 0:
		return
	var sim = GameState.sim
	var planet = sim.planet
	var eco = sim.economy
	var terrain_id: String = planet.terrain[_cell]
	var tdef: Dictionary = sim.terrain_defs.get(terrain_id, {})
	var building_id: String = planet.buildings[_cell]
	var lines := PackedStringArray()

	if building_id != "":
		var bdef: Dictionary = eco.defs.get(building_id, {})
		_cell_title.text = tr(str(bdef.get("name_key", building_id)))
		lines.append(_building_status(_cell, bdef))
		lines.append(tr(str(tdef.get("name_key", terrain_id))))
	else:
		_cell_title.text = tr(str(tdef.get("name_key", terrain_id)))
		if not tdef.get("water", false):
			lines.append(tr("CELL_FERTILITY") % roundi(planet.fertility[_cell] * 100.0))
		var found := _visible_resources(_cell)
		if not found.is_empty():
			lines.append(tr("CELL_RESOURCES") % " · ".join(found))

	var can_build_here: bool = building_id == "" and not tdef.get("water", false) and eco.in_territory(_cell)
	if building_id == "" and not tdef.get("water", false) and not eco.in_territory(_cell):
		lines.append(tr("BUILD_ERR_TERRITORY"))
	_cell_text.text = "\n".join(lines)
	_cell_build_button.visible = can_build_here or _cell == eco.village_center
	_cell_build_button.text = tr("OPEN_TOWNHALL") if _cell == eco.village_center else tr("BUILD_HERE")
	_demolish_button.visible = building_id != "" and _cell != eco.village_center
	var upgrade_id: String = eco.upgrade_target(_cell) if building_id != "" else ""
	_upgrade_button.visible = upgrade_id != ""
	if upgrade_id != "":
		_upgrade_button.text = tr("UPGRADE") % [tr(str(eco.defs[upgrade_id].get("name_key", upgrade_id))), _cost_text(eco.upgrade_cost(_cell))]
		_upgrade_button.disabled = eco.can_upgrade(_cell) != ""
	_demolish_button.text = tr("DEMOLISH_CONFIRM") if _confirm_demolish else tr("DEMOLISH")


## One clear line about what a building is doing right now.
func _building_status(cell: int, bdef: Dictionary) -> String:
	var eco = GameState.sim.economy
	if not eco.is_active(cell):
		return tr("BLD_UNDER_CONSTRUCTION") % [roundi(eco.construction_progress(cell) * 100.0), _format_days(eco.construction_left(cell))]
	if cell == eco.village_center:
		if eco.townhall_upgrade_left >= 0.0:
			return tr("TH_UPGRADING") % [eco.townhall_level + 1, _format_days(eco.townhall_upgrade_days_left())]
		return tr("BLD_TOWNHALL_STATUS") % [eco.townhall_level, eco.housing()]
	var housing := int(bdef.get("housing", 0))
	if housing > 0:
		return tr("BLD_HOUSING") % housing
	var need := int(bdef.get("workers", 0))
	if need > 0 and eco.workers_at(cell) == 0:
		var profession := str(bdef.get("profession", ""))
		if profession != "" and not eco.townhall_levels.is_empty():
			return tr("BLD_NEEDS_TRAINED") % tr(str(eco.professions.get(profession, {}).get("name_key", profession)))
		return tr("BLD_IDLE")
	if bdef.has("happiness") and not bdef.has("produces"):
		return tr("BLD_GIVES_HAPPINESS") % int(bdef.happiness)
	if bdef.has("health"):
		return tr("BLD_GIVES_HEALTH") % [int(bdef.health), eco.workers_at(cell), need]
	if bdef.has("produces"):
		if eco.is_waiting(cell):
			var inputs := PackedStringArray()
			for res in bdef.get("consumes", {}):
				inputs.append(tr(_res_key(res)).to_lower())
			return tr("BLD_WAITING") % " + ".join(inputs)
		if bdef.has("extracts") and not eco.has_deposit(cell, str(bdef.extracts)):
			return tr("BLD_DEPLETED")
		var rate: Dictionary = eco.building_rate(cell)
		var out := PackedStringArray()
		for res in bdef.produces:
			out.append("%s %s" % [_format_signed(float(rate.get(res, 0.0))), tr(_res_key(res)).to_lower()])
		return tr("BLD_STATUS") % [" · ".join(out), eco.workers_at(cell), need]
	return tr(str(bdef.get("short_key", "")))


func _visible_resources(cell: int) -> PackedStringArray:
	var found := PackedStringArray()
	var res_defs: Dictionary = GameState.config.get("resources", {})
	var cell_res: Dictionary = GameState.sim.planet.resources[cell]
	for res_id in cell_res:
		var res_def: Dictionary = res_defs.get(res_id, {})
		if res_def.get("hidden", false):
			continue  # Revealed by a later age.
		found.append("%s %d" % [tr(str(res_def.get("name_key", res_id))), floori(float(cell_res[res_id]))])
	return found


func _on_upgrade_pressed() -> void:
	if GameState.sim.economy.upgrade(_cell):
		Haptics.medium()
		_show_toast(tr("UPGRADED"))
		GameState.sim.check_objectives()
	_update_cell_card()


func _on_demolish_pressed() -> void:
	if not _confirm_demolish:
		_confirm_demolish = true
		_update_cell_card()
		return
	if GameState.sim.economy.demolish(_cell):
		Haptics.medium()
	_confirm_demolish = false
	_update_cell_card()


# --- Needs ------------------------------------------------------------------------

func _build_needs_sheet() -> PanelContainer:
	var parts := _sheet(_label(tr("NEEDS_TITLE"), 20, TEXT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts[1].add_child(scroll)
	_needs_text = RichTextLabel.new()
	_needs_text.bbcode_enabled = true
	_needs_text.fit_content = true
	_needs_text.scroll_active = false
	_needs_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_needs_text.add_theme_font_size_override("normal_font_size", 15)
	_needs_text.add_theme_font_size_override("bold_font_size", 16)
	scroll.add_child(_needs_text)
	return parts[0]


func _toggle_needs_sheet() -> void:
	if _needs_sheet.visible:
		_close_sheets()
		return
	_end_placement()
	_tutorial_flags["needs"] = true
	_update_needs_sheet()
	_show_sheet(_needs_sheet)
	close_requested.emit()
	Haptics.light()


## Plain-language summary: each need, its state, and what moves it.
func _update_needs_sheet() -> void:
	var eco = GameState.sim.economy
	var t := ""
	var food_rate := float(eco.rates.get("food", 0.0))
	var water_rate := float(eco.rates.get("water", 0.0))
	t += _need_line(tr("RES_FOOD"), food_rate >= 0.0 or eco.stock("food") > 0.0, tr("NEED_FOOD") % [floori(eco.stock("food")), _format_signed(food_rate)])
	t += _need_line(tr("RES_WATER"), water_rate >= 0.0 or eco.stock("water") > 0.0, tr("NEED_WATER") % [floori(eco.stock("water")), _format_signed(water_rate)])
	t += _need_line(tr("NEED_HOUSING"), eco.population <= eco.housing(), tr("NEED_HOUSING_TEXT") % [eco.population, eco.housing()])
	t += _need_line(tr("NEED_WORK"), eco.employed() >= eco.population * 0.6, tr("NEED_WORK_TEXT") % [eco.employed(), eco.jobs()])
	t += "\n[b]%s : %d %%[/b]  [color=#8a7564](%s)[/color]\n" % [tr("HAPPINESS"), roundi(eco.happiness), tr("NEED_PRODUCTIVITY") % roundi(eco.productivity() * 100.0)]
	t += _factor_lines(eco.happiness_factors())
	t += "\n[b]%s : %d %%[/b]\n" % [tr("HEALTH"), roundi(eco.health)]
	t += _factor_lines(eco.health_factors())
	t += "\n[b]%s[/b]\n" % tr("NEED_STOCKS")
	for res in ["grain", "flour", "tools"]:
		t += "%s : %d\n" % [tr(_res_key(res)), floori(eco.stock(res))]
	t += "\n[color=#8a7564]%s[/color]" % tr("NEED_TIP")
	_needs_text.text = t


func _need_line(title: String, ok: bool, text: String) -> String:
	var color := "%s" % Design.HEX_GOOD if ok else "%s" % Design.HEX_BAD
	return "[color=%s]•[/color] [b]%s[/b] — %s\n" % [color, title, text]


func _factor_lines(factors: Array) -> String:
	var out := ""
	for f in factors:
		var value := float(f[1])
		if str(f[0]) == "WB_BASE":
			out += "   %s %d\n" % [tr("WB_BASE"), roundi(value)]
			continue
		var color := "%s" % Design.HEX_GOOD if value > 0.0 else "%s" % Design.HEX_BAD
		out += "   [color=%s]%s%d[/color] %s\n" % [color, "+" if value > 0.0 else "", roundi(value), tr(str(f[0]))]
	return out


# --- Settings -----------------------------------------------------------------

func _build_settings_sheet() -> PanelContainer:
	var parts := _sheet(_label(tr("SETTINGS"), 20, TEXT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts[1].add_child(scroll)
	var box := VBoxContainer.new()
	box.name = "Content"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	return parts[0]


## Rebuilt each time the sheet opens, so it always shows current values.
## Three tabs keep it short: Planet, Display, Game.
func _refresh_settings_sheet() -> void:
	var box: VBoxContainer = _settings_sheet.find_child("Content", true, false)
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var sim = GameState.sim
	var options: Dictionary = GameState.config.get("customization", {})

	var tabs := {"planet": {"name_key": "SECTION_PLANET", "order": 0}, "display": {"name_key": "SECTION_DISPLAY", "order": 1}, "game": {"name_key": "SECTION_GAME", "order": 2}}
	box.add_child(UiKit.choice_grid(tabs, _settings_tab, func(id: String):
		_settings_tab = id
		_refresh_settings_sheet.call_deferred()))

	match _settings_tab:
		"planet":
			box.add_child(_caption(tr("PLANET_NAME")))
			var name_row := HBoxContainer.new()
			name_row.add_theme_constant_override("separation", 8)
			var name_edit := LineEdit.new()
			name_edit.text = str(sim.custom.get("planet_name", ""))
			name_edit.max_length = 18
			name_edit.custom_minimum_size = Vector2(0, 46)
			name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_edit.text_changed.connect(func(text: String):
				if text.strip_edges() != "":
					sim.custom["planet_name"] = text.strip_edges()
					_refresh_title())
			name_row.add_child(name_edit)
			var dice := _icon_button("dice", "", Vector2(46, 46))
			dice.pressed.connect(func():
				var new_name: String = sim.generate_name(randi(), sim.name_syllables)
				sim.custom["planet_name"] = new_name
				name_edit.text = new_name
				_refresh_title()
				Haptics.light())
			name_row.add_child(dice)
			box.add_child(name_row)
			box.add_child(_caption(tr("PALETTE")))
			box.add_child(UiKit.choice_grid(options.get("palettes", {}), str(sim.custom.get("palette", "classic")), func(id: String):
				sim.custom["palette"] = id
				appearance_changed.emit()
				Haptics.light()))
			box.add_child(_caption(tr("VILLAGE_COLOR")))
			box.add_child(UiKit.swatches(options.get("village_colors", []), str(sim.custom.get("village_color", "")), func(hex: String):
				sim.custom["village_color"] = hex
				appearance_changed.emit()
				Haptics.light()))
			box.add_child(_caption(tr("DECORATIONS")))
			for key in ["rings", "moon"]:
				var toggle := CheckButton.new()
				toggle.text = tr("DECOR_" + key.to_upper())
				toggle.icon = _texture(key)
				toggle.add_theme_constant_override("icon_max_width", 28)
				toggle.custom_minimum_size = Vector2(0, 44)
				toggle.button_pressed = bool(sim.custom.get(key, false))
				toggle.toggled.connect(func(on: bool):
					sim.custom[key] = on
					appearance_changed.emit())
				box.add_child(toggle)
		"display":
			box.add_child(_caption(tr("SKY")))
			box.add_child(UiKit.choice_grid(options.get("skies", {}), str(UserSettings.get_value("sky")), func(id: String):
				UserSettings.set_value("sky", id)
				appearance_changed.emit()
				Haptics.light()))
			box.add_child(_toggle(tr("CLOUDS"), "clouds", true))
			box.add_child(_toggle(tr("OUTLINES"), "outlines", true))
		"game":
			box.add_child(_toggle(tr("HAPTICS"), "haptics", false))
			box.add_child(_caption(tr("LANGUAGE")))
			var current_lang := str(UserSettings.get_value("language"))
			if current_lang == "":
				current_lang = TranslationServer.get_locale().substr(0, 2)
			box.add_child(UiKit.choice_grid({"fr": {"name_key": "LANG_FR", "order": 0}, "en": {"name_key": "LANG_EN", "order": 1}}, current_lang, func(id: String):
				UserSettings.set_value("language", id)
				GameState.save_game()
				get_tree().reload_current_scene()))
			var tuto := _icon_button("help", tr("START_TUTORIAL"), Vector2(0, 50))
			tuto.pressed.connect(func():
				_close_sheets()
				restart_tutorial())
			box.add_child(tuto)
			var new_planet := _icon_button("build", tr("START_NEW"), Vector2(0, 50))
			new_planet.pressed.connect(func():
				_close_sheets()
				_start_menu.open("new"))
			box.add_child(new_planet)
			var home := _icon_button("play", tr("START_SCREEN"), Vector2(0, 50))
			home.pressed.connect(func():
				_close_sheets()
				_start_menu.open("main"))
			box.add_child(home)
			box.add_child(_label(tr("VERSION") % ProjectSettings.get_setting("application/config/version", "?"), 11, Design.INK_FAINT))


func _section(text: String) -> Label:
	var label := _label(text, 16, TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


func _caption(text: String) -> Label:
	var label := _label(text, 13, MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Toggle buttons (one choice) laid out on 2-3 columns.
func _choice_grid(choices: Dictionary, current: String, on_pick: Callable) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3 if choices.size() >= 3 else 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var ids: Array = choices.keys()
	ids.sort_custom(func(a, b): return int(choices[a].get("order", 0)) < int(choices[b].get("order", 0)))
	var group := ButtonGroup.new()
	for id in ids:
		var choice: Dictionary = choices[id]
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = tr(str(choice.get("name_key", id)))
		if choice.has("cells"):
			button.text += "\n" + tr("CELLS_N") % int(choice.cells)
		button.button_pressed = str(id) == current
		button.pressed.connect(func():
			on_pick.call(str(id))
			Haptics.light())
		grid.add_child(button)
	return grid


func _toggle(text: String, key: String, affects_view: bool) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.custom_minimum_size = Vector2(0, 44)
	toggle.button_pressed = bool(UserSettings.get_value(key))
	toggle.toggled.connect(func(on: bool):
		UserSettings.set_value(key, on)
		if affects_view:
			appearance_changed.emit())
	return toggle


# =============================================================================
# Tutorial
# =============================================================================

func _build_tutorial_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Design.panel(Design.SKY_SOFT, 20, 12))
	panel.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(_icon("help", 34))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	_tutorial_count = _label("", 11, MUTED)
	_tutorial_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(_tutorial_count)
	_tutorial_text = _label("", 15, TEXT)
	_tutorial_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(_tutorial_text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	texts.add_child(buttons)
	var skip := Button.new()
	skip.text = tr("TUTO_SKIP")
	skip.custom_minimum_size = Vector2(0, 38)
	skip.pressed.connect(func():
		GameState.sim.tutorial_step = -1
		_refresh_tutorial())
	buttons.add_child(skip)
	_tutorial_next = Button.new()
	_tutorial_next.text = tr("TUTO_NEXT")
	_tutorial_next.custom_minimum_size = Vector2(0, 38)
	_tutorial_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Design.make_primary(_tutorial_next, 14)
	_tutorial_next.pressed.connect(_advance_tutorial)
	buttons.add_child(_tutorial_next)
	return panel


func restart_tutorial() -> void:
	GameState.sim.tutorial_step = 0
	_tutorial_flags.clear()
	_refresh_tutorial()


func on_planet_rotated() -> void:
	_tutorial_flags["rotate"] = true


func on_planet_zoomed() -> void:
	_tutorial_flags["zoom"] = true


func _current_step() -> Dictionary:
	var index: int = GameState.sim.tutorial_step
	if index < 0 or index >= _tutorial_steps.size():
		return {}
	return _tutorial_steps[index]


func _refresh_tutorial() -> void:
	var step := _current_step()
	_stop_pulse()
	if step.is_empty():
		_tutorial_panel.visible = false
		if GameState.sim.tutorial_step >= _tutorial_steps.size():
			GameState.sim.tutorial_step = -1
		return
	_tutorial_panel.visible = true
	_tutorial_count.text = tr("TUTO_STEP") % [GameState.sim.tutorial_step + 1, _tutorial_steps.size()]
	var text := tr(str(step.get("text_key", "")))
	if text.contains("%s"):
		text = text % GameState.sim.custom.get("planet_name", "")
	_tutorial_text.text = text
	_tutorial_next.visible = str(step.get("condition", "")) == "next"
	match str(step.get("highlight", "")):
		"build":
			_start_pulse(_build_button)
		"needs":
			_start_pulse(_needs_row)
		"speed":
			_start_pulse(_speed_button)
		"goals", "village":
			_start_pulse(_goals_button)


func _advance_tutorial() -> void:
	GameState.sim.tutorial_step += 1
	_tutorial_flags.clear()
	Haptics.light()
	_refresh_tutorial()


## Moves to the next step as soon as its condition is met.
func _check_tutorial() -> void:
	var step := _current_step()
	if step.is_empty():
		return
	var condition := str(step.get("condition", "next"))
	var done := false
	if condition.begins_with("building:"):
		var parts := condition.split(":")
		done = GameState.sim.planet.buildings.count(parts[1]) >= int(parts[2])
	elif condition.begins_with("trained:"):
		var parts := condition.split(":")
		done = GameState.sim.economy.trained_count(parts[1]) >= int(parts[2])
	elif condition != "next":
		done = _tutorial_flags.get(condition, false)
	if done:
		_advance_tutorial()


func _start_pulse(control: Control) -> void:
	_pulsing = control
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(control, "modulate", Color(1.2, 1.05, 0.75), 0.5)
	_pulse_tween.tween_property(control, "modulate", Color.WHITE, 0.5)


func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	if _pulsing:
		_pulsing.modulate = Color.WHITE
		_pulsing = null


# =============================================================================
# Goals
# =============================================================================

func _on_goals_pressed() -> void:
	_tutorial_flags["goals"] = true
	_tutorial_flags["village"] = true
	if _goals_sheet.visible:
		_close_sheets()
		return
	_end_placement()
	_village_signature = ""
	_update_goals_sheet()
	_show_sheet(_goals_sheet)
	close_requested.emit()
	Haptics.light()


func _build_goals_sheet() -> PanelContainer:
	var parts := _sheet(_label(tr("VILLAGE_TITLE"), 20, TEXT))
	var tabs := {"townhall": {"name_key": "TAB_TOWNHALL", "order": 0}, "people": {"name_key": "TAB_PEOPLE", "order": 1}, "goals": {"name_key": "TAB_GOALS", "order": 2}}
	var tab_holder := VBoxContainer.new()
	tab_holder.name = "Tabs"
	parts[1].add_child(tab_holder)
	tab_holder.add_child(UiKit.choice_grid(tabs, _village_tab, func(id: String):
		_village_tab = id
		_village_signature = ""
		_update_goals_sheet()
		Haptics.light()))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts[1].add_child(scroll)
	_goals_list = VBoxContainer.new()
	_goals_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goals_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_goals_list)
	return parts[0]


## Rebuilt only when something visible changed (so buttons stay pressable).
func _update_goals_sheet() -> void:
	var eco = GameState.sim.economy
	var signature := str([_village_tab, eco.townhall_level, snappedf(eco.townhall_upgrade_left, 0.02), eco.trained,
		eco.training.size(), eco.population, floori(eco.stock("food")), floori(eco.stock("wood")), floori(eco.stock("stone")),
		GameState.sim.completed_objectives.size(), eco.free_builders()])
	if signature == _village_signature:
		return
	_village_signature = signature
	for child in _goals_list.get_children():
		_goals_list.remove_child(child)
		child.queue_free()
	match _village_tab:
		"townhall":
			_fill_townhall_tab()
		"people":
			_fill_people_tab()
		_:
			_fill_goals_tab()


func _fill_goals_tab() -> void:
	var sim = GameState.sim
	var shown := 0
	var done_count := 0
	for obj in sim.objective_defs:
		var done: bool = str(obj.id) in sim.completed_objectives
		if done:
			done_count += 1
	_goals_list.add_child(_caption(tr("GOALS_PROGRESS") % [done_count, sim.objective_defs.size()]))
	# Unfinished goals first (the next 5), then the completed ones.
	for pass_done in [false, true]:
		for obj in sim.objective_defs:
			var done: bool = str(obj.id) in sim.completed_objectives
			if done != pass_done or (not done and shown >= 5):
				continue
			if not done:
				shown += 1
			_goals_list.add_child(_goal_row(obj, done))


## Town hall: level, skills, next level (unlocks, conditions, cost), upgrade.
func _fill_townhall_tab() -> void:
	var eco = GameState.sim.economy
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(_icon("townhall", 48))
	var head_text := VBoxContainer.new()
	head_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_text)
	var title := _label(tr("TH_LEVEL") % [eco.townhall_level, eco.max_level()], 18, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_override("font", Design.title_font())
	head_text.add_child(title)
	head_text.add_child(_caption(tr("TH_STATS") % [eco.housing(), eco.free_builders(), eco.builders(), eco.training_slots()]))
	_goals_list.add_child(head)

	var perk_names := PackedStringArray()
	for perk in eco.perks():
		perk_names.append(tr(str(perk.name_key)))
	if not perk_names.is_empty():
		_goals_list.add_child(_info_card(tr("TH_SKILLS"), " · ".join(perk_names), Design.TEAL_SOFT))

	if eco.townhall_upgrade_left >= 0.0:
		var card := _info_card(tr("TH_UPGRADING_TITLE") % (eco.townhall_level + 1), tr("TH_TIME_LEFT") % _format_days(eco.townhall_upgrade_days_left()), Design.SKY_SOFT)
		var bar := ProgressBar.new()
		var total := float(eco.level_def(eco.townhall_level + 1).get("days", 1.0))
		bar.max_value = 1.0
		bar.value = 1.0 - eco.townhall_upgrade_left / maxf(total, 0.01)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 12)
		card.get_child(0).add_child(bar)
		_goals_list.add_child(card)
		return
	if eco.townhall_level >= eco.max_level():
		_goals_list.add_child(_info_card(tr("TH_MAX"), tr("TH_MAX_TEXT"), Design.CREAM_DEEP))
		return

	var next: Dictionary = eco.level_def(eco.townhall_level + 1)
	var unlocks := PackedStringArray()
	var current: Dictionary = eco.level_def().get("buildings", {})
	for id in next.get("buildings", {}):
		if int(current.get(id, 0)) <= 0:
			unlocks.append(tr(str(eco.defs.get(id, {}).get("name_key", id))))
	for p in next.get("professions", []):
		if not (p in eco.level_def().get("professions", [])):
			unlocks.append(tr(str(eco.professions.get(p, {}).get("name_key", p))))
	for perk in next.get("perks", []):
		unlocks.append(tr(str(perk.name_key)))
	var lines := PackedStringArray()
	if not unlocks.is_empty():
		lines.append(tr("TH_UNLOCKS") % ", ".join(unlocks))
	lines.append(tr("TH_MORE") % [int(next.get("housing", 0)), int(next.get("builders", 1))])
	var need_pop := int(next.get("requires", {}).get("population", 0))
	lines.append(tr("TH_NEEDS_POP") % [need_pop, eco.population])
	lines.append(tr("TH_COST") % [_cost_text(next.get("cost", {})), _format_days(float(next.get("days", 1.0)))])
	_goals_list.add_child(_info_card(tr("TH_NEXT") % (eco.townhall_level + 1), "\n".join(lines), Design.CARD))
	var button := _icon_button("townhall", tr("TH_UPGRADE"), Vector2(0, 56))
	Design.make_primary(button, 18)
	var reason: String = eco.can_upgrade_townhall()
	button.disabled = reason != ""
	if reason != "":
		button.text = tr(reason)
	button.pressed.connect(func():
		if GameState.sim.economy.upgrade_townhall():
			Haptics.medium()
			_show_toast(tr("TH_STARTED"))
			_village_signature = ""
			_update_goals_sheet())
	_goals_list.add_child(button)


## Villagers: idle count, trainings in progress, one row per profession.
func _fill_people_tab() -> void:
	var eco = GameState.sim.economy
	_goals_list.add_child(_caption(tr("PEOPLE_SUMMARY") % [eco.idle_villagers(), eco.population, eco.training.size(), eco.training_slots()]))
	for t in eco.training:
		var pdef: Dictionary = eco.professions.get(t.profession, {})
		var days := float(pdef.get("days", 0.25))
		var card := _info_card(tr("TRAINING_ROW") % tr(str(pdef.get("name_key", t.profession))), "", Design.SKY_SOFT)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = 1.0 - float(t.left) / maxf(days, 0.01)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		card.get_child(0).add_child(bar)
		_goals_list.add_child(card)
	var ids: Array = eco.professions.keys()
	for id in ids:
		var pdef: Dictionary = eco.professions[id]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", Design.panel(Design.CARD, 16, 8, eco.is_profession_unlocked(id)))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		row.add_child(line)
		line.add_child(_icon(str(pdef.get("icon", "people")), 32))
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(texts)
		var pname := _label(tr(str(pdef.get("name_key", id))), 15, TEXT)
		pname.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		texts.add_child(pname)
		if not eco.is_profession_unlocked(id):
			texts.add_child(_caption(tr("LOCKED_AT") % _profession_unlock_level(id)))
			row.modulate = Color(1, 1, 1, 0.55)
			_goals_list.add_child(row)
			continue
		texts.add_child(_caption(tr("PROF_STATUS") % [eco.trained_count(id), eco.profession_jobs(id)]))
		var minus := Button.new()
		minus.text = "-"
		minus.custom_minimum_size = Vector2(40, 44)
		minus.disabled = eco.trained_count(id) <= 0
		minus.pressed.connect(func():
			GameState.sim.economy.untrain(id)
			_village_signature = ""
			_update_goals_sheet())
		line.add_child(minus)
		var train := Button.new()
		var reason: String = eco.can_train(id)
		train.text = tr("TRAIN") % _cost_text(pdef.get("cost", {})) if reason == "" or reason == Economy.ERR_COST else tr(reason)
		train.custom_minimum_size = Vector2(118, 44)
		train.clip_text = true
		train.disabled = reason != ""
		if reason == "":
			Design.make_primary(train, 14)
		train.pressed.connect(func():
			if GameState.sim.economy.train(id):
				Haptics.light()
			_village_signature = ""
			_update_goals_sheet())
		line.add_child(train)
		_goals_list.add_child(row)


func _profession_unlock_level(profession: String) -> int:
	for def in GameState.sim.economy.townhall_levels:
		if profession in def.get("professions", []):
			return int(def.level)
	return 0


func _info_card(title: String, text: String, color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Design.panel(color, 16, 10, false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var t := _label(title, 15, TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_override("font", Design.title_font())
	box.add_child(t)
	if text != "":
		var body := _label(text, 13, MUTED)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(body)
	return card


## Game days shown as real time at normal speed (1 day = 60 s at x1).
func _format_days(days: float) -> String:
	var sim = GameState.sim
	var seconds := days * float(sim.ticks_per_day) / float(GameState.config.get("tick_rate_hz", 10))
	if seconds < 60.0:
		return tr("TIME_SECONDS") % maxi(1, ceili(seconds))
	return tr("TIME_MINUTES") % maxi(1, roundi(seconds / 60.0))


func _on_construction_done(cell: int) -> void:
	var id: String = GameState.sim.planet.buildings[cell]
	_show_toast(tr("CONSTRUCTION_DONE") % tr(str(GameState.sim.economy.defs.get(id, {}).get("name_key", id))))
	Haptics.light()
	GameState.sim.check_objectives()


func _on_training_done(profession: String) -> void:
	var name_key := str(GameState.sim.economy.professions.get(profession, {}).get("name_key", profession))
	_show_toast(tr("TRAINING_DONE") % tr(name_key))
	GameState.sim.check_objectives()


## Big celebration card when the town hall reaches a new level.
func _show_level_up(level: int) -> void:
	var eco = GameState.sim.economy
	_end_placement()
	_event_title.text = tr("LEVEL_UP_TITLE") % level
	var unlocks := PackedStringArray()
	var previous: Dictionary = eco.level_def(level - 1).get("buildings", {})
	for id in eco.level_def(level).get("buildings", {}):
		if int(previous.get(id, 0)) <= 0:
			unlocks.append(tr(str(eco.defs.get(id, {}).get("name_key", id))))
	for perk in eco.level_def(level).get("perks", []):
		unlocks.append(tr(str(perk.name_key)))
	_event_text.text = tr("LEVEL_UP_TEXT") % (", ".join(unlocks) if not unlocks.is_empty() else tr("LEVEL_UP_MORE"))
	for child in _event_choices.get_children():
		_event_choices.remove_child(child)
		child.queue_free()
	var ok := Button.new()
	ok.text = tr("LEVEL_UP_OK")
	ok.custom_minimum_size = Vector2(0, 54)
	Design.make_primary(ok, 18)
	ok.pressed.connect(func(): _close_sheets())
	_event_choices.add_child(ok)
	_show_sheet(_event_sheet)
	GameState.sim.check_objectives()
	Haptics.medium()


func _goal_row(obj: Dictionary, done: bool) -> PanelContainer:
	var sim = GameState.sim
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Design.panel(Design.TEAL_SOFT if done else Design.CARD, 16, 10, not done))
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := tr(str(obj.title_key))
	if title.contains("%d"):
		title = title % int(obj.value)
	elif title.contains("%s"):
		title = title % str(obj.value)
	var head := _label(("OK  " if done else "") + title, 15, GOOD if done else TEXT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(head)
	if not done:
		var p := Objectives.progress(sim, obj)
		var bar := ProgressBar.new()
		bar.max_value = float(p[1])
		bar.value = float(p[0])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		box.add_child(bar)
		box.add_child(_caption(tr("GOAL_STATUS") % [floori(float(p[0])), int(p[1]), _cost_text(obj.get("reward", {}))]))
	return panel


func _on_objective_completed(id: String) -> void:
	for obj in GameState.sim.objective_defs:
		if str(obj.id) == id:
			var title := tr(str(obj.title_key))
			if title.contains("%d"):
				title = title % int(obj.value)
			_show_toast(tr("GOAL_DONE") % [title, _cost_text(obj.get("reward", {}))])
			Haptics.medium()


# =============================================================================
# Events
# =============================================================================

func _build_event_sheet() -> PanelContainer:
	_event_title = _label("", 20, TEXT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Design.panel(Design.PARCHMENT, 26, 16))
	panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(_icon("event", 36))
	_event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_event_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_event_title)
	box.add_child(head)
	_event_text = _label("", 15, TEXT)
	_event_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_event_text)
	_event_choices = VBoxContainer.new()
	_event_choices.add_theme_constant_override("separation", 8)
	box.add_child(_event_choices)
	return panel


func _show_event(id: String) -> void:
	var ev := Events.find(GameState.sim.event_defs, id)
	if ev.is_empty():
		return
	_end_placement()
	_event_title.text = tr(str(ev.title_key))
	_event_text.text = tr(str(ev.text_key))
	for child in _event_choices.get_children():
		_event_choices.remove_child(child)
		child.queue_free()
	var choices: Array = ev.get("choices", [])
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var b := Button.new()
		b.text = "%s\n%s" % [tr(str(choice.label_key)), _effects_text(choice.get("effects", {}))]
		b.custom_minimum_size = Vector2(0, 58)
		b.pressed.connect(func():
			GameState.sim.resolve_event(i)
			Haptics.light()
			_close_sheets())
		_event_choices.add_child(b)
	_show_sheet(_event_sheet)
	close_requested.emit()
	Haptics.medium()


func _effects_text(effects: Dictionary) -> String:
	if effects.is_empty():
		return tr("EV_NOTHING")
	var parts := PackedStringArray()
	for key in effects:
		var value := float(effects[key])
		var label := ""
		match str(key):
			"population":
				label = tr("EFFECT_PEOPLE")
			"happiness":
				label = tr("HAPPINESS").to_lower()
			"health":
				label = tr("HEALTH").to_lower()
			_:
				label = tr(_res_key(str(key))).to_lower()
		parts.append("%s%d %s" % ["+" if value > 0.0 else "", int(value), label])
	return " · ".join(parts)


# =============================================================================
# Helpers
# =============================================================================

func _texture(icon_id: String) -> Texture2D:
	var path := ICON_DIR + icon_id + ".svg"
	return load(path) if ResourceLoader.exists(path) else null


func _icon(icon_id: String, size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = _texture(icon_id)
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _icon_button(icon_name: String, text: String, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	if icon_name != "":
		button.icon = _texture(icon_name)
	button.custom_minimum_size = min_size
	button.clip_text = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if text == "" else HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", 30)
	button.add_theme_font_size_override("font_size", 18)
	return button


func _box(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


func _res_key(res: String) -> String:
	var res_def: Dictionary = GameState.config.get("resources", {}).get(res, {})
	return str(res_def.get("name_key", "RES_" + res.to_upper()))


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for res in cost:
		parts.append("%d %s" % [int(cost[res]), tr(_res_key(res)).to_lower()])
	return " + ".join(parts) if not parts.is_empty() else tr("FREE")


func _format_signed(value: float) -> String:
	var text := ("%.1f" % absf(value)).replace(".", tr("DECIMAL_SEPARATOR"))
	return ("+" if value >= 0.0 else "-") + text


## Converts the OS safe area (screen pixels) into viewport units and pads the UI.
func _apply_safe_area() -> void:
	var insets := [0.0, 0.0, 0.0, 0.0]  # left, top, right, bottom
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.window_get_size()
		var view := get_viewport().get_visible_rect().size
		if screen.x > 0 and screen.y > 0:
			var k := view / Vector2(screen)
			insets = [
				safe.position.x * k.x,
				safe.position.y * k.y,
				(screen.x - safe.end.x) * k.x,
				(screen.y - safe.end.y) * k.y,
			]
	_margin.add_theme_constant_override("margin_left", int(insets[0] + BASE_PADDING))
	_margin.add_theme_constant_override("margin_top", int(insets[1] + BASE_PADDING))
	_margin.add_theme_constant_override("margin_right", int(insets[2] + BASE_PADDING))
	_margin.add_theme_constant_override("margin_bottom", int(insets[3] + BASE_PADDING))


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The "Diorama doux" theme (see scripts/ui/design.gd).
func _make_theme() -> Theme:
	return Design.make_theme()
