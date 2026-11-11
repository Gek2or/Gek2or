class_name UIStyle
extends RefCounted
## Shared look of the HUD, following the approved mock-ups: milky cream pills
## and tiles, a translucent white frame around the dock, soft shadows.

const INK := Color("#232946")
const TEXT := Color("#5A4250")
const CREAM := Color("#FFF8EE")
const TILE := Color("#FFF0E0")
const SKY := Color("#BFE0FB")
const ROSE := Color("#FBC4D6")
const LILAC := Color("#D6C4FB")
const BUTTER := Color("#FFE3A6")
const MINT := Color("#C4F0DE")
const ICE := Color("#49C7EE")
const DIM := Color(0.09, 0.08, 0.2, 0.74)


static func card(fill: Color, radius: int = 40, border: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.set_border_width_all(border)
	box.border_color = INK
	box.shadow_color = Color(0.05, 0.04, 0.14, 0.3)
	box.shadow_size = 16
	box.shadow_offset = Vector2(0, 8)
	box.set_content_margin_all(22)
	box.anti_aliasing_size = 1.5
	return box


## Small milky capsule: level, coins, vocal level, accuracy.
static func pill() -> StyleBoxFlat:
	var box := card(Color(1.0, 0.97, 0.93, 0.94), 48)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 5)
	box.content_margin_left = 26.0
	box.content_margin_right = 30.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box


## Translucent white frame that holds the dock tiles and the care drawer.
static func frame(radius: int = 64) -> StyleBoxFlat:
	var box := card(Color(1.0, 0.98, 0.96, 0.46), radius)
	box.set_border_width_all(4)
	box.border_color = Color(1, 1, 1, 0.75)
	return box


## Dark frosted panel for toasts.
static func glass(radius: int = 56) -> StyleBoxFlat:
	var box := card(Color(0.12, 0.12, 0.28, 0.82), radius)
	box.set_border_width_all(3)
	box.border_color = Color(1, 1, 1, 0.14)
	return box


## Gives a Button the soft card look with pressed/disabled feedback.
static func button(target: Button, fill: Color, radius: int = 40, font_size: int = 36) -> void:
	target.add_theme_font_size_override("font_size", font_size)
	target.add_theme_stylebox_override("normal", card(fill, radius))
	target.add_theme_stylebox_override("hover", card(fill.lightened(0.12), radius))
	target.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var pressed := card(fill.darkened(0.08), radius)
	pressed.shadow_size = 4
	pressed.shadow_offset = Vector2(0, 2)
	pressed.content_margin_top += 4.0
	target.add_theme_stylebox_override("pressed", pressed)
	var disabled := card(fill.lerp(Color("#9AA0B5"), 0.6), radius)
	target.add_theme_stylebox_override("disabled", disabled)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		target.add_theme_color_override(state, TEXT)
	target.add_theme_color_override("font_disabled_color", Color(TEXT, 0.55))
	target.add_theme_constant_override("h_separation", 14)
	target.add_theme_constant_override("icon_max_width", 64)


## Cream tile with the icon above the caption (dock and care drawer).
static func tile(target: Button, font_size: int = 32, icon_width: int = 84) -> void:
	button(target, TILE, 44, font_size)
	var outlined := target.get_theme_stylebox("normal") as StyleBoxFlat
	outlined.set_border_width_all(4)
	outlined.border_color = Color(1, 1, 1, 0.9)
	target.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	target.expand_icon = true
	target.add_theme_constant_override("icon_max_width", icon_width)


## The icy "Wake Up Bloopie" call to action.
static func ice_button(target: Button) -> void:
	button(target, ICE, 56, 50)
	for state: String in ["normal", "hover", "pressed"]:
		var box := target.get_theme_stylebox(state) as StyleBoxFlat
		box.set_border_width_all(6)
		box.border_color = Color(0.86, 0.97, 1.0)
		box.shadow_color = Color(0.2, 0.75, 1.0, 0.55)
		box.shadow_size = 28
		box.shadow_offset = Vector2.ZERO
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		target.add_theme_color_override(state, Color.WHITE)
	target.add_theme_color_override("font_outline_color", Color("#1C6FA8"))
	target.add_theme_constant_override("outline_size", 14)


static func label(target: Label, size: int, color: Color = TEXT) -> void:
	target.add_theme_font_size_override("font_size", size)
	target.add_theme_color_override("font_color", color)


static func line_edit(target: LineEdit) -> void:
	target.add_theme_font_size_override("font_size", 38)
	var normal := card(Color(1.0, 0.98, 0.95, 0.96), 52)
	normal.set_border_width_all(4)
	normal.border_color = Color(1, 1, 1, 0.9)
	normal.content_margin_left = 40.0
	target.add_theme_stylebox_override("normal", normal)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color.WHITE
	target.add_theme_stylebox_override("focus", focus)
	target.add_theme_color_override("font_color", TEXT)
	target.add_theme_color_override("font_placeholder_color", Color(TEXT, 0.45))
	target.add_theme_color_override("caret_color", TEXT)


static func progress_bar(target: ProgressBar, fill: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(1, 1, 1, 0.5)
	background.set_corner_radius_all(26)
	background.set_border_width_all(4)
	background.border_color = Color(1, 1, 1, 0.9)
	var bar := StyleBoxFlat.new()
	bar.bg_color = fill
	bar.set_corner_radius_all(26)
	bar.set_border_width_all(4)
	bar.border_color = Color(1, 1, 1, 0.0)
	target.add_theme_stylebox_override("background", background)
	target.add_theme_stylebox_override("fill", bar)
