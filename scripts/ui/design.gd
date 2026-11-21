## "Diorama doux" design system: one place for colors, fonts and styles.
## Warm cream panels, brown ink, coral accent, soft shadows, rounded type.
## Change the look of the whole game from here.
extends RefCounted

# --- Palette ---------------------------------------------------------------------
const CREAM := Color("fff6e9")        # Sheets and cards
const CREAM_DEEP := Color("f6e8d4")   # Secondary surfaces
const CARD := Color("fffdf8")         # Chips, buttons
const INK := Color("4a3b2f")          # Main text
const INK_SOFT := Color("8a7564")     # Secondary text
const INK_FAINT := Color("b8a898")    # Disabled text
const CORAL := Color("f2786a")        # Primary action
const CORAL_DARK := Color("d95f52")
const CORAL_SOFT := Color("ffd9cf")   # Selected toggle
const TEAL := Color("5bb5a2")         # Positive / progress
const TEAL_SOFT := Color("dff3ec")
const SKY_SOFT := Color("e6f2fb")     # Tutorial card
const PARCHMENT := Color("fff0dc")    # Events
const SUN := Color("ffc857")
const GOOD := Color("3f9e6e")
const BAD := Color("d9534f")
const WARN := Color("d9822b")
const SHADOW := Color(0.35, 0.22, 0.1, 0.16)
const WHITE := Color.WHITE

# Same colors as hex, for BBCode in rich text.
const HEX_GOOD := "#3f9e6e"
const HEX_BAD := "#d9534f"
const HEX_SOFT := "#8a7564"

static var _title_font: Font
static var _body_font: Font


## Rounded system font for titles and buttons (no font file to license).
static func title_font() -> Font:
	if _title_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Arial Rounded MT Bold", "Avenir Next", "Helvetica Neue"])
		f.font_weight = 700
		_title_font = f
	return _title_font


static func body_font() -> Font:
	if _body_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue"])
		f.font_weight = 500
		_body_font = f
	return _body_font


## Rounded panel with an optional soft drop shadow.
static func panel(color: Color, radius: int = 20, margin: int = 12, shadow: bool = true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.anti_aliasing = true
	if shadow:
		style.shadow_color = SHADOW
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 3)
	return style


## Panel with a colored outline (selected states, focus).
static func outlined(color: Color, border: Color, radius: int = 16, margin: int = 8) -> StyleBoxFlat:
	var style := panel(color, radius, margin, false)
	style.set_border_width_all(3)
	style.border_color = border
	return style


## Styles a button as the main action (coral, white text).
static func make_primary(button: Button, radius: int = 18) -> void:
	button.add_theme_stylebox_override("normal", panel(CORAL, radius, 8))
	button.add_theme_stylebox_override("hover", panel(CORAL.lightened(0.06), radius, 8))
	button.add_theme_stylebox_override("pressed", panel(CORAL_DARK, radius, 8))
	button.add_theme_stylebox_override("hover_pressed", panel(CORAL_DARK, radius, 8))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, WHITE)
	button.add_theme_font_override("font", title_font())


## The whole UI theme: buttons, toggles, text fields, progress bars, labels.
static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = body_font()
	theme.default_font_size = 16
	var normal := panel(CARD, 16, 8)
	var hover := panel(Color("fff3e0"), 16, 8)
	var pressed := outlined(CORAL_SOFT, CORAL, 16, 8)
	var disabled := panel(Color("efe6da"), 16, 8, false)
	for type in ["Button", "CheckButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, INK)
		theme.set_color("font_hover_color", type, INK)
		theme.set_color("font_pressed_color", type, INK)
		theme.set_color("font_hover_pressed_color", type, INK)
		theme.set_color("font_focus_color", type, INK)
		theme.set_color("font_disabled_color", type, INK_FAINT)
		theme.set_color("icon_normal_color", type, WHITE)
		theme.set_color("icon_disabled_color", type, Color(1, 1, 1, 0.45))
		theme.set_font("font", type, title_font())
	theme.set_stylebox("normal", "LineEdit", panel(WHITE, 14, 10, false))
	theme.set_stylebox("focus", "LineEdit", outlined(WHITE, CORAL, 14, 10))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", INK_FAINT)
	theme.set_color("caret_color", "LineEdit", CORAL)
	theme.set_color("font_color", "Label", INK)
	theme.set_color("default_color", "RichTextLabel", INK)
	var track := panel(Color("efe2cf"), 6, 0, false)
	var fill := panel(TEAL, 6, 0, false)
	theme.set_stylebox("background", "ProgressBar", track)
	theme.set_stylebox("fill", "ProgressBar", fill)
	return theme
