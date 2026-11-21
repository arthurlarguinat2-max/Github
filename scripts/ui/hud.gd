## HUD: resource bar, day counter, time-speed buttons, alerts, and the cell
## card (terrain info + build / demolish). Respects the iPhone safe area.
extends CanvasLayer

signal close_requested

const Haptics := preload("res://scripts/platform/haptics.gd")
const Economy := preload("res://scripts/simulation/economy.gd")

const BASE_PADDING := 16.0
const REFRESH_INTERVAL := 0.25
const TEXT := Color("f2f4ff")
const MUTED := Color("aab4d4")
const WARN := Color("ffb36b")

var _margin: MarginContainer
var _resources_label: RichTextLabel
var _population_label: Label
var _day_label: Label
var _toast: Label
var _toast_tween: Tween
var _hint: Label
var _speed_buttons := {}
var _speed_bar: HBoxContainer

var _cell_panel: PanelContainer
var _cell_title: Label
var _cell_details: Label
var _building_info: Label
var _demolish_button: Button
var _build_title: Label
var _build_grid: GridContainer
var _build_note: Label
var _build_buttons := {}  # building id -> Button
var _cell := -1
var _confirm_demolish := false
var _refresh_timer := 0.0

## Controls that capture touches (the planet ignores touches starting on them).
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
	column.add_theme_constant_override("separation", 4)
	_margin.add_child(column)

	column.add_child(_label(tr("APP_TITLE"), 22, TEXT))
	_resources_label = RichTextLabel.new()
	_resources_label.bbcode_enabled = true
	_resources_label.fit_content = true
	_resources_label.scroll_active = false
	_resources_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resources_label.add_theme_font_size_override("normal_font_size", 16)
	column.add_child(_resources_label)
	_population_label = _label("", 14, MUTED)
	column.add_child(_population_label)

	_toast = _label("", 15, WARN)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_toast)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	_cell_panel = _build_cell_panel()
	column.add_child(_cell_panel)
	_hint = _label(tr("HINT_DRAG"), 14, Color("7c86a8"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	_day_label = _label("", 18, TEXT)
	column.add_child(_day_label)
	_speed_bar = _build_speed_bar()
	column.add_child(_speed_bar)
	column.add_child(_label(tr("VERSION") % ProjectSettings.get_setting("application/config/version", "?"), 11, Color("5a6380")))
	_blocking.append(_speed_bar)
	_blocking.append(_cell_panel)

	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	GameState.ticked.connect(_refresh_day)
	GameState.sim.economy.alert.connect(_on_alert)
	_refresh_day()
	_refresh_resources()
	_show_offline_message()


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL:
		_refresh_timer = 0.0
		_refresh_resources()
		if _cell >= 0:
			_update_card()


## True when `point` (viewport coordinates) is over an interactive UI element.
func blocks_point(point: Vector2) -> bool:
	for control in _blocking:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return true
	return false


# --- Top bar -----------------------------------------------------------------

func _refresh_resources() -> void:
	var eco = GameState.sim.economy
	var parts := PackedStringArray()
	for res in ["food", "wood", "stone"]:
		var rate := float(eco.rates.get(res, 0.0))
		var color := "#f2f4ff"
		if res == "food" and rate < 0.0:
			color = "#ffb36b" if eco.stock("food") > 0.0 else "#ff6b6b"
		var rate_text := ""
		if absf(rate) >= 0.05:
			rate_text = " [color=#8f9abf](%s%s)[/color]" % [_format_signed(rate), tr("PER_DAY")]
		parts.append("[color=%s]%s %d[/color]%s" % [color, tr(_res_key(res)), floori(eco.stock(res)), rate_text])
	_resources_label.text = "[center]%s[/center]" % "   ".join(parts)
	_population_label.text = tr("POP_LINE") % [eco.population, eco.housing(), eco.employed(), eco.jobs()]


func _refresh_day() -> void:
	_day_label.text = tr("DAY_N") % GameState.sim.day()
	for speed in _speed_buttons:
		_speed_buttons[speed].set_pressed_no_signal(speed == GameState.sim.speed)


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


func _show_offline_message() -> void:
	if GameState.pending_offline_days <= 0:
		return
	_show_toast(tr("OFFLINE_WELCOME") % GameState.pending_offline_days)
	GameState.pending_offline_days = 0


# --- Speed bar ---------------------------------------------------------------

func _build_speed_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	for speed in GameState.sim.allowed_speeds:
		var button := Button.new()
		button.text = tr("SPEED_PAUSE") if speed == 0 else tr("SPEED_X") % speed
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 46)  # Comfortable thumb target.
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_speed_pressed.bind(speed))
		bar.add_child(button)
		_speed_buttons[speed] = button
	return bar


func _on_speed_pressed(speed: int) -> void:
	GameState.sim.set_speed(speed)
	Haptics.light()
	_refresh_day()


# --- Cell card ---------------------------------------------------------------

## Opens the card of a planet cell (terrain, building, build menu).
func show_cell(cell: int) -> void:
	_cell = cell
	_confirm_demolish = false
	_rebuild_build_buttons()
	_update_card()
	_cell_panel.visible = true
	_hint.visible = false
	Haptics.light()


func hide_cell() -> void:
	_cell = -1
	_cell_panel.visible = false
	_hint.visible = true


func _update_card() -> void:
	var sim = GameState.sim
	var planet = sim.planet
	var eco = sim.economy
	var terrain_id: String = planet.terrain[_cell]
	var def: Dictionary = sim.terrain_defs.get(terrain_id, {})
	var building_id: String = planet.buildings[_cell]

	if building_id != "":
		_cell_title.text = "%s · %s" % [tr(str(eco.defs.get(building_id, {}).get("name_key", building_id))), tr(str(def.get("name_key", terrain_id)))]
	else:
		_cell_title.text = tr(str(def.get("name_key", terrain_id)))

	# Terrain lines.
	var lines := PackedStringArray()
	if def.get("water", false):
		lines.append(tr("CELL_WATER"))
	else:
		lines.append(tr("CELL_FERTILITY") % roundi(planet.fertility[_cell] * 100.0))
	var found := PackedStringArray()
	var res_defs: Dictionary = GameState.config.get("resources", {})
	var cell_res: Dictionary = planet.resources[_cell]
	for res_id in cell_res:
		var res_def: Dictionary = res_defs.get(res_id, {})
		if res_def.get("hidden", false):
			continue  # Revealed by a later age.
		found.append("%s (%d)" % [tr(str(res_def.get("name_key", res_id))), floori(float(cell_res[res_id]))])
	lines.append(tr("CELL_NO_RESOURCE") if found.is_empty() else tr("CELL_RESOURCES") % " · ".join(found))
	_cell_details.text = "\n".join(lines)

	# Existing building.
	if building_id != "":
		_building_info.text = _building_text(_cell, building_id)
		_building_info.visible = true
		_demolish_button.visible = _cell != eco.village_center
		_demolish_button.text = tr("DEMOLISH_CONFIRM") if _confirm_demolish else tr("DEMOLISH")
	else:
		_building_info.visible = false
		_demolish_button.visible = false

	# Build menu.
	var any_button := false
	for id in _build_buttons:
		var button: Button = _build_buttons[id]
		var reason: String = eco.can_build(_cell, id)
		button.disabled = reason != ""
		any_button = true
	var note := ""
	if building_id == "" and not def.get("water", false):
		if not eco.in_territory(_cell):
			note = tr("BUILD_ERR_TERRITORY")
		elif not any_button:
			note = tr("BUILD_NOTHING")
	_build_title.visible = any_button
	_build_grid.visible = any_button
	_build_note.text = note
	_build_note.visible = note != ""


func _building_text(cell: int, building_id: String) -> String:
	var eco = GameState.sim.economy
	var bdef: Dictionary = eco.defs.get(building_id, {})
	var lines := PackedStringArray()
	lines.append(tr(str(bdef.get("desc_key", ""))))
	if cell == eco.village_center:
		lines.append(tr("BLD_VILLAGE_CENTER"))
	var housing := int(bdef.get("housing", 0))
	if housing > 0:
		lines.append(tr("BLD_HOUSING") % housing)
	var need := int(bdef.get("workers", 0))
	if need > 0:
		lines.append(tr("BLD_WORKERS") % [eco.workers_at(cell), need])
	if bdef.has("produces"):
		var rate: Dictionary = eco.building_rate(cell)
		var out := PackedStringArray()
		for res in bdef.produces:
			out.append("%s %s" % [_format_signed(float(rate.get(res, 0.0))), tr(_res_key(res))])
		if need > 0 and eco.workers_at(cell) == 0:
			lines.append(tr("BLD_IDLE"))
		elif bdef.has("extracts") and not eco.has_deposit(cell, str(bdef.extracts)):
			lines.append(tr("BLD_DEPLETED"))
		else:
			lines.append(tr("BLD_PRODUCTION") % " · ".join(out))
	return "\n".join(lines)


## One button per building that could ever go on this cell (terrain/deposit OK).
func _rebuild_build_buttons() -> void:
	for child in _build_grid.get_children():
		_build_grid.remove_child(child)
		child.queue_free()
	_build_buttons.clear()
	var eco = GameState.sim.economy
	if GameState.sim.planet.buildings[_cell] != "":
		return
	var ids: Array = eco.defs.keys()
	ids.sort_custom(func(a, b): return int(eco.defs[a].get("order", 99)) < int(eco.defs[b].get("order", 99)))
	for id in ids:
		var reason: String = eco.can_build(_cell, id)
		if reason in [Economy.ERR_TERRAIN, Economy.ERR_DEPOSIT, Economy.ERR_UNKNOWN, Economy.ERR_OCCUPIED, Economy.ERR_TERRITORY]:
			continue
		var bdef: Dictionary = eco.defs[id]
		var button := Button.new()
		button.text = "%s\n%s" % [tr(str(bdef.get("name_key", id))), _cost_text(bdef.get("cost", {}))]
		button.custom_minimum_size = Vector2(0, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_build_pressed.bind(id))
		_build_grid.add_child(button)
		_build_buttons[id] = button


func _on_build_pressed(id: String) -> void:
	var eco = GameState.sim.economy
	if eco.build(_cell, id):
		Haptics.medium()
		show_cell(_cell)


func _on_demolish_pressed() -> void:
	if not _confirm_demolish:
		_confirm_demolish = true
		_update_card()
		return
	if GameState.sim.economy.demolish(_cell):
		Haptics.medium()
	show_cell(_cell)


func _build_cell_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.19, 0.94)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	_cell_title = _label("", 20, TEXT)
	_cell_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cell_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cell_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_cell_title)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(44, 44)
	close.pressed.connect(func(): close_requested.emit())
	header.add_child(close)

	_cell_details = _left_label(14, Color("c4cbe6"))
	box.add_child(_cell_details)
	_building_info = _left_label(14, TEXT)
	box.add_child(_building_info)
	_demolish_button = Button.new()
	_demolish_button.custom_minimum_size = Vector2(0, 44)
	_demolish_button.pressed.connect(_on_demolish_pressed)
	box.add_child(_demolish_button)

	_build_title = _left_label(14, MUTED)
	_build_title.text = tr("BUILD_TITLE")
	box.add_child(_build_title)
	_build_grid = GridContainer.new()
	_build_grid.columns = 2
	_build_grid.add_theme_constant_override("h_separation", 8)
	_build_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_build_grid)
	_build_note = _left_label(14, WARN)
	box.add_child(_build_note)
	return panel


# --- Helpers -----------------------------------------------------------------

func _res_key(res: String) -> String:
	var res_def: Dictionary = GameState.config.get("resources", {}).get(res, {})
	return str(res_def.get("name_key", "RES_" + res.to_upper()))


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for res in cost:
		parts.append("%d %s" % [int(cost[res]), tr(_res_key(res)).to_lower()])
	return " · ".join(parts) if not parts.is_empty() else tr("FREE")


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


func _left_label(size: int, color: Color) -> Label:
	var label := _label("", size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Sober dark theme with rounded buttons (a rounded font arrives in Phase 7).
func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.15, 0.22, 0.9)
	normal.set_corner_radius_all(14)
	normal.set_content_margin_all(8)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.36, 0.55, 0.95, 0.95)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.18, 0.2, 0.3, 0.92)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.11, 0.12, 0.17, 0.7)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("hover_pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", Color("dfe5ff"))
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color("5d6584"))
	return theme
