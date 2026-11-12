extends Node
## Persistent player/pet state: stats, coins, customization, friendship level,
## the short AI memory, the polaroid archive and the 14-day trial with an
## anti-tamper clock that puts Bloopie into cryo-stasis when it runs out.

signal stats_changed
signal coins_changed(coins: int)
signal theme_changed(theme_id: String)
signal hat_changed(hat_id: String)
signal level_changed(level: int)
signal frozen_changed(is_frozen: bool)
signal hatched_changed
signal purchase_unavailable

const SAVE_PATH := "user://bloopie_save_v02.json"
const TRIAL_DAYS := 14.0
const MAX_LEVEL := 20
const MAX_VOCAL_LEVEL := 99
const XP_PER_LEVEL := 100
const MAX_RECENT_MEMORIES := 7
const MAX_ALBUM_CARDS := 200
const CARE_XP_COOLDOWN := 30
const STARTING_COINS := 120
const DAILY_GIFT_COINS := 20
const LEVEL_UP_COINS := 25
## Needs drift down slowly but never below this floor: no guilt, no sickness.
const NEED_FLOOR := 35
const HUNGER_PER_HOUR := 4.0
const HYGIENE_PER_HOUR := 3.0

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

## Hats unlock with the friendship level and are then bought once with coins.
const HAT_ORDER: Array[String] = ["none", "cosy", "cat", "frog", "wizard"]
const HATS := {
	"none": {"title": "Без шапочки", "level": 1, "price": 0},
	"cosy": {"title": "Вязаный капюшон", "level": 1, "price": 50},
	"cat": {"title": "Котик", "level": 5, "price": 120},
	"frog": {"title": "Лягушонок", "level": 10, "price": 200},
	"wizard": {"title": "Волшебник", "level": 20, "price": 350},
}

const ARCHETYPES := {
	"supporter": {"title": "Спокойный друг", "about": "Тёплый, чуткий, всегда поддержит."},
	"explorer": {"title": "Исследователь", "about": "Любознательный мечтатель о звёздах."},
	"joker": {"title": "Весёлый шутник", "about": "Бодрый любитель уютных каламбуров."},
}

var hatched := false
var player_name := ""
var archetype := "supporter"
var current_theme := "original"
var current_hat := "none"
var owned_hats: Array[String] = ["none"]
var has_active_subscription := false
var is_frozen := false

var hunger := 80
var hygiene := 80
var energy := 80
var mood := 70
var vocal_level := 1
var vocal_xp := 0
var affection_xp := 0
var pet_level := 1
var coins := STARTING_COINS

## Ring buffer of the last 7 facts sent to the AI with every request.
var recent_memories: Array[String] = []
## Polaroid archive: {timestamp, date_string, caption, image_path}.
var album_cards: Array[Dictionary] = []

var trial_start_unix := 0
var last_login_unix := 0
var last_gift_day := ""
var window_mode := "auto"

var _care_stamps := {}
var _save_queued := false
var _hunger_debt := 0.0
var _hygiene_debt := 0.0


func _ready() -> void:
	_load()
	_register_login()
	var clock := Timer.new()
	clock.wait_time = 30.0
	clock.autostart = true
	clock.timeout.connect(_on_clock_tick.bind(clock.wait_time))
	add_child(clock)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save_now()


# --- Time, trial and cryo-stasis ---------------------------------------------

## Anti-tamper clock: if the system clock was moved back, the last login wins.
func trusted_now() -> int:
	var current_unix := int(Time.get_unix_time_from_system())
	if current_unix < last_login_unix:
		return last_login_unix
	return current_unix


func trial_elapsed_days() -> float:
	if trial_start_unix == 0:
		return 0.0
	return (trusted_now() - trial_start_unix) / 86400.0


func trial_days_left() -> int:
	return int(ceil(maxf(0.0, TRIAL_DAYS - trial_elapsed_days())))


## Returns the coins granted as today's welcome gift (0 if already received).
func claim_daily_gift() -> int:
	var today := Time.get_date_string_from_unix_time(trusted_now())
	if not hatched or is_frozen or today == last_gift_day:
		return 0
	last_gift_day = today
	add_coins(DAILY_GIFT_COINS)
	return DAILY_GIFT_COINS


func _register_login() -> void:
	var now := trusted_now()
	if hatched and last_login_unix > 0:
		# Bloopie rests while the player is away: energy recovers, needs drift
		# down gently to the floor, mood never drops.
		var away_hours := (now - last_login_unix) / 3600.0
		energy = clampi(energy + int(away_hours * 12.0), 0, 100)
		hunger = maxi(mini(hunger, NEED_FLOOR), hunger - int(away_hours * HUNGER_PER_HOUR))
		hygiene = maxi(mini(hygiene, NEED_FLOOR), hygiene - int(away_hours * HYGIENE_PER_HOUR))
		mood = maxi(mood, 55)
	last_login_unix = now
	_refresh_frozen()
	save_now()


func _on_clock_tick(seconds: float) -> void:
	last_login_unix = trusted_now()
	_refresh_frozen()
	if hatched and not is_frozen:
		_hunger_debt += seconds / 3600.0 * HUNGER_PER_HOUR
		_hygiene_debt += seconds / 3600.0 * HYGIENE_PER_HOUR
		var changed := false
		if _hunger_debt >= 1.0 and hunger > NEED_FLOOR:
			hunger -= 1
			_hunger_debt -= 1.0
			changed = true
		if _hygiene_debt >= 1.0 and hygiene > NEED_FLOOR:
			hygiene -= 1
			_hygiene_debt -= 1.0
			changed = true
		if changed:
			stats_changed.emit()
	_queue_save()


func _refresh_frozen() -> void:
	var frozen := hatched and not has_active_subscription and trial_elapsed_days() >= TRIAL_DAYS
	if frozen != is_frozen:
		is_frozen = frozen
		frozen_changed.emit(is_frozen)


## Entry point for the "Wake Up Bloopie (Cozy Pass)" button. Store billing is
## wired in on the platform side; debug builds grant the pass directly so the
## whole flow can be tested.
func request_cozy_pass_purchase() -> void:
	if OS.is_debug_build():
		activate_subscription()
	else:
		purchase_unavailable.emit()


func activate_subscription() -> void:
	has_active_subscription = true
	_refresh_frozen()
	save_now()


# --- Onboarding ----------------------------------------------------------------

func hatch(chosen_archetype: String, chosen_name: String = "") -> void:
	archetype = chosen_archetype if ARCHETYPES.has(chosen_archetype) else "supporter"
	player_name = chosen_name.strip_edges().left(24)
	hatched = true
	trial_start_unix = trusted_now()
	last_login_unix = trial_start_unix
	save_now()
	hatched_changed.emit()


# --- Stats ----------------------------------------------------------------------

func get_level_progress() -> float:
	if pet_level >= MAX_LEVEL:
		return 1.0
	return float(affection_xp % XP_PER_LEVEL) / XP_PER_LEVEL


## Overall happiness shown in the care drawer, 0..100.
func get_happiness() -> int:
	return int(round(mood * 0.4 + hunger * 0.2 + hygiene * 0.2 + energy * 0.2))


## 1 = baby (Lv.1+), 2 = teen (Lv.10+), 3 = grown-up friend (Lv.20).
func get_growth_stage() -> int:
	if pet_level >= 20:
		return 3
	return 2 if pet_level >= 10 else 1


## Smooth body scale: 0.92 at Lv.1, 1.00 at Lv.10, 1.08 at Lv.20.
func get_growth_scale() -> float:
	var level := float(pet_level)
	if level <= 10.0:
		return remap(level, 1.0, 10.0, 0.92, 1.0)
	return remap(level, 10.0, 20.0, 1.0, 1.08)


func apply_deltas(mood_delta: int, energy_delta: int, affection_delta: int) -> void:
	mood = clampi(mood + mood_delta, 0, 100)
	energy = clampi(energy + energy_delta, 0, 100)
	affection_xp = maxi(0, affection_xp + maxi(0, affection_delta))
	_refresh_level()
	stats_changed.emit()
	_queue_save()


func feed(amount: int) -> void:
	hunger = clampi(hunger + amount, 0, 100)
	stats_changed.emit()
	_queue_save()


func wash(amount: int) -> void:
	hygiene = clampi(hygiene + amount, 0, 100)
	stats_changed.emit()
	_queue_save()


func _refresh_level() -> void:
	var level := clampi(1 + affection_xp / XP_PER_LEVEL, 1, MAX_LEVEL)
	if level == pet_level:
		return
	var gained := level - pet_level
	pet_level = level
	if gained > 0:
		add_coins(LEVEL_UP_COINS * gained)
	level_changed.emit(pet_level)


## Care actions always feel good, but grant friendship XP at most once per cooldown.
func care_affection(action: String, amount: int) -> int:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_care_stamps.get(action, -1000.0)) < CARE_XP_COOLDOWN:
		return 0
	_care_stamps[action] = now
	return amount


func add_vocal_result(accuracy_percent: int) -> void:
	vocal_xp += accuracy_percent
	vocal_level = clampi(1 + vocal_xp / 250, 1, MAX_VOCAL_LEVEL)
	_queue_save()


## Pushes a fact into the 7-slot ring buffer, dropping the oldest one.
func remember(fact: String) -> void:
	var clean := fact.strip_edges()
	if clean.is_empty():
		return
	recent_memories.push_back(clean)
	while recent_memories.size() > MAX_RECENT_MEMORIES:
		recent_memories.pop_front()
	_queue_save()


## Adds a polaroid card and returns the cards that fell out of the archive.
func add_album_card(card: Dictionary) -> Array[Dictionary]:
	var dropped: Array[Dictionary] = []
	album_cards.push_back(card)
	while album_cards.size() > MAX_ALBUM_CARDS:
		dropped.push_back(album_cards.pop_front())
	save_now()
	return dropped


# --- Coins ------------------------------------------------------------------------

func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	coins_changed.emit(coins)
	_queue_save()


func spend_coins(amount: int) -> bool:
	if amount > coins:
		return false
	add_coins(-amount)
	return true


# --- Customization -------------------------------------------------------------------

func get_palette() -> Dictionary:
	return THEMES[current_theme]


func set_theme(id: String) -> void:
	if not THEMES.has(id) or id == current_theme:
		return
	current_theme = id
	theme_changed.emit(current_theme)
	_queue_save()


func cycle_theme() -> String:
	var index := (THEME_ORDER.find(current_theme) + 1) % THEME_ORDER.size()
	set_theme(THEME_ORDER[index])
	return current_theme


func is_hat_unlocked(id: String) -> bool:
	return HATS.has(id) and pet_level >= int(HATS[id]["level"])


func is_hat_owned(id: String) -> bool:
	return owned_hats.has(id)


func set_hat(id: String) -> void:
	if not is_hat_owned(id) or id == current_hat:
		return
	current_hat = id
	hat_changed.emit(current_hat)
	_queue_save()


## Buys an unlocked hat. Returns false when it is locked or coins are short.
func buy_hat(id: String) -> bool:
	if is_hat_owned(id):
		return true
	if not is_hat_unlocked(id) or not spend_coins(int(HATS[id]["price"])):
		return false
	owned_hats.push_back(id)
	save_now()
	return true


## The hat that follows the current one in the wardrobe order.
func next_hat() -> String:
	return HAT_ORDER[(HAT_ORDER.find(current_hat) + 1) % HAT_ORDER.size()]


func set_window_mode(mode: String) -> void:
	window_mode = mode
	_queue_save()


# --- Persistence --------------------------------------------------------------------

func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	get_tree().create_timer(1.0).timeout.connect(save_now)


func save_now() -> void:
	_save_queued = false
	var data := {
		"hatched": hatched,
		"player_name": player_name,
		"archetype": archetype,
		"current_theme": current_theme,
		"current_hat": current_hat,
		"owned_hats": owned_hats,
		"has_active_subscription": has_active_subscription,
		"hunger": hunger,
		"hygiene": hygiene,
		"energy": energy,
		"mood": mood,
		"vocal_level": vocal_level,
		"vocal_xp": vocal_xp,
		"affection_xp": affection_xp,
		"pet_level": pet_level,
		"coins": coins,
		"recent_memories": recent_memories,
		"album_cards": album_cards,
		"trial_start_unix": trial_start_unix,
		"last_login_unix": last_login_unix,
		"last_gift_day": last_gift_day,
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
	player_name = str(data.get("player_name", "")).left(24)
	archetype = str(data.get("archetype", "supporter"))
	if not ARCHETYPES.has(archetype):
		archetype = "supporter"
	current_theme = str(data.get("current_theme", "original"))
	if not THEMES.has(current_theme):
		current_theme = "original"
	owned_hats.assign(["none"])
	var stored_hats: Variant = data.get("owned_hats", [])
	if typeof(stored_hats) == TYPE_ARRAY:
		for item: Variant in stored_hats:
			if HATS.has(str(item)) and not owned_hats.has(str(item)):
				owned_hats.push_back(str(item))
	current_hat = str(data.get("current_hat", "none"))
	if not owned_hats.has(current_hat):
		current_hat = "none"
	has_active_subscription = bool(data.get("has_active_subscription", false))
	hunger = clampi(int(data.get("hunger", 80)), 0, 100)
	hygiene = clampi(int(data.get("hygiene", 80)), 0, 100)
	energy = clampi(int(data.get("energy", 80)), 0, 100)
	mood = clampi(int(data.get("mood", 70)), 0, 100)
	vocal_level = clampi(int(data.get("vocal_level", 1)), 1, MAX_VOCAL_LEVEL)
	vocal_xp = maxi(0, int(data.get("vocal_xp", 0)))
	affection_xp = maxi(0, int(data.get("affection_xp", 0)))
	pet_level = clampi(1 + affection_xp / XP_PER_LEVEL, 1, MAX_LEVEL)
	coins = maxi(0, int(data.get("coins", STARTING_COINS)))
	trial_start_unix = int(data.get("trial_start_unix", 0))
	last_login_unix = int(data.get("last_login_unix", 0))
	last_gift_day = str(data.get("last_gift_day", ""))
	window_mode = str(data.get("window_mode", "auto"))
	recent_memories.clear()
	var stored_memories: Variant = data.get("recent_memories", [])
	if typeof(stored_memories) == TYPE_ARRAY:
		for item: Variant in stored_memories:
			recent_memories.push_back(str(item))
	while recent_memories.size() > MAX_RECENT_MEMORIES:
		recent_memories.pop_front()
	album_cards.clear()
	var stored_cards: Variant = data.get("album_cards", [])
	if typeof(stored_cards) == TYPE_ARRAY:
		for item: Variant in stored_cards:
			if typeof(item) == TYPE_DICTIONARY:
				album_cards.push_back({
					"timestamp": int(item.get("timestamp", 0)),
					"date_string": str(item.get("date_string", "")),
					"caption": str(item.get("caption", "")),
					"image_path": str(item.get("image_path", "")),
				})
