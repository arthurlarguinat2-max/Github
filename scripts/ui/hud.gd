## HUD for Phase 0: title, day counter, time-speed buttons, offline message.
## Respects the iPhone safe area (notch / Dynamic Island / home indicator).
extends CanvasLayer

const Haptics := preload("res://scripts/platform/haptics.gd")

const BASE_PADDING := 16.0

var _margin: MarginContainer
var _day_label: Label
var _toast: Label
var _speed_buttons := {}


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

	column.add_child(_label(tr("HINT_DRAG"), 14, Color("7c86a8")))
	_day_label = _label("", 20, Color("f2f4ff"))
	column.add_child(_day_label)
	column.add_child(_build_speed_bar())
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
