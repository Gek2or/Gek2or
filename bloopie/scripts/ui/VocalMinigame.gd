extends Control
## Lo-fi vocal rhythm game. A neon turquoise melody wave with coloured note
## rings runs through a band above Bloopie. The player holds a finger anywhere
## on the screen and slides it up and down to keep the glowing cursor on the
## wave, while Bloopie sings the traced pitch in real time.

signal pitch_changed(frequency_hz: float, pitch: float)
signal pitch_released
signal finished(accuracy_percent: int, notes_hit: int)
signal closed

const ROUND_SECONDS := 18.0
const SCROLL_SPEED := 0.42 # melody seconds per screen width
const TOLERANCE := 0.1 # allowed distance from the wave, in lane heights
const MIN_ACCURACY := 15
const LOW_HZ := 330.0
const HIGH_HZ := 784.0
const RESULT_SECONDS := 2.2
const CURSOR_X := 0.44
const NOTE_INTERVAL := 0.85
const FIRST_NOTE := 1.4
const WAVE := Color("#4FF0E0")
const NOTE_COLORS: Array[Color] = [Color("#FF7AC8"), Color("#4FE3F0"), Color("#5BE8A0"), Color("#FFE066")]

var _lane := Rect2()
var _elapsed := 0.0
var _hit_time := 0.0
var _holding := false
var _started := false
var _cursor := 0.5
var _result_left := 0.0
var _seed := 0.0
var _clock := 0.0
## Per note: 0 = waiting, 1 = sung, -1 = missed.
var _notes: Array[int] = []
var _bursts: Array[Vector3] = []

var _vocal_label: Label
var _accuracy_label: Label
var _hint: Label
var _stop_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vocal_label = _make_pill(Control.PRESET_TOP_LEFT, "res://art/icons/mic.svg")
	_accuracy_label = _make_pill(Control.PRESET_TOP_RIGHT, "res://art/icons/star.svg")

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -330
	_hint.offset_bottom = -210
	_hint.offset_left = 60
	_hint.offset_right = -60
	UIStyle.label(_hint, 38, Color.WHITE)
	_hint.add_theme_color_override("font_outline_color", Color(UIStyle.INK, 0.85))
	_hint.add_theme_constant_override("outline_size", 12)
	add_child(_hint)

	_stop_button = Button.new()
	_stop_button.text = "Закончить"
	_stop_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_stop_button.offset_left = -190
	_stop_button.offset_right = 190
	_stop_button.offset_top = -190
	_stop_button.offset_bottom = -80
	UIStyle.button(_stop_button, UIStyle.TILE, 55, 38)
	_stop_button.pressed.connect(_abort)
	add_child(_stop_button)
	set_process(false)


func open() -> void:
	_elapsed = 0.0
	_hit_time = 0.0
	_holding = false
	_started = false
	_result_left = 0.0
	_cursor = 0.5
	_seed = randf() * 40.0
	_bursts.clear()
	_notes.clear()
	var note_time := FIRST_NOTE
	while note_time < ROUND_SECONDS - 0.3:
		_notes.push_back(0)
		note_time += NOTE_INTERVAL
	_vocal_label.text = "Вокал Lv.%d" % GameState.vocal_level
	_accuracy_label.text = "Точность —"
	_hint.text = "Коснись экрана и веди огонёк вверх-вниз по волне"
	_stop_button.visible = true
	visible = true
	set_process(true)
	queue_redraw()


func _make_pill(preset: Control.LayoutPreset, icon_path: String) -> Label:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UIStyle.pill())
	pill.set_anchors_and_offsets_preset(preset)
	pill.offset_top = 76
	if preset == Control.PRESET_TOP_LEFT:
		pill.offset_left = 44
	else:
		pill.offset_right = -44
		pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	pill.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var text := Label.new()
	UIStyle.label(text, 42)
	row.add_child(text)
	return text


func _abort() -> void:
	_release()
	visible = false
	set_process(false)
	closed.emit()


func _process(delta: float) -> void:
	_clock += delta
	_lane = Rect2(0, size.y * 0.235, size.x, size.y * 0.165)
	for i in range(_bursts.size() - 1, -1, -1):
		_bursts[i].z -= delta * 1.8
		if _bursts[i].z <= 0.0:
			_bursts.remove_at(i)
	if _result_left > 0.0:
		_result_left -= delta
		if _result_left <= 0.0:
			visible = false
			set_process(false)
			finished.emit(_accuracy(), _notes.count(1))
		queue_redraw()
		return
	if _started:
		_elapsed += delta
		var on_wave := _holding and absf(_cursor - _melody(_elapsed)) <= TOLERANCE
		if _holding:
			if on_wave:
				_hit_time += delta
			pitch_changed.emit(lerpf(HIGH_HZ, LOW_HZ, _cursor), 1.0 - _cursor)
		for i in _notes.size():
			if _notes[i] == 0 and _elapsed >= FIRST_NOTE + i * NOTE_INTERVAL:
				_notes[i] = 1 if on_wave else -1
				if on_wave:
					_bursts.push_back(Vector3(size.x * CURSOR_X, _lane.position.y + _cursor * _lane.size.y, 1.0))
		if _elapsed > 1.0:
			_accuracy_label.text = "Точность %d%%" % int(round(_hit_time / _elapsed * 100.0))
		if _elapsed >= ROUND_SECONDS:
			_release()
			_result_left = RESULT_SECONDS
			_stop_button.visible = false
			_accuracy_label.text = "Точность %d%%" % _accuracy()
			_hint.text = "Спето нот: %d из %d" % [_notes.count(1), _notes.size()]
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _result_left > 0.0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_holding = true
			_started = true
			_hint.text = "Держи огонёк на волне!"
			_move_cursor(event.position.y)
		else:
			_release()
	elif event is InputEventMouseMotion and _holding:
		_move_cursor(event.position.y)


## The whole middle of the screen is the control zone, so the thumb never
## covers the wave: its top maps to the highest note, its bottom to the lowest.
func _move_cursor(y: float) -> void:
	_cursor = clampf(remap(y, size.y * 0.3, size.y * 0.82, 0.0, 1.0), 0.0, 1.0)


func _release() -> void:
	if _holding:
		_holding = false
		pitch_released.emit()


func _accuracy() -> int:
	var raw := int(round(_hit_time / ROUND_SECONDS * 100.0))
	return clampi(raw, MIN_ACCURACY, 100)


## Melody height (0 = top of the lane, 1 = bottom) at melody time `t`.
func _melody(t: float) -> float:
	var s := t + _seed
	return 0.5 + 0.27 * sin(s * 1.25) + 0.11 * sin(s * 2.9 + 1.0) + 0.05 * sin(s * 5.3)


func _draw() -> void:
	if _lane.size.y <= 0.0:
		return
	# Translucent night band with softly waving edges.
	var top_edge := PackedVector2Array()
	var bottom_edge := PackedVector2Array()
	var x := -20.0
	while x <= size.x + 20.0:
		top_edge.push_back(Vector2(x, _lane.position.y - 46.0 + sin(x * 0.006 + _clock * 0.7) * 22.0))
		bottom_edge.push_back(Vector2(x, _lane.end.y + 46.0 + sin(x * 0.007 + _clock * 0.6 + 2.0) * 22.0))
		x += 40.0
	var band := top_edge.duplicate()
	for i in range(bottom_edge.size() - 1, -1, -1):
		band.push_back(bottom_edge[i])
	draw_colored_polygon(band, Color(0.11, 0.13, 0.33, 0.62))
	draw_polyline(top_edge, Color(0.62, 0.68, 1.0, 0.75), 6.0, true)
	draw_polyline(bottom_edge, Color(0.62, 0.68, 1.0, 0.75), 6.0, true)

	var cursor_x := size.x * CURSOR_X
	var seconds_per_pixel := 1.0 / (size.x * SCROLL_SPEED)
	var wave := PackedVector2Array()
	x = -10.0
	while x <= size.x + 10.0:
		var t := _elapsed + (x - cursor_x) * seconds_per_pixel
		wave.push_back(Vector2(x, _lane.position.y + _melody(t) * _lane.size.y))
		x += 12.0
	draw_polyline(wave, Color(WAVE, 0.16), 46.0, true)
	draw_polyline(wave, Color(WAVE, 0.32), 22.0, true)
	draw_polyline(wave, WAVE, 8.0, true)
	draw_polyline(wave, Color(1, 1, 1, 0.85), 3.0, true)

	# Note rings ride on the wave.
	for i in _notes.size():
		if _notes[i] == 1:
			continue
		var note_time := FIRST_NOTE + i * NOTE_INTERVAL
		var note_x := cursor_x + (note_time - _elapsed) / seconds_per_pixel
		if note_x < -60.0 or note_x > size.x + 60.0:
			continue
		var at := Vector2(note_x, _lane.position.y + _melody(note_time) * _lane.size.y)
		var color := NOTE_COLORS[i % NOTE_COLORS.size()]
		var alpha := 0.35 if _notes[i] == -1 else 1.0
		BloopieArt.glow(self, at, 70.0, Color(color, 0.55 * alpha))
		draw_circle(at, 30.0, Color(color, alpha))
		draw_circle(at, 19.0, Color(color.lightened(0.55), alpha))
		draw_arc(at, 30.0, 0.0, TAU, 28, Color(1, 1, 1, 0.9 * alpha), 4.0, true)

	for burst in _bursts:
		var at := Vector2(burst.x, burst.y)
		var grow := 1.0 - burst.z
		draw_arc(at, 40.0 + grow * 90.0, 0.0, TAU, 36, Color(1, 1, 1, burst.z), 5.0, true)
		for i in 8:
			BloopieArt.star4(self, at + Vector2.from_angle(i * TAU / 8.0) * (50.0 + grow * 110.0), 9.0, Color(1, 1, 1, burst.z))

	var cursor := Vector2(cursor_x, _lane.position.y + _cursor * _lane.size.y)
	var on_wave := _holding and absf(_cursor - _melody(_elapsed)) <= TOLERANCE
	var glow := WAVE if on_wave else Color("#BFD8FF")
	BloopieArt.glow(self, cursor, 150.0 if _holding else 100.0, Color(glow, 0.7))
	draw_arc(cursor, 62.0, 0.0, TAU, 36, Color(glow, 0.55), 4.0, true)
	draw_circle(cursor, 40.0, Color(glow, 0.95))
	draw_circle(cursor, 26.0, Color.WHITE)

	# Round progress along the bottom edge of the band.
	var progress := clampf(_elapsed / ROUND_SECONDS, 0.0, 1.0)
	draw_line(Vector2(60, _lane.end.y + 96), Vector2(size.x - 60, _lane.end.y + 96), Color(1, 1, 1, 0.25), 10.0, true)
	draw_line(Vector2(60, _lane.end.y + 96), Vector2(60 + (size.x - 120) * progress, _lane.end.y + 96), WAVE, 10.0, true)
