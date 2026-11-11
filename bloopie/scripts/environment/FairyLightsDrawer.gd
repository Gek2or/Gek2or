extends Node2D
## Foreground string of warm fairy lights hanging across the top of the window.

const WIRE := Color("#3A2A2A")
const GLOW := Color("#FFD175")
const BULB := Color("#FFF1C4")
const ANCHORS: Array[Vector2] = [Vector2(-60, 226), Vector2(330, 300), Vector2(760, 250), Vector2(1140, 236)]
const SAG := 82.0
const BULB_SPACING := 0.2
const REDRAW_INTERVAL := 1.0 / 15.0

## 0..1 overall glow strength, tweened by EnvironmentController.
var brightness := 1.0

var _vignette: GradientTexture2D
var _time := 0.0
var _redraw_clock := 0.0


func _process(delta: float) -> void:
	_time += delta
	_redraw_clock -= delta
	if _redraw_clock <= 0.0:
		_redraw_clock = REDRAW_INTERVAL
		queue_redraw()


func _draw() -> void:
	# Cozy vignette: darkens the corners of the room so Bloopie stays the focus.
	if _vignette == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.06, 0.04, 0.14, 0.0))
		gradient.set_color(1, Color(0.06, 0.04, 0.14, 0.78))
		gradient.set_offset(0, 0.45)
		_vignette = GradientTexture2D.new()
		_vignette.gradient = gradient
		_vignette.width = 128
		_vignette.height = 128
		_vignette.fill = GradientTexture2D.FILL_RADIAL
		_vignette.fill_from = Vector2(0.5, 0.5)
		_vignette.fill_to = Vector2(1.0, 0.5)
	draw_texture_rect(_vignette, Rect2(-760, -700, 2600, 3400), false)
	var bulb_index := 0
	for segment in ANCHORS.size() - 1:
		var from := ANCHORS[segment]
		var to := ANCHORS[segment + 1]
		var wire := PackedVector2Array()
		for i in 25:
			wire.push_back(_hang(from, to, i / 24.0))
		draw_polyline(wire, WIRE, 5.0, true)
		var t := BULB_SPACING * 0.5
		while t < 1.0:
			_draw_bulb(_hang(from, to, t), bulb_index)
			bulb_index += 1
			t += BULB_SPACING


func _hang(from: Vector2, to: Vector2, t: float) -> Vector2:
	return from.lerp(to, t) + Vector2(0, SAG * 4.0 * t * (1.0 - t))


func _draw_bulb(at: Vector2, index: int) -> void:
	var twinkle := (0.82 + 0.18 * sin(_time * 1.7 + index * 1.9)) * brightness
	var center := at + Vector2(0, 26)
	draw_line(at, at + Vector2(0, 12), WIRE, 6.0)
	BloopieArt.glow(self, center, 120.0, Color(GLOW, 0.5 * twinkle))
	BloopieArt.glow(self, center, 44.0, Color(GLOW, 0.8 * twinkle))
	draw_circle(center, 16.0, BULB.lerp(GLOW, 0.25))
	draw_circle(center + Vector2(-4, -4), 6.0, Color(1, 1, 1, 0.9))
