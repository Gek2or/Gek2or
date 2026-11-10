extends Node
## Persistent player/pet state: stats, customization, friendship level,
## 14-day trial with anti-tamper clock and the cryo-capsule (frozen) flag.

signal stats_changed
signal theme_changed(theme_id: String)
signal hat_changed(hat_id: String)
signal level_changed(level: int)
signal frozen_changed(is_frozen: bool)
signal hatched_changed
signal purchase_unavailable

const SAVE_PATH := "user://save.json"
const TRIAL_SECONDS := 14 * 86400
const MAX_LEVEL := 20
const XP_PER_LEVEL := 100
const MAX_RECENT_MEMORIES := 7
const CARE_XP_COOLDOWN := 30

const EMOTIONS: Array[String] = [
	"happy", "excited", "sleepy", "sad", "curious", "love",
	"angry", "surprised", "confused", "shy", "laugh", "proud",
]

const THEME_ORDER: Array[String] = [
	"original", "pink", "purple", "mint", "sunset", "night", "snow", "forest",
]
const THEMES := {
	"original": {"title": "Небесный", "base": Color("#8AC7F7"), "shade": Color("#5B8EC9")},
	"pink": {"title": "Зефирный", "base": Color("#F7A8C4"), "shade": Color("#D46A92")},
	"purple": {"title": "Лавандовый", "base": Color("#B695F8"), "shade": Color("#7A52C7")},
	"mint": {"title": "Мятный", "base": Color("#9CE5C8"), "shade": Color("#56A88A")},
	"sunset": {"title": "Закатный", "base": Color("#FFA96B"), "shade": Color("#E06377")},
	"night": {"title": "Ночной", "base": Color("#2E4078"), "shade": Color("#182246")},
	"snow": {"title": "Снежный", "base": Color("#F2F6FC"), "shade": Color("#B8CCE8")},
	"forest": {"title": "Лесной", "base": Color("#7BC678"), "shade": Color("#46894A")},
}

## Hat id -> friendship level at which it unlocks.
const HAT_ORDER: Array[String] = ["none", "cosy", "cat", "frog", "wizard"]
const HATS := {
	"none": {"title": "Без шапочки", "level": 1},
	"cosy": {"title": "Вязаный капюшон", "level": 1},
	"cat": {"title": "Котик", "level": 5},
	"frog": {"title": "Лягушонок", "level": 10},
	"wizard": {"title": "Волшебник", "level": 20},
}

const ARCHETYPES := {
	"supporter": {"title": "Спокойный друг", "about": "Тёплый, чуткий, всегда поддержит."},
	"explorer": {"title": "Исследователь", "about": "Любознательный мечтатель о звёздах."},
	"joker": {"title": "Весёлый шутник", "about": "Бодрый любитель уютных каламбуров."},
}

var hatched := false
var archetype := "supporter"
var theme_id := "original"
var hat_id := "none"
var mood := 70
var energy := 80
var affection_xp := 0
var vocal_level := 1
var vocal_xp := 0
var recent_memories: Array[String] = []
var trial_start_unix := 0
var last_login_unix := 0
var has_cozy_pass := false
var window_mode := "auto"
var is_frozen := false

var _care_stamps := {}
var _save_queued := false


func _ready() -> void:
	_load()
	_register_login()
	var clock := Timer.new()
	clock.wait_time = 30.0
	clock.autostart = true
	clock.timeout.connect(_on_clock_tick)
	add_child(clock)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save_now()


# --- Time, trial and cryo-capsule -------------------------------------------

## Anti-tamper clock: never lets time run backwards relative to the last login.
func trusted_now() -> int:
	return maxi(int(Time.get_unix_time_from_system()), last_login_unix)


func trial_seconds_left() -> int:
	if trial_start_unix == 0:
		return TRIAL_SECONDS
	return maxi(0, TRIAL_SECONDS - (trusted_now() - trial_start_unix))


func trial_days_left() -> int:
	return int(ceil(trial_seconds_left() / 86400.0))


func _register_login() -> void:
	var now := trusted_now()
	if hatched and last_login_unix > 0:
		# Bloopie rests while the player is away: no decay, only recovery.
		var away_hours := (now - last_login_unix) / 3600.0
		energy = clampi(energy + int(away_hours * 12.0), 0, 100)
		mood = maxi(mood, 55)
	last_login_unix = now
	_refresh_frozen()
	save_now()


func _on_clock_tick() -> void:
	last_login_unix = trusted_now()
	_refresh_frozen()
	_queue_save()


func _refresh_frozen() -> void:
	var frozen := hatched and not has_cozy_pass and trial_seconds_left() <= 0
	if frozen != is_frozen:
		is_frozen = frozen
		frozen_changed.emit(is_frozen)


## Entry point for the "Разбудить Блупи" button. Store billing is wired in on
## the platform side; debug builds grant the pass directly so the flow is testable.
func request_cozy_pass_purchase() -> void:
	if OS.is_debug_build():
		grant_cozy_pass()
	else:
		purchase_unavailable.emit()


func grant_cozy_pass() -> void:
	has_cozy_pass = true
	_refresh_frozen()
	save_now()


# --- Onboarding ---------------------------------------------------------------

func hatch(chosen_archetype: String) -> void:
	archetype = chosen_archetype if ARCHETYPES.has(chosen_archetype) else "supporter"
	hatched = true
	trial_start_unix = trusted_now()
	last_login_unix = trial_start_unix
	save_now()
	hatched_changed.emit()


# --- Stats ---------------------------------------------------------------------

func get_level() -> int:
	return clampi(1 + affection_xp / XP_PER_LEVEL, 1, MAX_LEVEL)


func get_level_progress() -> float:
	if get_level() >= MAX_LEVEL:
		return 1.0
	return float(affection_xp % XP_PER_LEVEL) / XP_PER_LEVEL


## 1 = baby (Lv.1+), 2 = teen (Lv.10+), 3 = grown-up friend (Lv.20).
func get_growth_stage() -> int:
	var level := get_level()
	if level >= 20:
		return 3
	return 2 if level >= 10 else 1


## Smooth body scale: 0.92 at Lv.1, 1.00 at Lv.10, 1.08 at Lv.20.
func get_growth_scale() -> float:
	var level := float(get_level())
	if level <= 10.0:
		return remap(level, 1.0, 10.0, 0.92, 1.0)
	return remap(level, 10.0, 20.0, 1.0, 1.08)


func apply_deltas(mood_delta: int, energy_delta: int, affection_delta: int) -> void:
	var level_before := get_level()
	mood = clampi(mood + mood_delta, 0, 100)
	energy = clampi(energy + energy_delta, 0, 100)
	affection_xp = maxi(0, affection_xp + maxi(0, affection_delta))
	stats_changed.emit()
	if get_level() != level_before:
		level_changed.emit(get_level())
	_queue_save()


## Care actions always feel good, but grant friendship XP at most once per cooldown.
func care_affection(action: String, amount: int) -> int:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_care_stamps.get(action, -1000.0)) < CARE_XP_COOLDOWN:
		return 0
	_care_stamps[action] = now
	return amount


func add_vocal_result(accuracy_percent: int) -> void:
	vocal_xp += accuracy_percent
	vocal_level = 1 + vocal_xp / 250
	_queue_save()


func remember(fact: String) -> void:
	var clean := fact.strip_edges()
	if clean.is_empty():
		return
	recent_memories.push_back(clean)
	while recent_memories.size() > MAX_RECENT_MEMORIES:
		recent_memories.pop_front()
	_queue_save()


# --- Customization ----------------------------------------------------------------

func get_palette() -> Dictionary:
	return THEMES[theme_id]


func set_theme(id: String) -> void:
	if not THEMES.has(id) or id == theme_id:
		return
	theme_id = id
	theme_changed.emit(theme_id)
	_queue_save()


func cycle_theme() -> String:
	var index := (THEME_ORDER.find(theme_id) + 1) % THEME_ORDER.size()
	set_theme(THEME_ORDER[index])
	return theme_id


func is_hat_unlocked(id: String) -> bool:
	return HATS.has(id) and get_level() >= int(HATS[id]["level"])


func set_hat(id: String) -> void:
	if not is_hat_unlocked(id) or id == hat_id:
		return
	hat_id = id
	hat_changed.emit(hat_id)
	_queue_save()


## Moves to the next unlocked hat and returns its id.
func cycle_hat() -> String:
	var index := HAT_ORDER.find(hat_id)
	for step in range(1, HAT_ORDER.size() + 1):
		var candidate: String = HAT_ORDER[(index + step) % HAT_ORDER.size()]
		if is_hat_unlocked(candidate):
			set_hat(candidate)
			break
	return hat_id


## Next hat that is still locked, or "" when everything is unlocked.
func next_locked_hat() -> String:
	for id in HAT_ORDER:
		if not is_hat_unlocked(id):
			return id
	return ""


func set_window_mode(mode: String) -> void:
	window_mode = mode
	_queue_save()


# --- Persistence -----------------------------------------------------------------

func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	get_tree().create_timer(1.0).timeout.connect(save_now)


func save_now() -> void:
	_save_queued = false
	var data := {
		"hatched": hatched,
		"archetype": archetype,
		"theme_id": theme_id,
		"hat_id": hat_id,
		"mood": mood,
		"energy": energy,
		"affection_xp": affection_xp,
		"vocal_level": vocal_level,
		"vocal_xp": vocal_xp,
		"recent_memories": recent_memories,
		"trial_start_unix": trial_start_unix,
		"last_login_unix": last_login_unix,
		"has_cozy_pass": has_cozy_pass,
		"window_mode": window_mode,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameState: cannot write save (%s)" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: save file is corrupted, starting fresh")
		return
	var data: Dictionary = parsed
	hatched = bool(data.get("hatched", false))
	archetype = str(data.get("archetype", "supporter"))
	if not ARCHETYPES.has(archetype):
		archetype = "supporter"
	theme_id = str(data.get("theme_id", "original"))
	if not THEMES.has(theme_id):
		theme_id = "original"
	hat_id = str(data.get("hat_id", "none"))
	if not HATS.has(hat_id):
		hat_id = "none"
	mood = clampi(int(data.get("mood", 70)), 0, 100)
	energy = clampi(int(data.get("energy", 80)), 0, 100)
	affection_xp = maxi(0, int(data.get("affection_xp", 0)))
	vocal_level = maxi(1, int(data.get("vocal_level", 1)))
	vocal_xp = maxi(0, int(data.get("vocal_xp", 0)))
	trial_start_unix = int(data.get("trial_start_unix", 0))
	last_login_unix = int(data.get("last_login_unix", 0))
	has_cozy_pass = bool(data.get("has_cozy_pass", false))
	window_mode = str(data.get("window_mode", "auto"))
	recent_memories.clear()
	var stored: Variant = data.get("recent_memories", [])
	if typeof(stored) == TYPE_ARRAY:
		for item: Variant in stored:
			recent_memories.push_back(str(item))
	while recent_memories.size() > MAX_RECENT_MEMORIES:
		recent_memories.pop_front()
