extends Control
## First launch: the player introduces themselves and picks Bloopie's
## personality. The choice sets the AI persona on the backend and the room
## interior; it also starts the 14-day trial.

const CARD_COLORS := {"supporter": UIStyle.SKY, "explorer": UIStyle.LILAC, "joker": UIStyle.BUTTER}

var _name_input: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = UIStyle.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 70
	column.offset_right = -70
	column.offset_top = 200
	column.offset_bottom = -160
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 30)
	add_child(column)

	var title := Label.new()
	title.text = "Знакомься, это Блупи!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.label(title, 64, Color.WHITE)
	column.add_child(title)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Как тебя зовут?"
	_name_input.max_length = 24
	_name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_input.custom_minimum_size = Vector2(0, 110)
	UIStyle.line_edit(_name_input)
	column.add_child(_name_input)

	var subtitle := Label.new()
	subtitle.text = "Каким другом он будет для тебя?"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.label(subtitle, 38, Color(1, 1, 1, 0.85))
	column.add_child(subtitle)

	for id: String in GameState.ARCHETYPES:
		var info: Dictionary = GameState.ARCHETYPES[id]
		var button := Button.new()
		button.text = "%s\n%s" % [info.title, info.about]
		button.custom_minimum_size = Vector2(0, 200)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UIStyle.button(button, CARD_COLORS[id], 48, 38)
		button.pressed.connect(_choose.bind(id))
		column.add_child(button)

	var note := Label.new()
	note.text = "14 дней полного доступа бесплатно.\nАльбом воспоминаний останется с тобой навсегда."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.label(note, 30, Color(1, 1, 1, 0.7))
	column.add_child(note)
	GameState.hatched_changed.connect(_dismiss)


func _choose(id: String) -> void:
	GameState.hatch(id, _name_input.text)


func _dismiss() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_input.release_focus()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.35)
	fade.tween_callback(queue_free)
