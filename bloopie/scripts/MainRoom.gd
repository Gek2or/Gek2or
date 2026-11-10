extends Node2D
## Root of the game: wires the HUD to Bloopie, the AI client, the care drawer,
## the vocal mini-game, the polaroid album and the trial paywall.

const HOME_ZOOM := Vector2(1.15, 1.15)
const CHAT_ZOOM := HOME_ZOOM * 1.18
const CAMERA_HOME := Vector2(540, 1010)
const CAMERA_CHAT := Vector2(540, 1040)
const CAMERA_CARE := Vector2(540, 1250)
const POLAROID_DELAY := 0.45
const POLAROID_SIDE := 780.0
const CHAT_BAR_HEIGHT := 110.0
const CHAT_BAR_BOTTOM := 410.0
const QUICK_REPLIES_GAP := 20.0
const QUICK_REPLIES_HEIGHT := 90.0

const CARE_LINES := {
	"cocoa": ["Ммм, какао! Тёплое, как твои ладошки.", "Спасибо! Пенка осталась на носу?"],
	"tart": ["Ягодный тарт! Чур, крошки не считаем.", "Вкуснятина. Половинку оставлю тебе."],
	"wash": ["Пузырики! Щекотно!", "Буль-буль. Теперь я блестящий."],
}

var _chat_open := false
var _care_open := false
var _camera_tween: Tween
var _toast_tween: Tween
var _greeted := false

@onready var _environment: CanvasLayer = $EnvironmentLayer
@onready var _bloopie: Area2D = $BloopieActor
@onready var _camera: Camera2D = $Camera2D
@onready var _hud: CanvasLayer = $HUD
@onready var _level_label: Label = $HUD/TopBar/LevelLabel
@onready var _mood_bar: ProgressBar = $HUD/TopBar/MoodBar
@onready var _album_button: Button = $HUD/TopBar/AlbumButton
@onready var _quick_replies: HBoxContainer = $HUD/QuickReplies
@onready var _chat_bar: HBoxContainer = $HUD/ChatBar
@onready var _message_input: LineEdit = $HUD/ChatBar/MessageInput
@onready var _send_button: Button = $HUD/ChatBar/SendButton
@onready var _care_drawer: PanelContainer = $HUD/CareDrawer
@onready var _dock: HBoxContainer = $HUD/BottomDock
@onready var _btn_chat: Button = $HUD/BottomDock/BtnChat
@onready var _btn_care: Button = $HUD/BottomDock/BtnCare
@onready var _btn_play: Button = $HUD/BottomDock/BtnPlay
@onready var _btn_sleep: Button = $HUD/BottomDock/BtnSleep
@onready var _minigame: Control = $HUD/VocalMinigame
@onready var _album: Control = $HUD/MemoryAlbum
@onready var _paywall: PanelContainer = $HUD/PaywallModal
@onready var _paywall_body: Label = $HUD/PaywallModal/Content/Body
@onready var _unfreeze_button: Button = $HUD/PaywallModal/Content/UnfreezeButton
@onready var _paywall_close: Button = $HUD/PaywallModal/Content/CloseButton
@onready var _toast: Label = $HUD/Toast
@onready var _flash: ColorRect = $HUD/CameraFlashRect


func _ready() -> void:
	_style_hud()
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
	_unfreeze_button.pressed.connect(GameState.request_cozy_pass_purchase)
	_paywall_close.pressed.connect(func() -> void: _paywall.visible = false)

	_bloopie.connect("frozen_tapped", _show_paywall)
	_bloopie.connect("woke_up", _on_bloopie_woke_up)
	AIClient.reply_received.connect(_on_reply)
	GameState.stats_changed.connect(_refresh_top_bar)
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
		elif _paywall.visible:
			_paywall.visible = false
		elif _care_open:
			_set_care_open(false)
		elif _chat_open:
			_set_chat_open(false)


# --- HUD ------------------------------------------------------------------------------------------

func _style_hud() -> void:
	UIStyle.label(_level_label, 44, Color.WHITE)
	_level_label.add_theme_color_override("font_outline_color", UIStyle.INK)
	_level_label.add_theme_constant_override("outline_size", 12)
	UIStyle.progress_bar(_mood_bar, Color("#FF8FA3"))
	UIStyle.button(_album_button, UIStyle.CREAM, 44)
	UIStyle.button(_btn_chat, UIStyle.SKY)
	UIStyle.button(_btn_care, UIStyle.ROSE)
	UIStyle.button(_btn_play, UIStyle.LILAC)
	UIStyle.button(_btn_sleep, UIStyle.BUTTER)
	for button: Button in _dock.get_children():
		button.add_theme_font_size_override("font_size", 32)
		button.add_theme_constant_override("icon_max_width", 76)
	UIStyle.line_edit(_message_input)
	UIStyle.button(_send_button, UIStyle.SKY, 55)
	for chip: Button in _quick_replies.get_children():
		UIStyle.button(chip, UIStyle.CREAM, 45)
		chip.add_theme_font_size_override("font_size", 30)
	_paywall.add_theme_stylebox_override("panel", UIStyle.card(UIStyle.CREAM, 56))
	UIStyle.label($HUD/PaywallModal/Content/Title, 52)
	UIStyle.label(_paywall_body, 34, Color(UIStyle.INK, 0.8))
	UIStyle.button(_unfreeze_button, UIStyle.BUTTER)
	UIStyle.button(_paywall_close, UIStyle.SKY)
	UIStyle.label(_toast, 34, Color.WHITE)
	_toast.add_theme_stylebox_override("normal", UIStyle.glass(40))
	$HUD/TopPanel.add_theme_stylebox_override("panel", UIStyle.glass(60))
	$HUD/DockPanel.add_theme_stylebox_override("panel", UIStyle.glass(64))
	_toast.visible = false
	_flash.visible = false


func _refresh_top_bar() -> void:
	_level_label.text = "Lv.%d" % GameState.get_level()
	_mood_bar.value = GameState.mood


func _set_hud_enabled(enabled: bool) -> void:
	for button: Button in [_btn_chat, _btn_care, _btn_play, _btn_sleep]:
		button.disabled = not enabled
	if not enabled:
		_set_chat_open(false)
		_set_care_open(false)


func _set_dock_visible(shown: bool) -> void:
	_dock.visible = shown
	$HUD/DockPanel.visible = shown


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
	var greetings := {
		"morning": "Доброе утро! Я занял тебе место на подушке.",
		"day": "Привет! Хорошо, что ты заглянул.",
		"sunset": "Смотри, какой закат. Посидим вместе?",
		"evening": "Добрый вечер. За окном шуршит дождь, а у нас тепло.",
		"night": "Тсс, уже ночь. Я рад, что ты рядом.",
	}
	await get_tree().create_timer(0.8).timeout
	_bloopie.call("say", greetings[TimeWeatherSystem.time_of_day], "happy")
	if not GameState.has_cozy_pass:
		_show_toast("Пробный период: ещё %d дн." % GameState.trial_days_left())


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


## Chat zooms in on Bloopie; the care drawer slides the view up so he stays visible.
func _frame_camera() -> void:
	var target := CAMERA_HOME
	if _chat_open:
		target = CAMERA_CHAT
	elif _care_open:
		target = CAMERA_CARE
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(_camera, "zoom", CHAT_ZOOM if _chat_open else HOME_ZOOM, 0.45)
	_camera_tween.tween_property(_camera, "position", target, 0.45)


func _set_care_open(open: bool) -> void:
	_care_open = open
	_care_drawer.call("open" if open else "close")
	_frame_camera()


## Keeps the input row and quick replies above the on-screen keyboard.
func _lift_chat_above_keyboard() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	var keyboard_pixels := DisplayServer.virtual_keyboard_get_height()
	var window_height := maxf(float(get_window().size.y), 1.0)
	var keyboard := keyboard_pixels * get_viewport_rect().size.y / window_height
	_place_chat(maxf(0.0, keyboard + 24.0 - (CHAT_BAR_BOTTOM - CHAT_BAR_HEIGHT)))


func _place_chat(lift: float) -> void:
	_chat_bar.offset_bottom = -(CHAT_BAR_BOTTOM - CHAT_BAR_HEIGHT) - lift
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
		_take_polaroid(memory)


# --- Polaroid camera ------------------------------------------------------------------------------

func _take_polaroid(caption: String) -> void:
	# Hide the HUD for one frame so the photo shows only Bloopie and his room.
	_hud.visible = false
	await RenderingServer.frame_post_draw
	MemoryManager.capture(get_viewport(), _bloopie.call("get_canvas_center"), POLAROID_SIDE * _camera.zoom.x, caption)
	_hud.visible = true
	_bloopie.call("play_sound", "shutter")
	_flash.visible = true
	_flash.modulate.a = 1.0
	var fade := create_tween()
	fade.tween_property(_flash, "modulate:a", 0.0, 0.55)
	fade.tween_callback(func() -> void: _flash.visible = false)
	_show_toast("Новый снимок в альбоме")


func _open_album() -> void:
	_set_care_open(false)
	_paywall.visible = false
	_album.call("open")


# --- Care -----------------------------------------------------------------------------------------

func _toggle_care() -> void:
	if not _care_open:
		_set_chat_open(false)
		if _bloopie.get("is_sleeping"):
			_set_sleeping(false)
	_set_care_open(not _care_open)


func _on_care_action(action: String) -> void:
	match action:
		"cocoa":
			GameState.apply_deltas(6, 4, GameState.care_affection("cocoa", 3))
			_bloopie.call("say", _pick(CARE_LINES.cocoa), "happy")
		"tart":
			GameState.apply_deltas(8, 8, GameState.care_affection("tart", 3))
			_bloopie.call("say", _pick(CARE_LINES.tart), "excited")
		"wash":
			GameState.apply_deltas(5, 0, GameState.care_affection("wash", 3))
			_bloopie.call("start_bubbles")
			_bloopie.call("say", _pick(CARE_LINES.wash), "laugh")
		"theme":
			var theme_id := GameState.cycle_theme()
			_bloopie.call("show_emotion", "proud", 2.0)
			_show_toast("Тема: %s" % GameState.THEMES[theme_id].title)
		"hat":
			var before := GameState.hat_id
			var hat_id := GameState.cycle_hat()
			if hat_id == before:
				_show_toast("Новые шапочки откроются с ростом дружбы")
			else:
				_bloopie.call("show_emotion", "shy" if hat_id != "none" else "happy", 2.0)
				_show_toast(GameState.HATS[hat_id].title)
		"weather":
			var mode := TimeWeatherSystem.cycle_window_mode()
			_show_toast("За окном: %s" % TimeWeatherSystem.MODE_TITLES[mode].to_lower())


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
	_minigame.call("open")


func _on_minigame_closed() -> void:
	_set_dock_visible(true)
	_bloopie.call("stop_singing")


func _on_minigame_finished(accuracy_percent: int) -> void:
	_set_dock_visible(true)
	_bloopie.call("stop_singing")
	GameState.add_vocal_result(accuracy_percent)
	_send_message("Мы спели вместе!", {
		"type": "vocal_result",
		"accuracy_percent": accuracy_percent,
		"vocal_level": GameState.vocal_level,
	})


# --- Level, trial and cryo-capsule ----------------------------------------------------------------

func _on_level_changed(level: int) -> void:
	_refresh_top_bar()
	_show_toast("Дружба выросла: Lv.%d" % level)


func _on_frozen_changed(frozen: bool) -> void:
	_set_hud_enabled(not frozen and GameState.hatched)
	_environment.call("set_sleeping", frozen)
	if frozen:
		_minigame.visible = false
		_set_dock_visible(true)
	else:
		_paywall.visible = false
		_btn_sleep.text = "Сон"
		if GameState.hatched and _greeted:
			_bloopie.call("say", "Я проснулся! Как же я по тебе соскучился.", "love")


func _show_paywall() -> void:
	_paywall_body.text = "Пробные 14 дней закончились. Блупи сладко спит в крио-капсуле и ждёт тебя.\nАльбом воспоминаний всегда открыт."
	_paywall.visible = true


func _on_purchase_unavailable() -> void:
	_paywall_body.text = "Покупка Cozy Pass пока недоступна в этой сборке. Блупи подождёт, а альбом остаётся с тобой."
