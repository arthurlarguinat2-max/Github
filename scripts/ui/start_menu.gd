## Start screen: continue the current planet, create a new one with options
## (name, size, oceans, relief, colors, seed), or replay the tutorial.
extends Control

signal closed
signal tutorial_requested

const UiKit := preload("res://scripts/ui/ui_kit.gd")
const Haptics := preload("res://scripts/platform/haptics.gd")

var _main_page: VBoxContainer
var _new_page: VBoxContainer
var _options := {}
var _confirm := false
var _create_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.08, 0.86)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	_main_page = _build_main_page()
	stack.add_child(_main_page)
	_new_page = _build_new_page()
	stack.add_child(_new_page)
	open("main")


func open(page: String) -> void:
	visible = true
	_main_page.visible = page == "main"
	_new_page.visible = page == "new"
	if page == "new":
		_reset_options()
		_refill_new_page()


# --- Main page -------------------------------------------------------------------

func _build_main_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(spacer_top)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/icons/app_icon_1024.png")
	logo.custom_minimum_size = Vector2(150, 150)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	page.add_child(logo)
	page.add_child(UiKit.label(tr("APP_TITLE"), 34))
	var sim = GameState.sim
	page.add_child(UiKit.label(tr("START_CURRENT") % [sim.custom.planet_name, sim.day(), sim.economy.population], 16, UiKit.MUTED))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	page.add_child(spacer)
	var play := UiKit.button(tr("START_CONTINUE"), "play", 60)
	play.add_theme_stylebox_override("normal", UiKit.box(Color(0.3, 0.5, 0.9, 0.95), 16, 8))
	play.add_theme_font_size_override("font_size", 20)
	play.pressed.connect(func():
		Haptics.light()
		visible = false
		closed.emit())
	page.add_child(play)
	var new_planet := UiKit.button(tr("START_NEW"), "build", 54)
	new_planet.pressed.connect(func(): open("new"))
	page.add_child(new_planet)
	var tuto := UiKit.button(tr("START_TUTORIAL"), "help", 54)
	tuto.pressed.connect(func():
		visible = false
		tutorial_requested.emit()
		closed.emit())
	page.add_child(tuto)
	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(spacer_bottom)
	return page


# --- New planet page -------------------------------------------------------------

func _build_new_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(UiKit.label(tr("NEW_PLANET_TITLE"), 24))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	page.add_child(actions)
	var back := UiKit.button(tr("BACK"), "", 54)
	back.pressed.connect(func(): open("main"))
	actions.add_child(back)
	_create_button = UiKit.button(tr("NEW_PLANET"), "play", 54)
	_create_button.add_theme_stylebox_override("normal", UiKit.box(Color(0.3, 0.5, 0.9, 0.95), 14, 8))
	_create_button.pressed.connect(_on_create)
	actions.add_child(_create_button)
	return page


func _reset_options() -> void:
	var options: Dictionary = GameState.config.get("customization", {})
	_confirm = false
	_options = {
		"name": GameState.sim.generate_name(randi(), GameState.sim.name_syllables),
		"frequency": int(options.get("default_size", 12)),
		"water": "balanced",
		"relief": "normal",
		"palette": "classic",
		"seed_text": "",
	}


func _refill_new_page() -> void:
	var content: VBoxContainer = _new_page.find_child("Content", true, false)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var options: Dictionary = GameState.config.get("customization", {})
	_create_button.text = tr("NEW_PLANET")

	content.add_child(_caption(tr("PLANET_NAME")))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	var name_edit := LineEdit.new()
	name_edit.text = _options.name
	name_edit.max_length = 18
	name_edit.custom_minimum_size = Vector2(0, 46)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(text: String): _options["name"] = text)
	name_row.add_child(name_edit)
	var dice := Button.new()
	dice.icon = UiKit.texture("dice")
	dice.add_theme_constant_override("icon_max_width", 30)
	dice.custom_minimum_size = Vector2(46, 46)
	dice.pressed.connect(func():
		_options["name"] = GameState.sim.generate_name(randi(), GameState.sim.name_syllables)
		name_edit.text = _options.name
		Haptics.light())
	name_row.add_child(dice)
	content.add_child(name_row)

	content.add_child(_caption(tr("PLANET_SIZE")))
	var sizes := {}
	var order := 0
	for size in options.get("planet_sizes", []):
		var f := int(size.frequency)
		sizes[str(f)] = {"name_key": size.name_key, "order": order, "subtitle": tr("CELLS_N") % (10 * f * f + 2)}
		order += 1
	content.add_child(UiKit.choice_grid(sizes, str(_options.frequency), func(id: String): _options["frequency"] = int(id), 2))

	content.add_child(_caption(tr("PLANET_WATER")))
	content.add_child(UiKit.choice_grid(options.get("water_levels", {}), _options.water, func(id: String): _options["water"] = id))
	content.add_child(_caption(tr("PLANET_RELIEF")))
	content.add_child(UiKit.choice_grid(options.get("reliefs", {}), _options.relief, func(id: String): _options["relief"] = id))
	content.add_child(_caption(tr("PALETTE")))
	content.add_child(UiKit.choice_grid(options.get("palettes", {}), _options.palette, func(id: String): _options["palette"] = id))

	content.add_child(_caption(tr("PLANET_SEED")))
	var seed_edit := LineEdit.new()
	seed_edit.placeholder_text = tr("PLANET_SEED_HINT")
	seed_edit.custom_minimum_size = Vector2(0, 46)
	seed_edit.text_changed.connect(func(text: String): _options["seed_text"] = text)
	content.add_child(seed_edit)
	content.add_child(_caption(tr("NEW_PLANET_INFO")))


func _on_create() -> void:
	if not _confirm:
		_confirm = true
		_create_button.text = tr("NEW_PLANET_CONFIRM")
		Haptics.medium()
		return
	var options: Dictionary = GameState.config.get("customization", {})
	var water: Dictionary = options.get("water_levels", {}).get(_options.water, {})
	var relief: Dictionary = options.get("reliefs", {}).get(_options.relief, {})
	var world := {
		"frequency": _options.frequency,
		"name": _options.name,
		"palette": _options.palette,
		"seed": GameState.seed_from_text(str(_options.seed_text)),
	}
	if water.has("ocean_fraction"):
		world["ocean_fraction"] = water.ocean_fraction
	for key in ["hills_threshold", "mountain_threshold"]:
		if relief.has(key):
			world[key] = relief[key]
	GameState.start_menu_shown = true
	GameState.new_world(world)


func _caption(text: String) -> Label:
	return UiKit.label(text, 14, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
