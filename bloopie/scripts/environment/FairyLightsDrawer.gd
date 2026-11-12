extends Node2D
## Foreground glow for the fairy lights that are painted into the backdrop:
## every bulb gets a soft, slowly twinkling halo. Bulb positions are stored per
## room picture in the painted art manifest.

const GLOW := Color("#FFC86B")
const REDRAW_INTERVAL := 1.0 / 15.0

## 0..1 overall glow strength, tweened by EnvironmentController.
var brightness := 1.0

var _points := PackedVector2Array()
var _time := 0.0
var _redraw_clock := 0.0


## `room_file` is the backdrop picture currently shown.
func set_room(room_file: String) -> void:
	_points = PaintedArt.bulbs(room_file)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_redraw_clock -= delta
	if _redraw_clock <= 0.0:
		_redraw_clock = REDRAW_INTERVAL
		queue_redraw()


func _draw() -> void:
	for i in _points.size():
		var twinkle := (0.55 + 0.45 * sin(_time * 1.6 + i * 1.9)) * brightness
		BloopieArt.glow(self, _points[i], 86.0, Color(GLOW, 0.34 * twinkle))
		BloopieArt.glow(self, _points[i], 30.0, Color(1.0, 0.95, 0.8, 0.5 * twinkle))
