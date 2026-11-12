extends CanvasLayer
## Drives the room: the painted backdrop for the current archetype and time of
## day, the living rain / star overlay on the window, the twinkling fairy
## lights, and the dimming for sleep. When a room has no picture for the current
## time of day, the nearest one is colour-graded instead.

const BLEND_SECONDS := 1.6
## Window overlay area per room, in canvas units of the 1080x1920 backdrop.
const WINDOWS := {
	"supporter": Rect2(150, 0, 830, 900),
	"explorer": Rect2(0, 0, 600, 760),
	"joker": Rect2(150, 0, 830, 900),
}
## Colour grading used when the backdrop was painted for another time of day.
const GRADES := {
	"evening": Color(1.0, 1.0, 1.0),
	"sunset": Color(1.0, 0.92, 0.84),
	"night": Color(0.7, 0.74, 0.98),
}
const LIGHTS := {"evening": 1.0, "sunset": 0.75, "night": 1.0}

var _sleeping := false
var _room_file := ""
var _room_exact := true
var _tween: Tween
var _rain_player: AudioStreamPlayer

@onready var _sky: TextureRect = $SkyBackdrop
@onready var _glass: ColorRect = $WindowGlassRain
@onready var _frame: CanvasItem = $WindowFrameProps
@onready var _sill: CanvasItem = $SillAndCushion
@onready var _lights: Node2D = $FairyLightsFG


func _ready() -> void:
	_rain_player = AudioStreamPlayer.new()
	_rain_player.stream = ProcAudio.rain_loop()
	_rain_player.volume_db = -60.0
	add_child(_rain_player)
	_rain_player.play()
	# The painted backdrop already contains the frame, the sill and the cushion.
	_frame.visible = false
	_sill.visible = false
	TimeWeatherSystem.environment_updated.connect(func(_time: String, _weather: String) -> void: _refresh(true))
	GameState.hatched_changed.connect(_refresh.bind(true))
	_refresh(false)


func set_sleeping(sleeping: bool) -> void:
	_sleeping = sleeping
	_blend_to_current()


## Shows the picture for the current archetype and time, cross-fading from the
## previous one, then blends the grading, lights and weather.
func _refresh(animate: bool) -> void:
	var room := PaintedArt.room(GameState.archetype, TimeWeatherSystem.current_time_of_day)
	_room_exact = room.exact
	if room.file != "" and room.file != _room_file:
		if animate and _sky.texture != null:
			_cross_fade()
		_room_file = room.file
		_sky.texture = PaintedArt.texture(room.file)
		var window: Rect2 = WINDOWS.get(room.archetype, WINDOWS["supporter"])
		_glass.position = window.position
		_glass.size = window.size
		(_glass.material as ShaderMaterial).set_shader_parameter("aspect", window.size.x / window.size.y)
		_lights.call("set_room", room.file)
	if animate:
		_blend_to_current()
	else:
		_apply(_target_values())


## Leaves a copy of the old backdrop on top and fades it away.
func _cross_fade() -> void:
	var ghost := _sky.duplicate() as TextureRect
	ghost.z_index = _sky.z_index + 1
	add_child(ghost)
	var fade := ghost.create_tween()
	fade.tween_property(ghost, "modulate:a", 0.0, BLEND_SECONDS)
	fade.tween_callback(ghost.queue_free)


func _target_values() -> Dictionary:
	var time := TimeWeatherSystem.current_time_of_day
	var room: Color = Color.WHITE if _room_exact else GRADES[time]
	var lights: float = LIGHTS[time]
	if _sleeping:
		room = room.darkened(0.4)
		lights *= 0.45
	return {
		"room": room,
		"lights": lights,
		"stars": TimeWeatherSystem.get_star_amount(),
		"rain": TimeWeatherSystem.get_rain_intensity(),
	}


func _current_values() -> Dictionary:
	var glass := _glass.material as ShaderMaterial
	return {
		"room": _sky.modulate,
		"lights": _lights.get("brightness"),
		"stars": glass.get_shader_parameter("star_amount"),
		"rain": glass.get_shader_parameter("rain_intensity"),
	}


func _blend_to_current() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var from := _current_values()
	var to := _target_values()
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void: _apply(_mix(from, to, t)), 0.0, 1.0, BLEND_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _mix(from: Dictionary, to: Dictionary, t: float) -> Dictionary:
	var result := {}
	for key: String in to:
		if to[key] is Color:
			result[key] = (from[key] as Color).lerp(to[key], t)
		else:
			result[key] = lerpf(from[key], to[key], t)
	return result


func _apply(values: Dictionary) -> void:
	var glass := _glass.material as ShaderMaterial
	glass.set_shader_parameter("star_amount", values.stars)
	glass.set_shader_parameter("rain_intensity", values.rain)
	_sky.modulate = values.room
	_lights.set("brightness", values.lights)
	var rain: float = values.rain
	_rain_player.volume_db = linear_to_db(maxf(0.0001, rain * 0.22))
