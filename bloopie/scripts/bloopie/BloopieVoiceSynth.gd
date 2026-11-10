extends AudioStreamPlayer2D
## Procedural voice: no speech samples ship with the game. Soft sine "blips"
## (480 Hz -> 660 Hz, 65 ms) accompany the typewriter, and a continuous sung
## tone follows the vocal mini-game.

const MIX_RATE := 22050.0
const BLIP_FROM_HZ := 480.0
const BLIP_TO_HZ := 660.0
const BLIP_SECONDS := 0.065

var _playback: AudioStreamGeneratorPlayback
var _blip_total := int(BLIP_SECONDS * MIX_RATE)
var _blip_left := 0
var _blip_pitch := 1.0
var _blip_phase := 0.0
var _sing_target_hz := 0.0
var _sing_hz := 440.0
var _sing_gain := 0.0
var _sing_phase := 0.0
var _vibrato_phase := 0.0


func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.08
	stream = generator
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func blip(pitch: float = 1.0) -> void:
	_blip_left = _blip_total
	_blip_pitch = pitch
	_blip_phase = 0.0


func sing(frequency_hz: float) -> void:
	if _sing_target_hz <= 0.0 and _sing_gain < 0.01:
		_sing_hz = frequency_hz
	_sing_target_hz = frequency_hz


func stop_singing() -> void:
	_sing_target_hz = 0.0


func _process(_delta: float) -> void:
	if _playback == null:
		return
	if _blip_left <= 0 and _sing_target_hz <= 0.0 and _sing_gain < 0.001:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	var gain_target := 1.0 if _sing_target_hz > 0.0 else 0.0
	for i in frames:
		var sample := 0.0
		if _blip_left > 0:
			var t := 1.0 - float(_blip_left) / _blip_total
			_blip_phase += TAU * lerpf(BLIP_FROM_HZ, BLIP_TO_HZ, t) * _blip_pitch / MIX_RATE
			sample += sin(_blip_phase) * sin(PI * t) * 0.32
			_blip_left -= 1
		_sing_gain += (gain_target - _sing_gain) * 0.0012
		if _sing_gain > 0.001:
			if _sing_target_hz > 0.0:
				_sing_hz += (_sing_target_hz - _sing_hz) * 0.0015
			_vibrato_phase += TAU * 5.5 / MIX_RATE
			_sing_phase += TAU * _sing_hz * (1.0 + 0.008 * sin(_vibrato_phase)) / MIX_RATE
			sample += (sin(_sing_phase) + 0.28 * sin(_sing_phase * 2.0) + 0.1 * sin(_sing_phase * 3.0)) * _sing_gain * 0.2
		buffer[i] = Vector2(sample, sample)
	_blip_phase = fmod(_blip_phase, TAU)
	_sing_phase = fmod(_sing_phase, TAU)
	_vibrato_phase = fmod(_vibrato_phase, TAU)
	_playback.push_buffer(buffer)


func is_singing() -> bool:
	return _sing_target_hz > 0.0
