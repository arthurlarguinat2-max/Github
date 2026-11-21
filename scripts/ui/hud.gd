## HUD for Phase 0: title, day counter, time-speed buttons, offline message.
## Respects the iPhone safe area (notch / Dynamic Island / home indicator).
extends CanvasLayer

const Haptics := preload("res://scripts/platform/haptics.gd")

signal close_requested

const BASE_PADDING := 16.0

var _margin: MarginContainer
var _day_label: Label
var _toast: Label
var _speed_buttons := {}
var _speed_bar: HBoxContainer
var _hint: Label
var _cell_panel: PanelContainer
var _cell_title: Label
var _cell_details: Label
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
	_margin.add_child(column)

	var title := _label(tr("APP_TITLE"), 30, Color("f2f4ff"))
	column.add_child(title)
	column.add_child(_label(tr("HELLO_PLANET"), 18, Color("aab4d4")))

	_toast = _label("", 15, Color("ffd98a"))
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
	_day_label = _label("", 20, Color("f2f4ff"))
	column.add_child(_day_label)
	_speed_bar = _build_speed_bar()
	column.add_child(_speed_bar)
	_blocking.append(_speed_bar)
	_blocking.append(_cell_panel)
	column.add_child(_label(tr("VERSION") % ProjectSettings.get_setting("application/config/version", "?"), 11, Color("5a6380")))

	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	GameState.ticked.connect(_refresh)
	_refresh()
	_show_offline_message()


func _build_speed_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	for speed in GameState.sim.allowed_speeds:
		var button := Button.new()
		button.text = tr("SPEED_PAUSE") if speed == 0 else tr("SPEED_X") % speed
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 48)  # Comfortable thumb target.
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_speed_pressed.bind(speed))
		bar.add_child(button)
		_speed_buttons[speed] = button
	return bar


## True when `point` (viewport coordinates) is over an interactive UI element.
func blocks_point(point: Vector2) -> bool:
	for control in _blocking:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return true
	return false


## Shows the information card of a planet cell.
func show_cell(cell: int) -> void:
	var sim = GameState.sim
	var planet = sim.planet
	var terrain_id: String = planet.terrain[cell]
	var def: Dictionary = sim.terrain_defs.get(terrain_id, {})
	_cell_title.text = tr(str(def.get("name_key", terrain_id)))
	var lines := PackedStringArray()
	if def.get("water", false):
		lines.append(tr("CELL_WATER"))
	else:
		lines.append(tr("CELL_FERTILITY") % roundi(planet.fertility[cell] * 100.0))
		lines.append(tr("CELL_BUILDABLE") if def.get("buildable", false) else tr("CELL_NOT_BUILDABLE"))
	var found := PackedStringArray()
	var res_defs: Dictionary = GameState.config.get("resources", {})
	var cell_res: Dictionary = planet.resources[cell]
	for res_id in cell_res:
		var res_def: Dictionary = res_defs.get(res_id, {})
		if res_def.get("hidden", false):
			continue  # Revealed by a later age.
		found.append("%s (%d)" % [tr(str(res_def.get("name_key", res_id))), int(cell_res[res_id])])
	if found.is_empty():
		lines.append(tr("CELL_NO_RESOURCE"))
	else:
		lines.append(tr("CELL_RESOURCES") % " · ".join(found))
	if planet.grid.is_pentagon(cell):
		lines.append(tr("CELL_PENTAGON"))
	_cell_details.text = "\n".join(lines)
	_cell_panel.visible = true
	_hint.visible = false
	Haptics.light()


func hide_cell() -> void:
	_cell_panel.visible = false
	_hint.visible = true


func _build_cell_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.19, 0.92)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	_cell_title = _label("", 21, Color("f2f4ff"))
	_cell_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cell_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_cell_title)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(44, 44)
	close.pressed.connect(func(): close_requested.emit())
	header.add_child(close)

	_cell_details = _label("", 15, Color("c4cbe6"))
	_cell_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cell_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_cell_details)
	return panel


func _on_speed_pressed(speed: int) -> void:
	GameState.sim.set_speed(speed)
	Haptics.light()
	_refresh()


func _refresh() -> void:
	_day_label.text = tr("DAY_N") % GameState.sim.day()
	for speed in _speed_buttons:
		_speed_buttons[speed].set_pressed_no_signal(speed == GameState.sim.speed)


func _show_offline_message() -> void:
	if GameState.pending_offline_days <= 0:
		return
	_toast.text = tr("OFFLINE_WELCOME") % GameState.pending_offline_days
	GameState.pending_offline_days = 0
	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(_toast, "modulate:a", 0.0, 1.0)


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
	theme.default_font_size = 17
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.15, 0.22, 0.85)
	normal.set_corner_radius_all(14)
	normal.set_content_margin_all(8)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.36, 0.55, 0.95, 0.95)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.18, 0.2, 0.3, 0.9)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("hover_pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", Color("dfe5ff"))
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	return theme
