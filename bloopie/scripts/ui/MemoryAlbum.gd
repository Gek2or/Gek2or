extends Control
## Polaroid album overlay. Free forever, including after the trial ends.

const CARD_WIDTH := 440.0

var _grid: GridContainer
var _empty: Label


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = UIStyle.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 50
	column.offset_right = -50
	column.offset_top = 90
	column.offset_bottom = -70
	column.add_theme_constant_override("separation", 30)
	add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Альбом воспоминаний"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.label(title, 54, Color.WHITE)
	header.add_child(title)
	var close_button := Button.new()
	close_button.icon = load("res://art/icons/close.svg")
	close_button.custom_minimum_size = Vector2(110, 110)
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.button(close_button, UIStyle.ROSE, 55)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_empty = Label.new()
	_empty.text = "Здесь появятся тёплые моменты.\nПросто поболтай с Блупи — он сам сделает снимок."
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.label(_empty, 38, Color(1, 1, 1, 0.8))
	column.add_child(_empty)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 40)
	_grid.add_theme_constant_override("v_separation", 40)
	scroll.add_child(_grid)


func open() -> void:
	_rebuild()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func close() -> void:
	visible = false


func _rebuild() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_empty.visible = MemoryManager.entries.is_empty()
	for i in range(MemoryManager.entries.size() - 1, -1, -1):
		_grid.add_child(_make_polaroid(MemoryManager.entries[i]))


func _make_polaroid(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	var paper := UIStyle.card(Color("#FFFDF9"), 10, 0)
	paper.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", paper)
	card.custom_minimum_size.x = CARD_WIDTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)

	var photo := load_photo_node(entry)
	column.add_child(photo)

	var caption := Label.new()
	caption.text = entry.caption
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.x = CARD_WIDTH - 48.0
	UIStyle.label(caption, 30)
	column.add_child(caption)

	var date := Label.new()
	date.text = MemoryManager.format_date(entry.unix)
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIStyle.label(date, 26, Color(UIStyle.INK, 0.6))
	column.add_child(date)
	return card


func load_photo_node(entry: Dictionary) -> Control:
	var side := CARD_WIDTH - 48.0
	var texture := MemoryManager.load_photo(entry)
	if texture == null:
		# The caption was saved without a snapshot (e.g. the frame could not be read).
		var blank := ColorRect.new()
		blank.color = Color("#35295F")
		blank.custom_minimum_size = Vector2(side, side)
		return blank
	var photo := TextureRect.new()
	photo.texture = texture
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.custom_minimum_size = Vector2(side, side)
	return photo
