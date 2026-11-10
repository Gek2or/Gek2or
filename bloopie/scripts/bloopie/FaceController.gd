extends Node2D
## Owns Bloopie's face: expression, blinking and the parallax look that makes the
## face follow the player's finger by up to LOOK_RANGE pixels.

const LOOK_RANGE := 12.0
const BLINK_INTERVAL := 3.5
const BLINK_DURATION := 0.13
const LOOK_RELEASE_DELAY := 2.5

var state := {}

var _look_target := Vector2.ZERO
var _look_idle := 0.0
var _blink_clock := BLINK_INTERVAL
var _blink_left := 0.0

@onready var _eyes: Node2D = $EyesSprite
@onready var _blush: Node2D = $BlushSprite
@onready var _mouth: Node2D = $MouthTeeth


func bind(shared_state: Dictionary) -> void:
	state = shared_state
	for layer: Node2D in [_eyes, _blush, _mouth]:
		layer.set("state", state)
	redraw()


func redraw() -> void:
	_eyes.queue_redraw()
	_blush.queue_redraw()
	_mouth.queue_redraw()


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
	var next_look := look.lerp(_look_target, minf(1.0, delta * 9.0))
	if not next_look.is_equal_approx(look):
		state.look = next_look
		position = next_look * LOOK_RANGE
		_eyes.queue_redraw()

	_blink_clock -= delta
	if _blink_clock <= 0.0:
		_blink_clock = BLINK_INTERVAL
		_blink_left = BLINK_DURATION
	var blink := 1.0 if _blink_left > 0.0 else 0.0
	_blink_left = maxf(0.0, _blink_left - delta)
	if blink != state.blink:
		state.blink = blink
		_eyes.queue_redraw()
