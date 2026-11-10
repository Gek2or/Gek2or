class_name ProcAudio
extends RefCounted
## Tiny synthesizer for sound effects and ambience, so the build ships without
## audio files. Everything is 16-bit mono PCM.

const MIX_RATE := 22050


## Sine sweep from `from_hz` to `to_hz` with a smooth envelope. `tremolo_hz`
## adds a purr-like amplitude wobble, `noise` (0..1) mixes in white noise.
static func tone(from_hz: float, to_hz: float, seconds: float, volume: float = 0.5, tremolo_hz: float = 0.0, noise: float = 0.0) -> AudioStreamWAV:
	var count := int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += TAU * lerpf(from_hz, to_hz, t) / MIX_RATE
		var sample := sin(phase) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		var envelope := sin(PI * t)
		if tremolo_hz > 0.0:
			envelope *= 0.55 + 0.45 * sin(TAU * tremolo_hz * t * seconds)
		data.encode_s16(i * 2, int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0))
	return _wav(data, false)


## Two-note chime used for level-ups and saved memories.
static func chime(first_hz: float, second_hz: float) -> AudioStreamWAV:
	var count := int(0.5 * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / MIX_RATE
		var sample := sin(TAU * first_hz * t) * exp(-t * 7.0)
		if t > 0.14:
			sample += sin(TAU * second_hz * (t - 0.14)) * exp(-(t - 0.14) * 6.0)
		data.encode_s16(i * 2, int(clampf(sample * 0.35, -1.0, 1.0) * 32767.0))
	return _wav(data, false)


## Seamless loop of soft low-passed noise: rain on the window.
static func rain_loop(seconds: float = 3.0) -> AudioStreamWAV:
	var count := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	for i in count:
		low += (randf_range(-1.0, 1.0) - low) * 0.22
		samples[i] = low
	var fade := MIX_RATE / 4
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var sample := samples[i]
		if i < fade:
			# Cross-fade the head with the tail so the loop point is inaudible.
			var k := float(i) / fade
			sample = sample * k + samples[count - fade + i] * (1.0 - k)
		data.encode_s16(i * 2, int(clampf(sample * 0.9, -1.0, 1.0) * 32767.0))
	data.resize((count - fade) * 2)
	return _wav(data, true)


static func _wav(data: PackedByteArray, looped: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = data.size() / 2
	return wav
