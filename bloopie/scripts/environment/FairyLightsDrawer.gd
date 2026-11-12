extends Node2D
## Foreground glow for the fairy lights that are painted into the backdrop:
## every bulb gets a soft, slowly twinkling halo. Bulb positions come from
## res://art/painted/painted.json (pixels of the 1124x1998 source painting).

const GLOW := Color("#FFC86B")
const SOURCE_WIDTH := 1124.0
const CANVAS_WIDTH := 1080.0
const REDRAW_INTERVAL := 1.0 / 15.0

## 0..1 overall glow strength, tweened by EnvironmentController.
var brightness := 1.0

var _bulbs := {}
var _room := "supporter"
var _time := 0.0
var _redraw_clock := 0.0


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art/painted/painted.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("FairyLightsDrawer: painted.json is missing or broken")
		return
	var scale_to_canvas := CANVAS_WIDTH / SOURCE_WIDTH
	var stored: Dictionary = parsed.get("bulbs", {})
	for room: String in stored:
		var points := PackedVector2Array()
		for item: Variant in stored[room]:
			points.push_back(Vector2(item[0], item[1]) * scale_to_canvas)
		_bulbs[room] = points


func set_room(room: String) -> void:
	_room = room
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_redraw_clock -= delta
	if _redraw_clock <= 0.0:
		_redraw_clock = REDRAW_INTERVAL
		queue_redraw()


func _draw() -> void:
	var points: PackedVector2Array = _bulbs.get(_room, PackedVector2Array())
	for i in points.size():
		var twinkle := (0.55 + 0.45 * sin(_time * 1.6 + i * 1.9)) * brightness
		BloopieArt.glow(self, points[i], 86.0, Color(GLOW, 0.34 * twinkle))
		BloopieArt.glow(self, points[i], 30.0, Color(1.0, 0.95, 0.8, 0.5 * twinkle))
