extends Node
## Keeps the window outside in sync with the player's evening: the time of day
## ("evening", "sunset", "night") and the weather ("rain", "stars"). Weather is
## derived on-device from the calendar date, so it is stable for a few hours,
## works offline and never needs the player's location.

signal environment_updated(time_of_day: String, weather: String)

const MODE_ORDER: Array[String] = ["auto", "evening", "sunset", "night"]
const MODE_TITLES := {
	"auto": "Как за окном",
	"evening": "Дождливые сумерки",
	"sunset": "Закат",
	"night": "Звёздная ночь",
}

var current_time_of_day := "evening"
var current_weather := "rain"

var _last_stamp := ""


func _ready() -> void:
	_refresh()
	var clock := Timer.new()
	clock.wait_time = 60.0
	clock.autostart = true
	clock.timeout.connect(_refresh)
	add_child(clock)
	GameState.hatched_changed.connect(_refresh.bind(true))


func get_rain_intensity() -> float:
	if current_weather == "stars":
		return 0.0
	return 0.9 if current_time_of_day == "evening" else 0.45


func get_star_amount() -> float:
	if current_weather != "stars":
		return 0.1 if current_time_of_day == "night" else 0.0
	return 1.0 if current_time_of_day == "night" else 0.35


## Player override from the care drawer: "auto" follows the real clock.
func cycle_window_mode() -> String:
	var index := (MODE_ORDER.find(GameState.window_mode) + 1) % MODE_ORDER.size()
	GameState.set_window_mode(MODE_ORDER[index])
	_refresh(true)
	return GameState.window_mode


## Part of the real day, used for greetings: morning, day, evening or night.
func get_day_part() -> String:
	var hour: int = Time.get_datetime_dict_from_system().hour
	if hour >= 23 or hour < 6:
		return "night"
	if hour < 12:
		return "morning"
	return "day" if hour < 18 else "evening"


## Compact context sent to the AI with every message.
func get_context() -> Dictionary:
	var now := Time.get_datetime_dict_from_system()
	return {
		"local_time": "%02d:%02d" % [now.hour, now.minute],
		"day_part": get_day_part(),
		"time_of_day": current_time_of_day,
		"weather": current_weather,
	}


func _refresh(force: bool = false) -> void:
	var now := Time.get_datetime_dict_from_system()
	var hour: int = now.hour
	var stamp := "%d-%d|%s|%s" % [now.day, hour, GameState.window_mode, GameState.archetype]
	if stamp == _last_stamp and not force:
		return
	_last_stamp = stamp
	var roll := hash("%d-%d-%d-%d" % [now.year, now.month, now.day, hour / 3]) % 100
	var time_of_day := GameState.window_mode
	var weather := "rain"
	if time_of_day == "auto":
		if hour >= 23 or hour < 6:
			time_of_day = "night"
		elif hour >= 17 and hour < 21:
			time_of_day = "sunset"
		else:
			time_of_day = "evening"
		match time_of_day:
			"night":
				weather = "stars" if roll < 60 else "rain"
			"sunset":
				weather = "stars" if roll < 70 else "rain"
	else:
		weather = "rain" if time_of_day == "evening" else "stars"
	# The explorer's attic window always looks into a starry sky.
	if GameState.archetype == "explorer" and time_of_day != "sunset":
		time_of_day = "night"
		weather = "stars"
	if time_of_day == current_time_of_day and weather == current_weather and not force:
		return
	current_time_of_day = time_of_day
	current_weather = weather
	environment_updated.emit(current_time_of_day, current_weather)
