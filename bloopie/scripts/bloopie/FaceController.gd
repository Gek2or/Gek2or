extends Node2D
## Owns Bloopie's face. The painted sprite already smiles with open eyes. For
## every other expression this node first looks for a fully painted face in the
## manifest (PaintedArt "expressions"); when there is none it lays the patches
## cut from the mock-ups over the sprite (laughing face, singing mouth, plush
## over the eyes, brows or mouth) and lets the ink layer draw the rest. It also
## blinks and tracks where the player's finger is.

const BLINK_INTERVAL := 3.5
const BLINK_DURATION := 0.13
const LOOK_RELEASE_DELAY := 2.5
const TALK_OPEN := 0.4
const INK_BROWS: Array[String] = ["sad", "angry", "surprised", "curious", "confused"]
const INK_MOUTHS: Array[String] = ["sad", "angry", "surprised", "confused"]

const EYES_BLANK := preload("res://art/painted/face_eyes_blank.png")
const FACE_LAUGH := preload("res://art/painted/face_laugh.png")
const MOUTH_BLANK := preload("res://art/painted/face_mouth_blank.png")
const MOUTH_SING := preload("res://art/painted/face_sing.png")

var state := {}

var _look_target := Vector2.ZERO
var _look_idle := 0.0
var _blink_clock := BLINK_INTERVAL
var _blink_left := 0.0
var _mouth_open := false
var _painted: Sprite2D

@onready var _eyes: AnimatedSprite2D = $EyesSprite
@onready var _brows: Sprite2D = $BrowsCover
@onready var _mouth: AnimatedSprite2D = $MouthTeeth
@onready var _ink: Node2D = $FaceInk


func _ready() -> void:
	_eyes.sprite_frames = _frames({"blank": EYES_BLANK, "laugh": FACE_LAUGH})
	_mouth.sprite_frames = _frames({"blank": MOUTH_BLANK, "sing": MOUTH_SING})
	_eyes.visible = false
	_brows.visible = false
	_mouth.visible = false
	# Fully painted expressions sit under the patches, so the singing mouth
	# can still open on top of them while Bloopie talks.
	_painted = Sprite2D.new()
	_painted.name = "PaintedFace"
	_painted.centered = false
	_painted.material = _brows.material
	_painted.visible = false
	add_child(_painted)
	move_child(_painted, 0)


func bind(shared_state: Dictionary) -> void:
	state = shared_state
	_ink.set("state", state)
	redraw()


## Picks the patches that match the current expression, blink and speech.
func redraw() -> void:
	if state.is_empty():
		return
	var expression: String = "sleepy" if state.sleeping else state.expression
	_mouth_open = state.talk > TALK_OPEN
	if state.pose != "":
		# A painted pose brings its own face.
		for layer: Node2D in [_painted, _eyes, _brows, _mouth]:
			layer.visible = false
		state["painted_face"] = false
		_ink.queue_redraw()
		return
	var blinking: bool = state.blink > 0.5 and expression != "sleepy"
	var picture := PaintedArt.entry("expressions", "sleepy" if blinking else expression)
	state["painted_face"] = not picture.is_empty()
	_painted.visible = not picture.is_empty()
	if not picture.is_empty():
		_painted.texture = PaintedArt.texture(picture.file)
		PaintedArt.place(_painted, picture.box, get_parent().get_parent())
		_eyes.visible = false
		_brows.visible = false
		_mouth.visible = _mouth_open
		if _mouth_open:
			_mouth.animation = "sing"
		_ink.queue_redraw()
		return
	var laughing := expression in ["laugh", "love"]
	var closed: bool = state.blink > 0.5 or expression == "sleepy"
	_eyes.visible = laughing or closed
	if _eyes.visible:
		_eyes.animation = "laugh" if laughing else "blank"
	_brows.visible = not laughing and INK_BROWS.has(expression)
	var singing: bool = _mouth_open or expression == "excited"
	_mouth.visible = not laughing and (singing or INK_MOUTHS.has(expression))
	if _mouth.visible:
		_mouth.animation = "sing" if singing else "blank"
	_ink.queue_redraw()


## `direction` is the pointer offset from the face, normalised to -1..1 per axis.
func look_at_pointer(direction: Vector2) -> void:
	_look_target = direction.limit_length(1.0)
	_look_idle = 0.0


func _process(delta: float) -> void:
	if state.is_empty():
		return
	_look_idle += delta
	if _look_idle > LOOK_RELEASE_DELAY or state.sleeping:
		_look_target = Vector2.ZERO
	var look: Vector2 = state.look
	state.look = look.lerp(_look_target, minf(1.0, delta * 9.0))

	_blink_clock -= delta
	if _blink_clock <= 0.0:
		_blink_clock = BLINK_INTERVAL
		_blink_left = BLINK_DURATION
	var blink := 1.0 if _blink_left > 0.0 else 0.0
	_blink_left = maxf(0.0, _blink_left - delta)
	var mouth_open: bool = state.talk > TALK_OPEN
	if blink != state.blink or mouth_open != _mouth_open:
		state.blink = blink
		redraw()


func _frames(textures: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for animation: String in textures:
		frames.add_animation(animation)
		frames.add_frame(animation, textures[animation])
	frames.remove_animation("default")
	return frames
