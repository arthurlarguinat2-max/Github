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
const ICON_DIR := "res://assets/icons/ui/"

const BASE_PADDING := 14.0
const REFRESH_INTERVAL := 0.25
const TEXT := Color("f2f4ff")
const MUTED := Color("aab4d4")
const WARN := Color("ffb36b")
const GOOD := Color("8fd18f")
const BAD := Color("ff8b7b")
const PANEL_BG := Color(0.09, 0.11, 0.18, 0.95)
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
var _bottom_bar: HBoxContainer

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

	_title = _label("", 17, MUTED)
	column.add_child(_title)
	column.add_child(_build_chips())
	_toast = _label("", 15, WARN)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_toast)

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
	_sheets.append_array([_build_sheet, _cell_card, _settings_sheet])

	_hint = _label(tr("HINT_DRAG"), 13, Color("7c86a8"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	_bottom_bar = _build_bottom_bar()
	column.add_child(_bottom_bar)

	_blocking.append_array([_bottom_bar, _banner, _build_sheet, _cell_card, _settings_sheet])
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	GameState.ticked.connect(_refresh_title)
	GameState.sim.economy.alert.connect(_on_alert)
	_last_speed = GameState.sim.speed if GameState.sim.speed > 0 else 1
	_refresh_title()
	_refresh_chips()
	_refresh_speed_buttons()
	if GameState.pending_offline_days > 0:
		_show_toast(tr("OFFLINE_WELCOME") % GameState.pending_offline_days)
		GameState.pending_offline_days = 0


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer < REFRESH_INTERVAL:
		return
	_refresh_timer = 0.0
	_refresh_chips()
	if _cell_card.visible:
		_update_cell_card()
	if _build_sheet.visible:
		_update_build_cards()


## True when `point` (viewport coordinates) is over an interactive UI element.
func blocks_point(point: Vector2) -> bool:
	for control in _blocking:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return true
	return false


# =============================================================================
# Top: title and resource chips
# =============================================================================

func _build_chips() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for res in ["food", "wood", "stone", "people"]:
		var chip := PanelContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel", _box(Color(0.1, 0.12, 0.2, 0.82), 12, 6))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(line)
		line.add_child(_icon(res, 26))
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", -4)
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(texts)
		var value := _label("", 16, TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		texts.add_child(value)
		var rate := _label("", 11, MUTED)
		rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		texts.add_child(rate)
		row.add_child(chip)
		_chips[res] = {"value": value, "rate": rate}
	return row


func _refresh_chips() -> void:
	var eco = GameState.sim.economy
	for res in ["food", "wood", "stone"]:
		var chip: Dictionary = _chips[res]
		var rate := float(eco.rates.get(res, 0.0))
		chip.value.text = str(floori(eco.stock(res)))
		chip.rate.text = (_format_signed(rate) + tr("PER_DAY")) if absf(rate) >= 0.05 else "—"
		chip.rate.add_theme_color_override("font_color", GOOD if rate > 0.05 else (BAD if rate < -0.05 else MUTED))
		if res == "food" and eco.stock("food") <= 0.0:
			chip.value.add_theme_color_override("font_color", BAD)
		else:
			chip.value.add_theme_color_override("font_color", TEXT)
	var people: Dictionary = _chips["people"]
	people.value.text = "%d/%d" % [eco.population, eco.housing()]
	people.rate.text = tr("WORKERS_SHORT") % [eco.employed(), eco.jobs()]


func _refresh_title() -> void:
	_title.text = "%s · %s" % [GameState.sim.custom.get("planet_name", ""), tr("DAY_N") % GameState.sim.day()]


func _on_alert(key: String) -> void:
	_show_toast(tr(key))
	Haptics.medium()


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(4.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 1.0)


# =============================================================================
# Bottom bar: pause, speed, build, settings
# =============================================================================

func _build_bottom_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	_pause_button = _icon_button("pause", "", Vector2(58, 58))
	_pause_button.pressed.connect(_on_pause_pressed)
	bar.add_child(_pause_button)
	_speed_button = _icon_button("", "x1", Vector2(58, 58))
	_speed_button.pressed.connect(_on_speed_pressed)
	bar.add_child(_speed_button)
	_build_button = _icon_button("build", tr("BUILD"), Vector2(0, 58))
	_build_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_button.add_theme_stylebox_override("normal", _box(Color(0.3, 0.5, 0.9, 0.95), 16, 8))
	_build_button.add_theme_stylebox_override("hover", _box(Color(0.35, 0.56, 0.95, 0.95), 16, 8))
	_build_button.pressed.connect(_on_build_pressed)
	bar.add_child(_build_button)
	_settings_button = _icon_button("settings", "", Vector2(58, 58))
	_settings_button.pressed.connect(_on_settings_pressed)
	bar.add_child(_settings_button)
	return bar


func _on_pause_pressed() -> void:
	var sim = GameState.sim
	sim.set_speed(_last_speed if sim.speed == 0 else 0)
	Haptics.light()
	_refresh_speed_buttons()


func _on_speed_pressed() -> void:
	var index := SPEEDS.find(_last_speed)
	_last_speed = SPEEDS[(index + 1) % SPEEDS.size()]
	GameState.sim.set_speed(_last_speed)
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


func _close_sheets() -> void:
	for s in _sheets:
		s.visible = false
	_hint.visible = _placing == ""


func _sheet(title_label: Label) -> Array:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL_BG, 20, 14))
	panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	_build_list = VBoxContainer.new()
	_build_list.add_theme_constant_override("separation", 6)
	parts[1].add_child(_build_list)
	return parts[0]


## Opens the build menu. With a cell: builds right there; without: 2-tap flow.
func _open_build_sheet(cell: int) -> void:
	_end_placement()
	_target_cell = cell
	_build_sheet_title.text = tr("BUILD_HERE") if cell >= 0 else tr("BUILD_WHAT")
	for child in _build_list.get_children():
		_build_list.remove_child(child)
		child.queue_free()
	var eco = GameState.sim.economy
	var ids: Array = eco.defs.keys()
	ids.sort_custom(func(a, b): return int(eco.defs[a].get("order", 99)) < int(eco.defs[b].get("order", 99)))
	for id in ids:
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
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.icon = _texture(id)
	card.expand_icon = false
	card.add_theme_constant_override("icon_max_width", 40)
	card.add_theme_constant_override("h_separation", 12)
	card.text = "%s  ·  %s\n%s" % [tr(str(bdef.get("name_key", id))), _cost_text(bdef.get("cost", {})), tr(str(bdef.get("short_key", "")))]
	card.pressed.connect(_on_build_card_pressed.bind(id))
	return card


func _update_build_cards() -> void:
	var eco = GameState.sim.economy
	for card in _build_list.get_children():
		var id := str(card.name)
		var ok: bool
		if _target_cell >= 0:
			ok = eco.can_build(_target_cell, id) == ""
		else:
			ok = eco.can_afford(eco.defs[id].get("cost", {}))
		(card as Button).disabled = not ok


func _on_build_card_pressed(id: String) -> void:
	var eco = GameState.sim.economy
	if _target_cell >= 0:
		if eco.build(_target_cell, id):
			Haptics.medium()
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
	panel.add_theme_stylebox_override("panel", _box(Color(0.16, 0.36, 0.22, 0.95), 16, 10))
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
			_show_toast(tr("BUILT") % tr(str(eco.defs[id].get("name_key", id))))
			_end_placement()
		else:
			_show_toast(tr(reason))
		close_requested.emit()
		return
	_cell = cell
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
	_cell_text = _label("", 15, Color("c4cbe6"))
	_cell_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cell_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_cell_text)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	_cell_build_button = _icon_button("build", tr("BUILD_HERE"), Vector2(0, 50))
	_cell_build_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cell_build_button.pressed.connect(func(): _open_build_sheet(_cell))
	actions.add_child(_cell_build_button)
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
	_cell_build_button.visible = can_build_here
	_demolish_button.visible = building_id != "" and _cell != eco.village_center
	_demolish_button.text = tr("DEMOLISH_CONFIRM") if _confirm_demolish else tr("DEMOLISH")


## One clear line about what a building is doing right now.
func _building_status(cell: int, bdef: Dictionary) -> String:
	var eco = GameState.sim.economy
	if cell == eco.village_center:
		return tr("BLD_VILLAGE_CENTER")
	var housing := int(bdef.get("housing", 0))
	if housing > 0:
		return tr("BLD_HOUSING") % housing
	var need := int(bdef.get("workers", 0))
	if bdef.has("produces"):
		if need > 0 and eco.workers_at(cell) == 0:
			return tr("BLD_IDLE")
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


func _on_demolish_pressed() -> void:
	if not _confirm_demolish:
		_confirm_demolish = true
		_update_cell_card()
		return
	if GameState.sim.economy.demolish(_cell):
		Haptics.medium()
	_confirm_demolish = false
	_update_cell_card()


# --- Settings -----------------------------------------------------------------

func _build_settings_sheet() -> PanelContainer:
	var parts := _sheet(_label(tr("SETTINGS"), 20, TEXT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts[1].add_child(scroll)
	var box := VBoxContainer.new()
	box.name = "Content"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	return parts[0]


## Rebuilt each time the sheet opens, so it always shows current values.
func _refresh_settings_sheet() -> void:
	var box: VBoxContainer = _settings_sheet.find_child("Content", true, false)
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var sim = GameState.sim
	var options: Dictionary = GameState.config.get("customization", {})

	# --- My planet
	box.add_child(_section(tr("SECTION_PLANET")))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	var name_edit := LineEdit.new()
	name_edit.text = str(sim.custom.get("planet_name", ""))
	name_edit.max_length = 18
	name_edit.placeholder_text = tr("PLANET_NAME")
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
	box.add_child(_choice_grid(options.get("palettes", {}), str(sim.custom.get("palette", "classic")), func(id: String):
		sim.custom["palette"] = id
		appearance_changed.emit()))

	box.add_child(_caption(tr("VILLAGE_COLOR")))
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for hex in options.get("village_colors", []):
		var swatch := Button.new()
		swatch.toggle_mode = true
		swatch.button_group = group
		swatch.custom_minimum_size = Vector2(44, 44)
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var color := Color(str(hex))
		swatch.add_theme_stylebox_override("normal", _box(color, 22, 0))
		swatch.add_theme_stylebox_override("hover", _box(color.lightened(0.1), 22, 0))
		var chosen := _box(color, 22, 0)
		chosen.set_border_width_all(4)
		chosen.border_color = Color.WHITE
		swatch.add_theme_stylebox_override("pressed", chosen)
		swatch.add_theme_stylebox_override("hover_pressed", chosen)
		swatch.button_pressed = str(hex) == str(sim.custom.get("village_color", ""))
		swatch.pressed.connect(func():
			sim.custom["village_color"] = str(hex)
			appearance_changed.emit()
			Haptics.light())
		swatches.add_child(swatch)
	box.add_child(swatches)

	# --- Display
	box.add_child(_section(tr("SECTION_DISPLAY")))
	box.add_child(_caption(tr("SKY")))
	box.add_child(_choice_grid(options.get("skies", {}), str(UserSettings.get_value("sky")), func(id: String):
		UserSettings.set_value("sky", id)
		appearance_changed.emit()))
	box.add_child(_toggle(tr("CLOUDS"), "clouds", true))
	box.add_child(_toggle(tr("OUTLINES"), "outlines", true))

	# --- Game
	box.add_child(_section(tr("SECTION_GAME")))
	box.add_child(_toggle(tr("HAPTICS"), "haptics", false))
	box.add_child(_caption(tr("LANGUAGE")))
	var current_lang := str(UserSettings.get_value("language"))
	if current_lang == "":
		current_lang = TranslationServer.get_locale().substr(0, 2)
	box.add_child(_choice_grid({"fr": {"name_key": "LANG_FR", "order": 0}, "en": {"name_key": "LANG_EN", "order": 1}}, current_lang, func(id: String):
		UserSettings.set_value("language", id)
		GameState.save_game()
		get_tree().reload_current_scene()))

	# --- New planet
	box.add_child(_section(tr("SECTION_NEW_PLANET")))
	box.add_child(_caption(tr("NEW_PLANET_INFO")))
	var sizes := {}
	for size in options.get("planet_sizes", []):
		sizes[str(size.frequency)] = {"name_key": size.name_key, "order": int(size.frequency), "cells": 10 * int(size.frequency) * int(size.frequency) + 2}
	_new_world_size = sim.planet.grid.frequency
	box.add_child(_choice_grid(sizes, str(_new_world_size), func(id: String):
		_new_world_size = int(id)
		_confirm_new_world = false))
	var create := Button.new()
	create.custom_minimum_size = Vector2(0, 50)
	create.text = tr("NEW_PLANET")
	create.pressed.connect(func():
		if not _confirm_new_world:
			_confirm_new_world = true
			create.text = tr("NEW_PLANET_CONFIRM")
			Haptics.medium()
			return
		GameState.new_world(_new_world_size))
	box.add_child(create)

	box.add_child(_label(tr("VERSION") % ProjectSettings.get_setting("application/config/version", "?"), 11, Color("5a6380")))


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


## Sober dark theme with rounded buttons (a rounded font arrives in Phase 7).
func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	var normal := _box(Color(0.15, 0.17, 0.26, 0.95), 14, 8)
	var pressed := _box(Color(0.36, 0.55, 0.95, 0.95), 14, 8)
	var hover := _box(Color(0.19, 0.21, 0.31, 0.95), 14, 8)
	var disabled := _box(Color(0.11, 0.12, 0.17, 0.75), 14, 8)
	for type in ["Button", "CheckButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, Color("dfe5ff"))
		theme.set_color("font_pressed_color", type, Color.WHITE)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_disabled_color", type, Color("5d6584"))
	theme.set_stylebox("normal", "LineEdit", _box(Color(0.15, 0.17, 0.26, 0.95), 12, 10))
	theme.set_stylebox("focus", "LineEdit", _box(Color(0.2, 0.23, 0.35, 0.95), 12, 10))
	theme.set_color("font_color", "LineEdit", TEXT)
	return theme
