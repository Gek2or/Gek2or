extends Node
## Tracks the player's local time of day and the cozy weather outside the window.
## Weather is generated on-device from the calendar date and hour, so it is stable
## for the whole hour, works offline and never needs the player's location.

signal atmosphere_changed

const MODE_ORDER: Array[String] = ["auto", "evening", "sunset", "night"]
const MODE_TITLES := {
	"auto": "Как за окном",
	"evening": "Дождливые сумерки",
	"sunset": "Закат",
	"night": "Ночь",
}
const WEATHER_TITLES := {"rain": "дождь", "drizzle": "морось", "clear": "ясно"}

var time_of_day := "evening"
var weather := "rain"

var _last_hour := -1


func _ready() -> void:
	_refresh()
	var clock := Timer.new()
	clock.wait_time = 60.0
	clock.autostart = true
	clock.timeout.connect(_refresh)
	add_child(clock)


## Lighting mode actually shown in the window: "evening", "sunset" or "night".
func get_window_mode() -> String:
	if GameState.window_mode != "auto":
		return GameState.window_mode
	match time_of_day:
		"night":
			return "night"
		"sunset":
			return "sunset"
		_:
			return "evening"


func get_rain_intensity() -> float:
	match get_window_mode():
		"sunset":
			return 0.0 if GameState.window_mode != "auto" or weather == "clear" else 0.3
		"night":
			return 0.35 if weather == "rain" else 0.1
		_:
			if GameState.window_mode != "auto":
				return 0.9
			return {"rain": 0.9, "drizzle": 0.45, "clear": 0.15}[weather]


func cycle_window_mode() -> String:
	var index := (MODE_ORDER.find(GameState.window_mode) + 1) % MODE_ORDER.size()
	GameState.set_window_mode(MODE_ORDER[index])
	atmosphere_changed.emit()
	return GameState.window_mode


## Compact context sent to the AI with every message.
func get_context() -> Dictionary:
	var now := Time.get_datetime_dict_from_system()
	return {
		"local_time": "%02d:%02d" % [now.hour, now.minute],
		"time_of_day": time_of_day,
		"weather": weather,
		"window_mode": get_window_mode(),
	}


func _refresh() -> void:
	var now := Time.get_datetime_dict_from_system()
	var hour: int = now.hour
	if hour == _last_hour:
		return
	_last_hour = hour
	if hour >= 23 or hour < 6:
		time_of_day = "night"
	elif hour < 12:
		time_of_day = "morning"
	elif hour < 18:
		time_of_day = "day"
	elif hour < 21:
		time_of_day = "sunset"
	else:
		time_of_day = "evening"
	var roll := hash("%d-%d-%d-%d" % [now.year, now.month, now.day, hour / 3]) % 100
	if roll < 45:
		weather = "rain"
	elif roll < 70:
		weather = "drizzle"
	else:
		weather = "clear"
	atmosphere_changed.emit()
