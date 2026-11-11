extends Node2D
## Root of the game: wires the HUD to Bloopie, the AI client, the care drawer,
## the vocal mini-game, the polaroid album and the trial paywall.

const HOME_ZOOM := Vector2.ONE
const CHAT_ZOOM := Vector2(1.18, 1.18)
const CAMERA_HOME := Vector2(540, 960)
const CAMERA_CHAT := Vector2(540, 900)
const CAMERA_CARE := Vector2(540, 1130)
const CARE_ZOOM := Vector2(0.86, 0.86)
const POLAROID_DELAY := 0.45
const POLAROID_SIDE := 1000.0
const CHAT_BAR_HEIGHT := 116.0
const CHAT_BAR_BOTTOM := 300.0
const QUICK_REPLIES_GAP := 20.0
const QUICK_REPLIES_HEIGHT := 92.0
const COCOA_PRICE := 5
const TART_PRICE := 10

const CARE_LINES := {
	"cocoa": ["Ммм, какао! Тёплое, как твои ладошки.", "Спасибо! Пенка осталась на носу?"],
	"tart": ["Ягодный тарт! Чур, крошки не считаем.", "Вкуснятина. Половинку оставлю тебе."],
	"wash": ["Пузырики! Щекотно!", "Буль-буль. Теперь я блестящий."],
}
const GREETINGS := {
	"morning": "Доброе утро%s! Я занял тебе место на подушке.",
	"day": "Привет%s! Как проходит твой день?",
	"evening": "Добрый вечер%s. Как прошёл твой день?",
	"night": "Тсс, уже ночь%s. Я рад, что ты рядом.",
}

var _chat_open := false
var _care_open := false
var _camera_tween: Tween
var _toast_tween: Tween
var _greeted := false
## Hat the player was just offered to buy; a second tap confirms the purchase.
var _offered_hat := ""

@onready var _environment: CanvasLayer = $EnvironmentLayer
@onready var _bloopie: Area2D = $BloopieActor
@onready var _camera: Camera2D = $Camera2D
@onready var _hud: CanvasLayer = $HUD
@onready var _top_bar: HBoxContainer = $HUD/TopBar
@onready var _level_pill: PanelContainer = $HUD/TopBar/LevelPill
@onready var _level_label: Label = $HUD/TopBar/LevelPill/Row/LevelLabel
@onready var _coins_pill: PanelContainer = $HUD/TopBar/CoinsPill
@onready var _coins_label: Label = $HUD/TopBar/CoinsPill/Row/CoinsLabel
@onready var _mood_bar: ProgressBar = $HUD/TopBar/MoodBar
@onready var _album_button: Button = $HUD/TopBar/AlbumButton
@onready var _quick_replies: HBoxContainer = $HUD/QuickReplies
@onready var _chat_bar: HBoxContainer = $HUD/ChatBar
@onready var _message_input: LineEdit = $HUD/ChatBar/MessageInput
@onready var _send_button: Button = $HUD/ChatBar/SendButton
@onready var _care_drawer: PanelContainer = $HUD/CareDrawer
@onready var _dock_panel: Panel = $HUD/DockPanel
@onready var _dock: HBoxContainer = $HUD/BottomDock
@onready var _btn_chat: Button = $HUD/BottomDock/BtnChat
@onready var _btn_care: Button = $HUD/BottomDock/BtnCare
@onready var _btn_play: Button = $HUD/BottomDock/BtnPlay
@onready var _btn_sleep: Button = $HUD/BottomDock/BtnSleep
@onready var _minigame: Control = $HUD/VocalMinigame
@onready var _album: Control = $HUD/MemoryAlbum
@onready var _paywall: PanelContainer = $HUD/PaywallModal
@onready var _paywall_note: Label = $HUD/PaywallModal/Content/Note
@onready var _wake_up_button: Button = $HUD/PaywallModal/Content/WakeUpButton
@onready var _toast: Label = $HUD/Toast
@onready var _flash: ColorRect = $HUD/CameraFlashRect


func _ready() -> void:
	_style_hud()
	MemoryManager.register_camera(_hud, _flash)
	_album_button.pressed.connect(_open_album)
	_btn_chat.pressed.connect(_toggle_chat)
	_btn_care.pressed.connect(_toggle_care)
	_btn_play.pressed.connect(_open_minigame)
	_btn_sleep.pressed.connect(_toggle_sleep)
	_send_button.pressed.connect(_send_typed_message)
	_message_input.text_submitted.connect(func(_text: String) -> void: _send_typed_message())
	for chip: Button in _quick_replies.get_children():
		chip.pressed.connect(_send_message.bind(chip.text))
	_care_drawer.connect("action_requested", _on_care_action)
	_minigame.connect("pitch_changed", _bloopie.start_singing)
	_minigame.connect("pitch_released", _bloopie.stop_singing)
	_minigame.connect("finished", _on_minigame_finished)
	_minigame.connect("closed", _on_minigame_closed)
	_wake_up_button.pressed.connect(GameState.request_cozy_pass_purchase)

	_bloopie.connect("woke_up", _on_bloopie_woke_up)
	AIClient.reply_received.connect(_on_reply)
	MemoryManager.memory_saved.connect(_on_memory_saved)
	GameState.stats_changed.connect(_refresh_top_bar)
	GameState.coins_changed.connect(func(_coins: int) -> void: _refresh_top_bar())
	GameState.level_changed.connect(_on_level_changed)
	GameState.frozen_changed.connect(_on_frozen_changed)
	GameState.hatched_changed.connect(_on_hatched)
	GameState.purchase_unavailable.connect(_on_purchase_unavailable)

	_refresh_top_bar()
	_set_chat_open(false)
	_on_frozen_changed(GameState.is_frozen)
	if GameState.hatched:
		_greet()
	else:
		_set_hud_enabled(false)
		var onboarding := Control.new()
		onboarding.set_script(load("res://scripts/ui/Onboarding.gd"))
		_hud.add_child(onboarding)


func _process(_delta: float) -> void:
	if _chat_open:
		_lift_chat_above_keyboard()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back button closes the top-most overlay.
		if _album.visible:
			_album.call("close")
		elif _care_open:
			_set_care_open(false)
		elif _chat_open:
			_set_chat_open(false)


# --- HUD ------------------------------------------------------------------------------------------

func _style_hud() -> void:
	_level_pill.add_theme_stylebox_override("panel", UIStyle.pill())
	_coins_pill.add_theme_stylebox_override("panel", UIStyle.pill())
	UIStyle.label(_level_label, 44)
	UIStyle.label(_coins_label, 44)
	UIStyle.progress_bar(_mood_bar, Color("#FF8FA3"))
	UIStyle.button(_album_button, Color(1.0, 0.97, 0.93, 0.94), 48)
	_dock_panel.add_theme_stylebox_override("panel", UIStyle.frame(64))
	for button: Button in _dock.get_children():
		UIStyle.tile(button)
	UIStyle.line_edit(_message_input)
	UIStyle.button(_send_button, UIStyle.SKY, 58)
	for chip: Button in _quick_replies.get_children():
		UIStyle.button(chip, Color(1.0, 0.97, 0.93, 0.96), 46, 31)
	_paywall.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	UIStyle.ice_button(_wake_up_button)
	UIStyle.label(_paywall_note, 32, Color.WHITE)
	_paywall_note.add_theme_color_override("font_outline_color", Color(UIStyle.INK, 0.85))
	_paywall_note.add_theme_constant_override("outline_size", 10)
	UIStyle.label(_toast, 34, Color.WHITE)
	_toast.add_theme_stylebox_override("normal", UIStyle.glass(40))
	_toast.visible = false
	_flash.visible = false


func _refresh_top_bar() -> void:
	_level_label.text = "Lv.%d" % GameState.pet_level
	_coins_label.text = str(GameState.coins)
	_mood_bar.value = GameState.mood


func _set_hud_enabled(enabled: bool) -> void:
	for button: Button in [_btn_chat, _btn_care, _btn_play, _btn_sleep]:
		button.disabled = not enabled
	if not enabled:
		_set_chat_open(false)
		_set_care_open(false)


func _set_dock_visible(shown: bool) -> void:
	_dock.visible = shown
	_dock_panel.visible = shown


func _show_toast(text: String) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


# --- Greeting and onboarding ----------------------------------------------------------------------

func _on_hatched() -> void:
	_set_hud_enabled(true)
	_greet()


func _greet() -> void:
	if _greeted or GameState.is_frozen:
		return
	_greeted = true
	var address := "" if GameState.player_name.is_empty() else ", " + GameState.player_name
	await get_tree().create_timer(0.8).timeout
	_bloopie.call("say", GREETINGS[TimeWeatherSystem.get_day_part()] % address, "happy")
	var gift := GameState.claim_daily_gift()
	if gift > 0:
		_show_toast("Подарок дня: +%d монет" % gift)
	elif not GameState.has_active_subscription:
		_show_toast("Пробный период: ещё %d дн." % GameState.trial_days_left())


# --- Camera ---------------------------------------------------------------------------------------

## Chat zooms in on Bloopie; the care drawer pulls the view back and up so he
## stays visible above it.
func _frame_camera() -> void:
	var target := CAMERA_HOME
	var zoom := HOME_ZOOM
	if _chat_open:
		target = CAMERA_CHAT
		zoom = CHAT_ZOOM
	elif _care_open:
		target = CAMERA_CARE
		zoom = CARE_ZOOM
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(_camera, "zoom", zoom, 0.45)
	_camera_tween.tween_property(_camera, "position", target, 0.45)


# --- Chat -----------------------------------------------------------------------------------------

func _toggle_chat() -> void:
	_set_chat_open(not _chat_open)


func _set_chat_open(open: bool) -> void:
	_chat_open = open
	_chat_bar.visible = open
	_quick_replies.visible = open
	if open:
		_care_open = false
		_care_drawer.call("close")
		if _bloopie.get("is_sleeping"):
			_set_sleeping(false)
	else:
		_message_input.release_focus()
		_place_chat(0.0)
	_frame_camera()


## Keeps the input row and quick replies above the on-screen keyboard.
func _lift_chat_above_keyboard() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	var keyboard_pixels := DisplayServer.virtual_keyboard_get_height()
	var window_height := maxf(float(get_window().size.y), 1.0)
	var keyboard := keyboard_pixels * get_viewport_rect().size.y / window_height
	_place_chat(maxf(0.0, keyboard + 24.0 - CHAT_BAR_BOTTOM))


func _place_chat(lift: float) -> void:
	_chat_bar.offset_bottom = -CHAT_BAR_BOTTOM - lift
	_chat_bar.offset_top = _chat_bar.offset_bottom - CHAT_BAR_HEIGHT
	_quick_replies.offset_bottom = _chat_bar.offset_top - QUICK_REPLIES_GAP
	_quick_replies.offset_top = _quick_replies.offset_bottom - QUICK_REPLIES_HEIGHT


func _send_typed_message() -> void:
	var text := _message_input.text.strip_edges()
	if text.is_empty():
		return
	_message_input.clear()
	_send_message(text)


func _send_message(text: String, event: Dictionary = {}) -> void:
	if AIClient.is_busy or GameState.is_frozen:
		return
	_send_button.disabled = true
	_bloopie.call("show_thinking")
	AIClient.send_message(text, event)


func _on_reply(response: Dictionary) -> void:
	_send_button.disabled = false
	var deltas: Dictionary = response.stat_deltas
	GameState.apply_deltas(deltas.mood_delta, deltas.energy_delta, deltas.affection_delta)
	_bloopie.call("say", response.reply_text, response.emotion_animation)
	var memory: String = response.save_to_memory
	if not memory.is_empty():
		await get_tree().create_timer(POLAROID_DELAY).timeout
		var focus: Vector2 = _bloopie.call("get_canvas_center")
		MemoryManager.take_polaroid(memory, focus + Vector2(0, -40) * _camera.zoom.y, POLAROID_SIDE * _camera.zoom.x)


# --- Polaroid album -------------------------------------------------------------------------------

func _on_memory_saved(_card: Dictionary) -> void:
	_bloopie.call("play_sound", "shutter")
	_show_toast("Новый снимок в альбоме")


func _open_album() -> void:
	_set_care_open(false)
	_album.call("open")


# --- Care -----------------------------------------------------------------------------------------

func _toggle_care() -> void:
	if not _care_open:
		_set_chat_open(false)
		if _bloopie.get("is_sleeping"):
			_set_sleeping(false)
	_set_care_open(not _care_open)


func _set_care_open(open: bool) -> void:
	_care_open = open
	_offered_hat = ""
	_care_drawer.call("open" if open else "close")
	_frame_camera()


func _on_care_action(action: String) -> void:
	if action != "hat":
		_offered_hat = ""
	match action:
		"cocoa":
			if _pay(COCOA_PRICE):
				GameState.feed(12)
				GameState.apply_deltas(6, 4, GameState.care_affection("cocoa", 3))
				_bloopie.call("say", _pick(CARE_LINES.cocoa), "happy")
		"tart":
			if _pay(TART_PRICE):
				GameState.feed(25)
				GameState.apply_deltas(8, 8, GameState.care_affection("tart", 3))
				_bloopie.call("say", _pick(CARE_LINES.tart), "excited")
		"wash":
			GameState.wash(30)
			GameState.apply_deltas(5, 0, GameState.care_affection("wash", 3))
			_bloopie.call("start_bubbles")
			_bloopie.call("say", _pick(CARE_LINES.wash), "laugh")
		"theme":
			var theme_id := GameState.cycle_theme()
			_bloopie.call("show_emotion", "proud", 2.0)
			_show_toast("Тема: %s" % GameState.THEMES[theme_id].title)
		"hat":
			_next_hat()
		"weather":
			var mode := TimeWeatherSystem.cycle_window_mode()
			_show_toast("За окном: %s" % TimeWeatherSystem.MODE_TITLES[mode].to_lower())


func _pay(price: int) -> bool:
	if GameState.spend_coins(price):
		return true
	_show_toast("Не хватает монеток. Споём вместе — заработаем!")
	return false


## Walks through the wardrobe. Owned hats are put on at once; a hat that is
## unlocked but not bought yet is offered first and bought on the second tap.
func _next_hat() -> void:
	var hat_id := GameState.next_hat()
	if not _offered_hat.is_empty():
		hat_id = _offered_hat
	var info: Dictionary = GameState.HATS[hat_id]
	if GameState.is_hat_owned(hat_id):
		_wear(hat_id)
	elif not GameState.is_hat_unlocked(hat_id):
		_show_toast("«%s» откроется на Lv.%d" % [info.title, info.level])
		_wear("none")
	elif _offered_hat == hat_id:
		if GameState.buy_hat(hat_id):
			_wear(hat_id)
			_show_toast("Куплено: %s" % info.title)
		else:
			_show_toast("Не хватает монеток: нужно %d" % info.price)
			_wear("none")
	else:
		_offered_hat = hat_id
		_show_toast("«%s» стоит %d монет. Нажми ещё раз, чтобы купить" % [info.title, info.price])


func _wear(hat_id: String) -> void:
	_offered_hat = ""
	GameState.set_hat(hat_id)
	_bloopie.call("show_emotion", "shy" if hat_id != "none" else "happy", 2.0)


func _pick(lines: Array) -> String:
	return lines[randi() % lines.size()]


# --- Sleep ----------------------------------------------------------------------------------------

func _toggle_sleep() -> void:
	_set_sleeping(not _bloopie.get("is_sleeping"))


func _set_sleeping(sleeping: bool) -> void:
	if sleeping:
		_set_chat_open(false)
		_set_care_open(false)
		_bloopie.call("fall_asleep")
		_environment.call("set_sleeping", true)
		_btn_sleep.text = "Будить"
		GameState.apply_deltas(2, 25, 0)
	else:
		_bloopie.call("wake_up")


func _on_bloopie_woke_up() -> void:
	_environment.call("set_sleeping", false)
	_btn_sleep.text = "Сон"


# --- Vocal mini-game ------------------------------------------------------------------------------

func _open_minigame() -> void:
	_set_chat_open(false)
	_set_care_open(false)
	if _bloopie.get("is_sleeping"):
		_set_sleeping(false)
	_set_dock_visible(false)
	_top_bar.visible = false
	_bloopie.call("hush")
	_minigame.call("open")


func _on_minigame_closed() -> void:
	_set_dock_visible(true)
	_top_bar.visible = true
	_bloopie.call("stop_singing")


func _on_minigame_finished(accuracy_percent: int, notes_hit: int) -> void:
	_on_minigame_closed()
	GameState.add_vocal_result(accuracy_percent)
	var reward := 5 + accuracy_percent / 5
	GameState.add_coins(reward)
	_show_toast("Точность %d%% · +%d монет" % [accuracy_percent, reward])
	_send_message("Мы спели вместе!", {
		"type": "vocal_result",
		"accuracy_percent": accuracy_percent,
		"notes_hit": notes_hit,
		"vocal_level": GameState.vocal_level,
	})


# --- Level, trial and cryo-stasis -----------------------------------------------------------------

func _on_level_changed(level: int) -> void:
	_refresh_top_bar()
	_show_toast("Дружба выросла: Lv.%d · +%d монет" % [level, GameState.LEVEL_UP_COINS])


func _on_frozen_changed(frozen: bool) -> void:
	_set_hud_enabled(not frozen and GameState.hatched)
	_environment.call("set_sleeping", frozen)
	_paywall.visible = frozen
	if frozen:
		_minigame.visible = false
		_top_bar.visible = true
		_set_dock_visible(false)
		_paywall_note.text = "Альбом воспоминаний всегда открыт"
	else:
		_set_dock_visible(true)
		_btn_sleep.text = "Сон"
		if GameState.hatched and _greeted:
			_bloopie.call("say", "Я проснулся! Как же я по тебе соскучился.", "love")


func _on_purchase_unavailable() -> void:
	_paywall_note.text = "Покупка Cozy Pass пока недоступна в этой сборке"
