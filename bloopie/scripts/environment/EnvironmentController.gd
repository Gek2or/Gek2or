extends CanvasLayer
## Drives the five room layers: sky, rainy glass, window frame, sill with the
## cushion, and the fairy lights. Blends between the three window moods
## (rainy evening, sunset, night) and dims the room while Bloopie sleeps.

const BLEND_SECONDS := 1.6
const MOODS := {
	"evening": {
		"sky_top": Color("#35295F"), "sky_bottom": Color("#B479A6"), "glow": Color("#FFB26B"),
		"room": Color(1.0, 0.95, 0.97), "lights": 1.0,
	},
	"sunset": {
		"sky_top": Color("#5B4A9E"), "sky_bottom": Color("#FFA56B"), "glow": Color("#FFD27A"),
		"room": Color(1.0, 0.93, 0.86), "lights": 0.75,
	},
	"night": {
		"sky_top": Color("#0D1230"), "sky_bottom": Color("#2A2F6E"), "glow": Color("#F2B56B"),
		"room": Color(0.8, 0.8, 0.96), "lights": 1.0,
	},
}

var _sleeping := false
var _tween: Tween
var _rain_player: AudioStreamPlayer

@onready var _sky: ColorRect = $SkyBackdrop
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
	TimeWeatherSystem.environment_updated.connect(func(_time: String, _weather: String) -> void: _blend_to_current())
	GameState.hatched_changed.connect(_on_archetype_changed)
	_apply(_target_values())


func set_sleeping(sleeping: bool) -> void:
	_sleeping = sleeping
	_blend_to_current()


func _on_archetype_changed() -> void:
	_frame.call("set_archetype", GameState.archetype)
	_sill.call("set_archetype", GameState.archetype)


func _target_values() -> Dictionary:
	var mood: Dictionary = MOODS[TimeWeatherSystem.current_time_of_day]
	var room: Color = mood.room
	var lights: float = mood.lights
	if _sleeping:
		room = room.darkened(0.42)
		lights *= 0.45
	return {
		"sky_top": mood.sky_top, "sky_bottom": mood.sky_bottom, "glow": mood.glow,
		"stars": TimeWeatherSystem.get_star_amount(), "room": room, "lights": lights,
		"rain": TimeWeatherSystem.get_rain_intensity(),
	}


func _current_values() -> Dictionary:
	var material := _glass.material as ShaderMaterial
	return {
		"sky_top": material.get_shader_parameter("sky_top"),
		"sky_bottom": material.get_shader_parameter("sky_bottom"),
		"glow": material.get_shader_parameter("glow_color"),
		"stars": material.get_shader_parameter("star_amount"),
		"room": _sill.modulate,
		"lights": _lights.get("brightness"),
		"rain": material.get_shader_parameter("rain_intensity"),
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
	var material := _glass.material as ShaderMaterial
	material.set_shader_parameter("sky_top", values.sky_top)
	material.set_shader_parameter("sky_bottom", values.sky_bottom)
	material.set_shader_parameter("glow_color", values.glow)
	material.set_shader_parameter("star_amount", values.stars)
	material.set_shader_parameter("rain_intensity", values.rain)
	material.set_shader_parameter("aspect", _glass.size.x / maxf(_glass.size.y, 1.0))
	_sky.color = values.sky_top
	_frame.modulate = values.room
	_sill.modulate = values.room
	_lights.set("brightness", values.lights)
	var rain: float = values.rain
	_rain_player.volume_db = linear_to_db(maxf(0.0001, rain * 0.22))
