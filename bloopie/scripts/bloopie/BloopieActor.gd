extends Area2D
## Bloopie himself: touch physics (tap = squash & stretch, long swipe = petting),
## body animation loops, emotions, speech bubble with procedural voice,
## growth stages and the cryo-capsule sleep.

signal tapped
signal petted
signal frozen_tapped
signal woke_up
signal speech_finished

const BODY_RADIUS := 195.0
const BODY_BOTTOM := 190.0
const PET_SWIPE_LENGTH := 140.0
const TAP_MAX_TRAVEL := 24.0
const PET_VIBRATION_MS := 35
const TYPE_SPEED := 30.0
const IDLE_ACTION_MIN := 18.0
const IDLE_ACTION_MAX := 32.0
const BUBBLE_WIDTH := 760.0
const BUBBLE_BOTTOM := -410.0

## Shared render state read by every BloopiePart layer.
var state := {
	"palette": {},
	"theme_id": "original",
	"hat": "none",
	"stage": 1,
	"expression": "happy",
	"blink": 0.0,
	"look": Vector2.ZERO,
	"talk": 0.0,
	"sleeping": false,
	"bubbles": 0.0,
	"time": 0.0,
}

var is_sleeping := false
var is_busy_animating := false

var _resting_expression := "happy"
var _expression_left := 0.0
var _squash := Vector2.ONE
var _anim_offset := Vector2.ZERO
var _anim_tilt := 0.0
var _tilt := 0.0
var _curl_angle := 0.0
var _curl_velocity := 0.0
var _touch_on_body := false
var _touch_travel := 0.0
var _swipe := 0.0
var _typing := false
var _typed := 0.0
var _bubble_hold := 0.0
var _idle_clock := 0.0
var _body_tween: Tween
var _bubble_tween: Tween
var _sfx := {}
var _rng := RandomNumberGenerator.new()

@onready var _visual: Node2D = $VisualRoot
@onready var _face: Node2D = $VisualRoot/FaceController
@onready var _curl: Node2D = $VisualRoot/TopCurl
@onready var _hat: Node2D = $VisualRoot/HatSlot
@onready var _decor: Node2D = $VisualRoot/EmoteDecor
@onready var _ball: Node2D = $PlayBall
@onready var _capsule: Node2D = $FrozenCapsule
@onready var _cryo_light: PointLight2D = $FrozenCapsule/CryoLight
@onready var _hearts: GPUParticles2D = $HeartParticles
@onready var _sfx_player: AudioStreamPlayer2D = $SFXPlayer
@onready var _voice: AudioStreamPlayer2D = $BlipPlayer
@onready var _bubble: PanelContainer = $SpeechBubble
@onready var _reply: Label = $SpeechBubble/MarginContainer/ReplyLabel


func _ready() -> void:
	_rng.randomize()
	_idle_clock = _rng.randf_range(IDLE_ACTION_MIN, IDLE_ACTION_MAX)
	state.palette = GameState.get_palette()
	state.theme_id = GameState.theme_id
	state.hat = GameState.hat_id
	state.stage = GameState.get_growth_stage()
	for layer: Node in [$VisualRoot/DropShadow, $VisualRoot/BackTufts, $VisualRoot/BodyBase,
			_curl, $VisualRoot/FrontPaws, _hat, _decor, _ball, _capsule]:
		layer.set("state", state)
	_face.call("bind", state)
	_build_sounds()
	_build_hearts()
	_build_cryo_light()
	_style_bubble()
	_apply_hat()
	_bubble.visible = false
	_ball.visible = false
	GameState.theme_changed.connect(_on_theme_changed)
	GameState.hat_changed.connect(_on_hat_changed)
	GameState.level_changed.connect(_on_level_changed)
	GameState.frozen_changed.connect(_on_frozen_changed)
	_on_frozen_changed(GameState.is_frozen)


# --- Public API ----------------------------------------------------------------------------

## Shows `emotion` for `seconds`, then returns to the resting expression.
func show_emotion(emotion: String, seconds: float = 3.0) -> void:
	if is_sleeping:
		return
	_set_expression(emotion if GameState.EMOTIONS.has(emotion) else "happy")
	_expression_left = seconds


## Types `text` into the speech bubble with voice blips on every second letter.
func say(text: String, emotion: String = "happy") -> void:
	if GameState.is_frozen:
		return
	if is_sleeping:
		wake_up()
	show_emotion(emotion, maxf(4.0, text.length() / TYPE_SPEED + 3.0))
	_open_bubble(text)
	_typing = true
	_typed = 0.0
	_reply.visible_characters = 0
	_bubble_hold = maxf(2.8, text.length() * 0.07)


func show_thinking() -> void:
	if GameState.is_frozen:
		return
	show_emotion("curious", 20.0)
	_open_bubble("...")
	_typing = false
	_reply.visible_characters = -1
	_bubble_hold = 20.0


func start_bubbles() -> void:
	state.bubbles = 3.2


func fall_asleep() -> void:
	if is_sleeping:
		return
	_stop_body_tween()
	is_sleeping = true
	state.sleeping = true
	_hide_bubble()
	_redraw_all()
	_body_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(self, "_squash", Vector2(1.1, 0.84), 0.9)


func wake_up() -> void:
	if not is_sleeping or GameState.is_frozen:
		return
	is_sleeping = false
	state.sleeping = false
	_redraw_all()
	_stop_body_tween()
	_body_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(self, "_squash", Vector2.ONE, 0.5)
	show_emotion("surprised", 1.2)
	woke_up.emit()


## Plays one of the body loops: "walk", "jump" or "play". "idle" and "lie_down"
## are the resting poses driven by fall_asleep()/wake_up().
func play_body_animation(animation: String) -> void:
	if is_sleeping or GameState.is_frozen or is_busy_animating:
		return
	match animation:
		"walk":
			_animate_walk()
		"jump":
			_animate_jump()
		"play":
			_animate_play()


func start_singing(frequency_hz: float) -> void:
	_voice.call("sing", frequency_hz)
	state.talk = 0.9
	_face.call("redraw")


func stop_singing() -> void:
	_voice.call("stop_singing")


func play_sound(id: String) -> void:
	if _sfx.has(id):
		_sfx_player.stream = _sfx[id]
		_sfx_player.play()


## Centre of the body in canvas (screen) coordinates, for the polaroid camera.
func get_canvas_center() -> Vector2:
	return get_global_transform_with_canvas().origin


# --- Frame update ------------------------------------------------------------------------

func _process(delta: float) -> void:
	state.time += delta
	_update_expression(delta)
	_update_speech(delta)
	_update_pose(delta)
	_update_idle_actions(delta)
	if state.bubbles > 0.0:
		state.bubbles = maxf(0.0, state.bubbles - delta)
	_decor.queue_redraw()
	if _capsule.visible:
		_capsule.queue_redraw()


func _update_expression(delta: float) -> void:
	if _expression_left > 0.0:
		_expression_left -= delta
		if _expression_left <= 0.0:
			_set_expression(_resting_expression)
	var resting := "sleepy" if GameState.energy < 20 else "happy"
	if resting != _resting_expression:
		_resting_expression = resting
		if _expression_left <= 0.0:
			_set_expression(resting)


func _update_speech(delta: float) -> void:
	var talk_target := 0.0
	if _typing:
		var before := int(_typed)
		_typed += delta * TYPE_SPEED
		var total := _reply.text.length()
		var now := mini(int(_typed), total)
		_reply.visible_characters = now
		if now > before:
			var character := _reply.text.substr(now - 1, 1)
			if now % 2 == 0 and character != " ":
				_voice.call("blip", _rng.randf_range(0.92, 1.1))
		talk_target = absf(sin(state.time * 17.0)) * 0.75
		if now >= total:
			_typing = false
			speech_finished.emit()
	elif _bubble.visible and _bubble_hold > 0.0:
		_bubble_hold -= delta
		if _bubble_hold <= 0.0:
			_hide_bubble()
	if _voice.call("is_singing"):
		talk_target = 0.7 + 0.2 * sin(state.time * 6.0)
	if not is_equal_approx(state.talk, talk_target):
		state.talk = move_toward(state.talk, talk_target, delta * 9.0)
		_face.call("redraw")


func _update_pose(delta: float) -> void:
	var growth := GameState.get_growth_scale()
	var breath_speed := 1.1 if is_sleeping else 2.0
	var breath := sin(state.time * breath_speed) * (0.022 if is_sleeping else 0.012)
	var scale_now := Vector2(_squash.x * (1.0 - breath), _squash.y * (1.0 + breath)) * growth
	_visual.scale = scale_now
	# Keep the feet planted on the cushion whatever the squash or growth stage.
	_visual.position = _anim_offset + Vector2(0, BODY_BOTTOM - BODY_BOTTOM * scale_now.y)
	var tilt_target := deg_to_rad(7.0) if state.expression in ["curious", "confused"] and not is_sleeping else 0.0
	_tilt = lerpf(_tilt, tilt_target, minf(1.0, delta * 6.0))
	_visual.rotation = _tilt + _anim_tilt
	# Secondary motion of the curl: a damped spring kicked by taps, pets and jumps.
	_curl_velocity += (-_curl_angle * 90.0 - _curl_velocity * 7.0) * delta
	_curl_angle += _curl_velocity * delta
	_curl.rotation = _curl_angle + sin(state.time * 1.7) * 0.035


func _update_idle_actions(delta: float) -> void:
	if is_sleeping or GameState.is_frozen or is_busy_animating or _bubble.visible or _touch_on_body:
		return
	_idle_clock -= delta
	if _idle_clock > 0.0:
		return
	_idle_clock = _rng.randf_range(IDLE_ACTION_MIN, IDLE_ACTION_MAX)
	var actions: Array[String] = ["walk", "jump", "play"]
	play_body_animation(actions[_rng.randi() % actions.size()])


# --- Touch ----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var world := _to_world(event.position)
		if event.pressed:
			if GameState.is_frozen:
				frozen_tapped.emit()
				return
			_touch_on_body = _is_on_body(world)
			_touch_travel = 0.0
			_swipe = 0.0
			_look_at(world)
		else:
			if _touch_on_body and _touch_travel <= TAP_MAX_TRAVEL:
				_on_tap()
			_touch_on_body = false
	elif event is InputEventScreenDrag:
		if GameState.is_frozen:
			return
		var world := _to_world(event.position)
		_look_at(world)
		_touch_travel += event.relative.length()
		if _touch_on_body and _is_on_body(world):
			_swipe += event.relative.length()
			if _swipe >= PET_SWIPE_LENGTH:
				_swipe = 0.0
				_on_pet()
	elif event is InputEventMouseMotion and not GameState.is_frozen:
		_look_at(_to_world(event.position))


func _to_world(canvas_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * canvas_position


func _is_on_body(world: Vector2) -> bool:
	return world.distance_to(global_position) <= BODY_RADIUS * GameState.get_growth_scale() + 20.0


func _look_at(world: Vector2) -> void:
	_face.call("look_at_pointer", (world - global_position) / 420.0)


func _on_tap() -> void:
	if is_sleeping:
		wake_up()
		return
	_idle_clock = _rng.randf_range(IDLE_ACTION_MIN, IDLE_ACTION_MAX)
	_boop(Vector2(1.14, 0.86))
	_curl_velocity += _rng.randf_range(-1.0, 1.0) * 5.0 + 3.0
	play_sound("pop")
	if _expression_left <= 0.0:
		show_emotion(["happy", "surprised", "laugh"][_rng.randi() % 3], 1.4)
	GameState.apply_deltas(1, 0, 0)
	tapped.emit()


func _on_pet() -> void:
	if is_sleeping:
		# Stroking a sleeping Bloopie is soothing and does not wake him.
		play_sound("purr")
		return
	_idle_clock = _rng.randf_range(IDLE_ACTION_MIN, IDLE_ACTION_MAX)
	Input.vibrate_handheld(PET_VIBRATION_MS)
	_hearts.restart()
	_hearts.emitting = true
	_boop(Vector2(1.07, 0.94))
	_curl_velocity += 4.0
	play_sound("purr")
	show_emotion("love", 2.6)
	GameState.apply_deltas(3, 0, GameState.care_affection("pet", 2))
	petted.emit()


# --- Body animations ------------------------------------------------------------------------

func _boop(squash: Vector2) -> void:
	if is_busy_animating:
		return
	_stop_body_tween()
	_body_tween = create_tween()
	_body_tween.tween_property(self, "_squash", squash, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(self, "_squash", Vector2.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _begin_animation() -> Tween:
	_stop_body_tween()
	is_busy_animating = true
	_body_tween = create_tween()
	_body_tween.finished.connect(_end_animation)
	return _body_tween


func _end_animation() -> void:
	is_busy_animating = false
	_squash = Vector2.ONE
	_anim_offset = Vector2.ZERO
	_anim_tilt = 0.0
	_ball.visible = false


func _stop_body_tween() -> void:
	if _body_tween != null and _body_tween.is_valid():
		_body_tween.kill()
	if is_busy_animating:
		_end_animation()


func _animate_walk() -> void:
	var tween := _begin_animation()
	tween.tween_method(_walk_step, 0.0, 1.0, 3.2)


## One full stroll: left, right and back to the middle of the cushion, waddling.
func _walk_step(t: float) -> void:
	_anim_offset = Vector2(sin(t * TAU) * -78.0, -absf(sin(t * TAU * 4.0)) * 10.0)
	_anim_tilt = sin(t * TAU * 4.0) * 0.07 * sin(t * PI)


func _animate_jump() -> void:
	var tween := _begin_animation()
	show_emotion("excited", 1.6)
	tween.tween_property(self, "_squash", Vector2(1.18, 0.8), 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: _curl_velocity -= 7.0)
	tween.tween_property(self, "_squash", Vector2(0.88, 1.14), 0.1)
	tween.parallel().tween_property(self, "_anim_offset", Vector2(0, -170), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_anim_offset", Vector2.ZERO, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "_squash", Vector2.ONE, 0.26)
	tween.tween_callback(func() -> void:
		play_sound("pop")
		_curl_velocity += 8.0)
	tween.tween_property(self, "_squash", Vector2(1.2, 0.8), 0.08)
	tween.tween_property(self, "_squash", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _animate_play() -> void:
	var tween := _begin_animation()
	show_emotion("excited", 3.4)
	_ball.visible = true
	_ball.position = Vector2(250, BODY_BOTTOM - 40.0)
	tween.tween_method(_play_step, 0.0, 1.0, 3.4)


## The pink ball bounces three times from side to side; Bloopie hops after it.
func _play_step(t: float) -> void:
	var bounce := absf(sin(t * PI * 3.0))
	_ball.position = Vector2(cos(t * PI * 3.0) * 250.0, BODY_BOTTOM - 40.0 - bounce * 230.0)
	_ball.rotation = t * TAU * 2.0
	_anim_offset = Vector2(0, -absf(sin(t * PI * 6.0)) * 26.0)
	_anim_tilt = cos(t * PI * 3.0) * 0.06
	_squash = Vector2(1.0 + 0.04 * sin(t * PI * 6.0), 1.0 - 0.04 * sin(t * PI * 6.0))


# --- Speech bubble --------------------------------------------------------------------------

func _open_bubble(text: String) -> void:
	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()
	_reply.text = text
	_bubble.visible = true
	_bubble.modulate.a = 1.0
	_bubble.size = Vector2(BUBBLE_WIDTH, 0)
	_bubble.size = _bubble.get_combined_minimum_size()
	_bubble.position = Vector2(-_bubble.size.x * 0.5, BUBBLE_BOTTOM - _bubble.size.y)
	_bubble.pivot_offset = Vector2(_bubble.size.x * 0.5, _bubble.size.y)
	_bubble.scale = Vector2(0.85, 0.85)
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_bubble() -> void:
	if not _bubble.visible:
		return
	_typing = false
	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, "modulate:a", 0.0, 0.25)
	_bubble_tween.tween_callback(func() -> void: _bubble.visible = false)


func _style_bubble() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#FFFDF9")
	box.set_corner_radius_all(44)
	box.shadow_color = Color(0.05, 0.04, 0.14, 0.35)
	box.shadow_size = 22
	box.shadow_offset = Vector2(0, 10)
	box.anti_aliasing_size = 1.5
	_bubble.add_theme_stylebox_override("panel", box)
	_reply.add_theme_color_override("font_color", BloopieArt.INK)
	_reply.add_theme_font_size_override("font_size", 40)
	_reply.custom_minimum_size.x = BUBBLE_WIDTH - 88.0


# --- State changes ---------------------------------------------------------------------------

func _set_expression(expression: String) -> void:
	if state.expression == expression:
		return
	state.expression = expression
	_face.call("redraw")


func _redraw_all() -> void:
	for layer: Node in _visual.get_children():
		if layer is CanvasItem:
			(layer as CanvasItem).queue_redraw()
	_face.call("redraw")


func _apply_hat() -> void:
	_hat.queue_redraw()
	# The wizard hat covers the curl; hoods let it poke through on top.
	_curl.visible = state.hat != "wizard"
	_curl.z_index = 1 if state.hat in ["cosy", "cat", "frog"] else 0


func _on_theme_changed(theme_id: String) -> void:
	state.palette = GameState.get_palette()
	state.theme_id = theme_id
	_redraw_all()
	_boop(Vector2(1.1, 0.9))


func _on_hat_changed(hat_id: String) -> void:
	state.hat = hat_id
	_apply_hat()
	_boop(Vector2(0.94, 1.08))


func _on_level_changed(_level: int) -> void:
	state.stage = GameState.get_growth_stage()
	_redraw_all()
	play_sound("chime")
	show_emotion("proud", 4.0)


func _on_frozen_changed(frozen: bool) -> void:
	_capsule.visible = frozen
	_cryo_light.enabled = frozen
	if frozen:
		fall_asleep()
	elif is_sleeping:
		wake_up()


# --- Generated resources ----------------------------------------------------------------------

func _build_sounds() -> void:
	_sfx = {
		"pop": ProcAudio.tone(540.0, 300.0, 0.09, 0.5),
		"purr": ProcAudio.tone(96.0, 118.0, 0.7, 0.6, 22.0, 0.08),
		"shutter": ProcAudio.tone(1800.0, 400.0, 0.07, 0.55, 0.0, 0.7),
		"chime": ProcAudio.chime(659.25, 987.77),
	}


func _build_hearts() -> void:
	var size := 48
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (x + 0.5) / size * 2.6 - 1.3
			var v := 1.15 - (y + 0.5) / size * 2.6
			var f := pow(u * u + v * v - 1.0, 3.0) - u * u * v * v * v
			if f <= 0.0:
				image.set_pixel(x, y, Color("#FF7A9C"))
	_hearts.texture = ImageTexture.create_from_image(image)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 120.0
	process.direction = Vector3(0, -1, 0)
	process.spread = 38.0
	process.initial_velocity_min = 170.0
	process.initial_velocity_max = 300.0
	process.gravity = Vector3(0, -70, 0)
	process.scale_min = 0.7
	process.scale_max = 1.5
	process.color_ramp = ramp
	_hearts.process_material = process
	_hearts.amount = 12
	_hearts.lifetime = 1.3
	_hearts.one_shot = true
	_hearts.explosiveness = 0.8
	_hearts.emitting = false


func _build_cryo_light() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var glow := GradientTexture2D.new()
	glow.gradient = gradient
	glow.width = 256
	glow.height = 256
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	_cryo_light.texture = glow
	_cryo_light.texture_scale = 3.4
	_cryo_light.color = Color(0.5, 0.82, 1.0)
	_cryo_light.energy = 0.55
