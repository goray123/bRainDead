class_name RainSound
extends Node
## Small original synthesized sounds; no downloaded assets or gameplay RNG.

var ambience: AudioStreamPlayer
var effect: AudioStreamPlayer
var muted: bool = false


func _ready() -> void:
	ambience = AudioStreamPlayer.new()
	ambience.volume_db = -27.0
	add_child(ambience)
	effect = AudioStreamPlayer.new()
	effect.volume_db = -16.0
	add_child(effect)
	if DisplayServer.get_name() == "headless":
		# Physics/CI runs do not need audio playback or an audio mixing thread.
		muted = true
		return
	ambience.stream = _rain_loop()
	ambience.play()


func toggle() -> void:
	muted = not muted
	ambience.volume_db = -80.0 if muted else -27.0
	effect.volume_db = -80.0 if muted else -16.0


func _exit_tree() -> void:
	# Explicitly release looping playback before AudioServer shuts down.
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream = null
	if is_instance_valid(effect):
		effect.stop()
		effect.stream = null


func play_cue(kind: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var notes: Array[float] = [440.0, 660.0]
	if kind == "fail":
		notes = [330.0, 261.63, 196.0]
	elif kind == "clear":
		notes = [392.0, 493.88, 587.33, 783.99]
	elif kind == "trip":
		notes = [140.0, 87.31]
	var sample_rate: int = 22050
	var note_length: int = 2400
	var bytes := PackedByteArray()
	bytes.resize(notes.size() * note_length * 2)
	for n in range(notes.size()):
		for i in range(note_length):
			var envelope: float = sin(PI * float(i) / float(note_length)) * exp(-float(i) / 1200.0)
			var value: float = sin(TAU * notes[n] * float(i) / sample_rate) * envelope * 0.5
			bytes.encode_s16((n * note_length + i) * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	effect.stream = stream
	effect.play()


func _rain_loop() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var count: int = sample_rate * 2
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(sample_rate)
		var value: float = sin(TAU * 2317.0 * t + 4.0 * sin(TAU * 719.0 * t))
		value += sin(TAU * 3719.0 * t + 3.0 * sin(TAU * 1229.0 * t)) * 0.6
		value += sin(TAU * 5711.0 * t + 2.0 * sin(TAU * 1709.0 * t)) * 0.3
		bytes.encode_s16(i * 2, int(value * 6000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream
