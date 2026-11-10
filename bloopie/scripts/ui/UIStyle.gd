class_name UIStyle
extends RefCounted
## Shared pastel look for the HUD: rounded cards, ink outlines, soft shadows.

const INK := Color("#232946")
const CREAM := Color("#FFF8EE")
const SKY := Color("#BFE0FB")
const ROSE := Color("#FBC4D6")
const LILAC := Color("#D6C4FB")
const BUTTER := Color("#FFE3A6")
const MINT := Color("#C4F0DE")
const DIM := Color(0.09, 0.1, 0.2, 0.72)


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


## Frosted dark-indigo panel used behind the top bar, the dock and toasts.
static func glass(radius: int = 56) -> StyleBoxFlat:
	var box := card(Color(0.12, 0.12, 0.28, 0.8), radius)
	box.set_border_width_all(3)
	box.border_color = Color(1, 1, 1, 0.14)
	return box


## Gives a Button the pastel card look with pressed/disabled feedback.
static func button(target: Button, fill: Color, radius: int = 40, font_size: int = 36) -> void:
	target.add_theme_font_size_override("font_size", font_size)
	target.add_theme_stylebox_override("normal", card(fill, radius))
	target.add_theme_stylebox_override("hover", card(fill.lightened(0.12), radius))
	target.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var pressed := card(fill.darkened(0.1), radius)
	pressed.shadow_size = 4
	pressed.shadow_offset = Vector2(0, 2)
	pressed.content_margin_top += 4.0
	target.add_theme_stylebox_override("pressed", pressed)
	var disabled := card(fill.lerp(Color("#9AA0B5"), 0.6), radius)
	target.add_theme_stylebox_override("disabled", disabled)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		target.add_theme_color_override(state, INK)
	target.add_theme_color_override("font_disabled_color", Color(INK, 0.55))
	target.add_theme_constant_override("h_separation", 14)
	target.add_theme_constant_override("icon_max_width", 64)


static func label(target: Label, size: int, color: Color = INK) -> void:
	target.add_theme_font_size_override("font_size", size)
	target.add_theme_color_override("font_color", color)


static func line_edit(target: LineEdit) -> void:
	target.add_theme_font_size_override("font_size", 38)
	target.add_theme_stylebox_override("normal", card(CREAM, 48))
	target.add_theme_stylebox_override("focus", card(Color.WHITE, 48))
	target.add_theme_color_override("font_color", INK)
	target.add_theme_color_override("font_placeholder_color", Color(INK, 0.45))
	target.add_theme_color_override("caret_color", INK)


static func progress_bar(target: ProgressBar, fill: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(1, 1, 1, 0.22)
	background.set_corner_radius_all(26)
	var bar := StyleBoxFlat.new()
	bar.bg_color = fill
	bar.set_corner_radius_all(26)
	target.add_theme_stylebox_override("background", background)
	target.add_theme_stylebox_override("fill", bar)
