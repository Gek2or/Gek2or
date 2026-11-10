extends Control
## Lo-fi vocal rhythm game. A melody wave scrolls across a translucent staff;
## the player holds a finger on the screen and traces it with a glowing cursor
## while Bloopie sings the traced pitch in real time.

signal pitch_changed(frequency_hz: float)
signal pitch_released
signal finished(accuracy_percent: int)
signal closed

const ROUND_SECONDS := 18.0
const SCROLL_SPEED := 0.42 # melody seconds per screen width
const TOLERANCE := 0.085 # allowed distance from the wave, in lane heights
const MIN_ACCURACY := 15
const LOW_HZ := 330.0
const HIGH_HZ := 784.0
const RESULT_SECONDS := 2.2
const CURSOR_X := 0.3

var _lane := Rect2()
var _elapsed := 0.0
var _hit_time := 0.0
var _holding := false
var _started := false
var _cursor := 0.5
var _result_left := 0.0
var _seed := 0.0
var _trail: Array[Vector2] = []

var _title: Label
var _hint: Label
var _close_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title = Label.new()
	_title.text = "Споём вместе"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 230
	UIStyle.label(_title, 58, Color.WHITE)
	add_child(_title)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 320
	_hint.offset_left = 60
	_hint.offset_right = -60
	UIStyle.label(_hint, 36, Color(1, 1, 1, 0.85))
	add_child(_hint)

	_close_button = Button.new()
	_close_button.icon = load("res://art/icons/close.svg")
	_close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_close_button.offset_left = -160
	_close_button.offset_right = -50
	_close_button.offset_top = 90
	_close_button.offset_bottom = 200
	UIStyle.button(_close_button, UIStyle.ROSE, 55)
	_close_button.pressed.connect(_abort)
	add_child(_close_button)
	set_process(false)


func open() -> void:
	_elapsed = 0.0
	_hit_time = 0.0
	_holding = false
	_started = false
	_result_left = 0.0
	_cursor = 0.5
	_seed = randf() * 40.0
	_trail.clear()
	_hint.text = "Коснись экрана и веди огонёк по волне мелодии"
	visible = true
	set_process(true)
	queue_redraw()


func _abort() -> void:
	_release()
	visible = false
	set_process(false)
	closed.emit()


func _process(delta: float) -> void:
	_lane = Rect2(0, size.y * 0.52, size.x, size.y * 0.3)
	if _result_left > 0.0:
		_result_left -= delta
		if _result_left <= 0.0:
			visible = false
			set_process(false)
			finished.emit(_accuracy())
		queue_redraw()
		return
	if _started:
		_elapsed += delta
		if _holding:
			if absf(_cursor - _melody(_elapsed)) <= TOLERANCE:
				_hit_time += delta
			pitch_changed.emit(lerpf(HIGH_HZ, LOW_HZ, _cursor))
			_trail.push_back(Vector2(_elapsed, _cursor))
			if _trail.size() > 90:
				_trail.pop_front()
		if _elapsed >= ROUND_SECONDS:
			_release()
			_result_left = RESULT_SECONDS
			_hint.text = "Точность: %d%%" % _accuracy()
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


func _move_cursor(y: float) -> void:
	_cursor = clampf((y - _lane.position.y) / maxf(_lane.size.y, 1.0), 0.0, 1.0)


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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.1, 0.2, 0.62))
	if _lane.size.y <= 0.0:
		return
	var lane_box := StyleBoxFlat.new()
	lane_box.bg_color = Color(1, 1, 1, 0.1)
	lane_box.set_corner_radius_all(40)
	draw_style_box(lane_box, _lane.grow_individual(-30, 30, -30, 30))
	for i in 5:
		var y := _lane.position.y + _lane.size.y * (i + 0.5) / 5.0
		draw_line(Vector2(50, y), Vector2(size.x - 50, y), Color(1, 1, 1, 0.22), 3.0)

	var cursor_x := size.x * CURSOR_X
	var seconds_per_pixel := 1.0 / (size.x * SCROLL_SPEED)
	var wave := PackedVector2Array()
	var x := 40.0
	while x <= size.x - 40.0:
		var t := _elapsed + (x - cursor_x) * seconds_per_pixel
		wave.push_back(Vector2(x, _lane.position.y + _melody(t) * _lane.size.y))
		x += 12.0
	draw_polyline(wave, Color(1.0, 0.82, 0.46, 0.28), 44.0, true)
	draw_polyline(wave, Color("#FFD175"), 9.0, true)

	if _trail.size() >= 2:
		var trail := PackedVector2Array()
		for point in _trail:
			trail.push_back(Vector2(cursor_x + (point.x - _elapsed) / seconds_per_pixel, _lane.position.y + point.y * _lane.size.y))
		draw_polyline(trail, Color(0.54, 0.78, 0.97, 0.75), 8.0, true)

	var cursor := Vector2(cursor_x, _lane.position.y + _cursor * _lane.size.y)
	var on_wave := _holding and absf(_cursor - _melody(_elapsed)) <= TOLERANCE
	var glow := Color("#9CE5C8") if on_wave else Color("#8AC7F7")
	draw_circle(cursor, 58.0, Color(glow, 0.2 if _holding else 0.1))
	draw_circle(cursor, 36.0, Color(glow, 0.35))
	draw_circle(cursor, 22.0, glow)
	draw_arc(cursor, 22.0, 0.0, TAU, 28, UIStyle.INK, 5.0, true)

	var bar := Rect2(80, _lane.end.y + 70, size.x - 160, 26)
	draw_rect(bar, Color(1, 1, 1, 0.2))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_elapsed / ROUND_SECONDS, 0.0, 1.0), bar.size.y)), Color("#FFD175"))
