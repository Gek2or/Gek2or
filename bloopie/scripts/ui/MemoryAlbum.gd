extends Control
## Polaroid album overlay: a 2x2 page of slightly tilted cards with page
## arrows, a "1 / 3" counter and a Back button. Free forever, including while
## Bloopie sleeps in the cryo-capsule.

const PER_PAGE := 4
const CARD_SIZE := Vector2(450, 590)
const PHOTO_SIDE := 402.0
const TILTS: Array[float] = [-0.035, 0.03, 0.025, -0.03]
const CREAM_TEXT := Color("#FFE9B8")

var _page := 0
var _cards_area: Control
var _empty: Label
var _page_label: Label
var _prev_button: Button
var _next_button: Button


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.13, 0.1, 0.26, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var title := Label.new()
	title.text = "Альбом воспоминаний"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 120
	UIStyle.label(title, 66, CREAM_TEXT)
	add_child(title)

	_cards_area = Control.new()
	_cards_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cards_area.offset_top = 270
	_cards_area.offset_bottom = -260
	_cards_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_area.resized.connect(_layout_cards)
	add_child(_cards_area)

	_empty = Label.new()
	_empty.text = "Здесь появятся тёплые моменты.\nПросто поболтай с Блупи — он сам сделает снимок."
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty.offset_left = 80
	_empty.offset_right = -80
	UIStyle.label(_empty, 40, Color(1, 1, 1, 0.8))
	add_child(_empty)

	var footer := HBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 50
	footer.offset_right = -50
	footer.offset_top = -210
	footer.offset_bottom = -90
	footer.add_theme_constant_override("separation", 24)
	add_child(footer)

	var back := Button.new()
	back.text = "Назад"
	back.icon = load("res://art/icons/back.svg")
	back.flat = true
	back.add_theme_font_size_override("font_size", 52)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		back.add_theme_color_override(state, CREAM_TEXT)
	back.add_theme_constant_override("icon_max_width", 64)
	back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back.pressed.connect(close)
	footer.add_child(back)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	_prev_button = _make_arrow("res://art/icons/prev.svg", -1)
	footer.add_child(_prev_button)
	_page_label = Label.new()
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.size_flags_vertical = Control.SIZE_FILL
	UIStyle.label(_page_label, 52, CREAM_TEXT)
	footer.add_child(_page_label)
	_next_button = _make_arrow("res://art/icons/next.svg", 1)
	footer.add_child(_next_button)


func open() -> void:
	_page = 0
	_show_page()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func close() -> void:
	visible = false


func _make_arrow(icon_path: String, step: int) -> Button:
	var arrow := Button.new()
	arrow.icon = load(icon_path)
	arrow.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.custom_minimum_size = Vector2(110, 110)
	UIStyle.button(arrow, Color("#F2A28C"), 55)
	arrow.pressed.connect(func() -> void:
		_page = clampi(_page + step, 0, _page_count() - 1)
		_show_page())
	return arrow


func _page_count() -> int:
	return maxi(1, int(ceil(GameState.album_cards.size() / float(PER_PAGE))))


func _show_page() -> void:
	for child in _cards_area.get_children():
		child.queue_free()
	var cards := GameState.album_cards
	_empty.visible = cards.is_empty()
	var pages := _page_count()
	_page = clampi(_page, 0, pages - 1)
	_page_label.text = "%d / %d" % [_page + 1, pages]
	_prev_button.disabled = _page == 0
	_next_button.disabled = _page >= pages - 1
	# Newest memories first.
	for slot in PER_PAGE:
		var index := cards.size() - 1 - (_page * PER_PAGE + slot)
		if index < 0:
			break
		var polaroid := _make_polaroid(cards[index])
		polaroid.set_meta("slot", slot)
		_cards_area.add_child(polaroid)
	_layout_cards()


func _layout_cards() -> void:
	var area := _cards_area.size
	var gap := Vector2(40, 46)
	var grid := CARD_SIZE * 2.0 + gap
	var origin := (area - grid) * 0.5
	for child in _cards_area.get_children():
		if child.is_queued_for_deletion() or not child.has_meta("slot"):
			continue
		var slot: int = child.get_meta("slot")
		var card := child as Control
		card.size = CARD_SIZE
		card.position = origin + Vector2(slot % 2, slot / 2) * (CARD_SIZE + gap)
		card.pivot_offset = CARD_SIZE * 0.5
		card.rotation = TILTS[slot]


func _make_polaroid(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	var paper := UIStyle.card(Color("#FFFDF9"), 8)
	paper.set_content_margin_all(24)
	paper.shadow_size = 22
	card.add_theme_stylebox_override("panel", paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)

	column.add_child(_make_photo(entry))

	var caption := Label.new()
	caption.text = entry.caption
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.max_lines_visible = 2
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.custom_minimum_size = Vector2(PHOTO_SIDE, 0)
	caption.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIStyle.label(caption, 30, UIStyle.INK)
	column.add_child(caption)

	var date := Label.new()
	date.text = entry.date_string
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIStyle.label(date, 26, Color(UIStyle.INK, 0.6))
	column.add_child(date)
	return card


func _make_photo(entry: Dictionary) -> Control:
	var texture := MemoryManager.load_photo(entry)
	if texture == null:
		# The caption was saved without a snapshot (the frame could not be read).
		var blank := ColorRect.new()
		blank.color = Color("#35295F")
		blank.custom_minimum_size = Vector2(PHOTO_SIDE, PHOTO_SIDE)
		return blank
	var photo := TextureRect.new()
	photo.texture = texture
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.custom_minimum_size = Vector2(PHOTO_SIDE, PHOTO_SIDE)
	return photo
