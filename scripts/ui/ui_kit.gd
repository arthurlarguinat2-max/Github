## Small shared helpers to build the interface in code (labels, panels,
## icons, choice grids). Keeps every screen consistent.
extends RefCounted

const ICON_DIR := "res://assets/icons/ui/"
const TEXT := Color("f2f4ff")
const MUTED := Color("aab4d4")
const PANEL_BG := Color(0.09, 0.11, 0.18, 0.96)


static func box(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


static func label(text: String, size: int, color: Color = TEXT, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func texture(icon_id: String) -> Texture2D:
	var path := ICON_DIR + icon_id + ".svg"
	return load(path) if ResourceLoader.exists(path) else null


static func icon(icon_id: String, size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture(icon_id)
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func button(text: String, icon_id: String = "", min_height: int = 50) -> Button:
	var b := Button.new()
	b.text = text
	if icon_id != "":
		b.icon = texture(icon_id)
		b.add_theme_constant_override("icon_max_width", 30)
	b.custom_minimum_size = Vector2(0, min_height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


## One-choice toggle buttons on a grid. `choices`: id -> {name_key, order, subtitle?}.
static func choice_grid(choices: Dictionary, current: String, on_pick: Callable, columns: int = 3) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = mini(columns, maxi(choices.size(), 1))
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var ids: Array = choices.keys()
	ids.sort_custom(func(a, b): return int(choices[a].get("order", 0)) < int(choices[b].get("order", 0)))
	var group := ButtonGroup.new()
	for id in ids:
		var choice: Dictionary = choices[id]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = TranslationServer.translate(str(choice.get("name_key", id)))
		if choice.has("subtitle"):
			b.text += "\n" + str(choice.subtitle)
		b.button_pressed = str(id) == current
		b.pressed.connect(func(): on_pick.call(str(id)))
		grid.add_child(b)
	return grid


## Round color swatches; `on_pick` receives the hex string.
static func swatches(colors: Array, current: String, on_pick: Callable) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var group := ButtonGroup.new()
	for hex in colors:
		var swatch := Button.new()
		swatch.toggle_mode = true
		swatch.button_group = group
		swatch.custom_minimum_size = Vector2(44, 44)
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var color := Color(str(hex))
		swatch.add_theme_stylebox_override("normal", box(color, 22, 0))
		swatch.add_theme_stylebox_override("hover", box(color.lightened(0.1), 22, 0))
		var chosen := box(color, 22, 0)
		chosen.set_border_width_all(4)
		chosen.border_color = Color.WHITE
		swatch.add_theme_stylebox_override("pressed", chosen)
		swatch.add_theme_stylebox_override("hover_pressed", chosen)
		swatch.button_pressed = str(hex) == current
		swatch.pressed.connect(func(): on_pick.call(str(hex)))
		grid.add_child(swatch)
	return grid


## Converts a list of {id, name_key, ...} into a choice dictionary.
static func choices_from_list(items: Array, subtitle_fn: Callable = Callable()) -> Dictionary:
	var out := {}
	var order := 0
	for item in items:
		var entry := {"name_key": item.get("name_key", item.get("id", "")), "order": order}
		if subtitle_fn.is_valid():
			entry["subtitle"] = subtitle_fn.call(item)
		out[str(item.get("id", order))] = entry
		order += 1
	return out
