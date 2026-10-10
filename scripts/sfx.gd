extends Node
## Tiny synthesized sound kit, so the game ships no audio files: spin ticks,
## a taiko "don", hand claps for the chant, a shamisen-ish fanfare, a whoosh
## and a sake-cup clink.

const RATE := 22050
# yo-scale run (D E G A B D) for the fanfare
const FANFARE_NOTES := [587.33, 659.25, 783.99, 880.0, 987.77, 1174.66]
const FANFARE_GAP := 0.07

var _tick: AudioStreamWAV
var _don: AudioStreamWAV
var _fanfare: AudioStreamWAV
var _whoosh: AudioStreamWAV
var _clink: AudioStreamWAV
var _clap: AudioStreamWAV
var enabled := true
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_tick = _make(0.035, func(t: float) -> float: return sin(TAU * 1700.0 * t) * exp(-t * 120.0))
	_don = _make(0.7, _don_sample)
	_fanfare = _make(FANFARE_GAP * (FANFARE_NOTES.size() - 1) + 0.7, _fanfare_sample)
	_whoosh = _make(0.45, func(t: float) -> float: return randf_range(-1.0, 1.0) * sin(PI * t / 0.45) * 0.45)
	_clink = _make(0.5, _clink_sample)
	_clap = _make(0.12, _clap_sample)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func tick(speed: float) -> void:
	_play(_tick, 0.8 + minf(speed / 40.0, 0.5) + randf_range(-0.05, 0.05), -6.0)


func click() -> void:
	_play(_tick, 0.6, -4.0)


func don() -> void:
	_play(_don, 1.0, 0.0)


func fanfare() -> void:
	_play(_fanfare, 1.0, -4.0)


func whoosh() -> void:
	_play(_whoosh, 1.0, -8.0)


func clap() -> void:
	_play(_clap, randf_range(0.9, 1.1), -5.0)


func beat_don() -> void:
	_play(_don, 1.35, -11.0)


func roll() -> void:
	_play(_tick, 1.5, -3.0)


func thud() -> void:
	_play(_don, 0.75, -2.0)


func clink() -> void:
	_play(_clink, randf_range(0.95, 1.05), -3.0)


func _play(stream: AudioStreamWAV, pitch: float, volume_db: float) -> void:
	if not enabled:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _make(seconds: float, sample: Callable) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: float = sample.call(float(i) / RATE)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _don_sample(t: float) -> float:
	# pitch drops from ~145 Hz to 55 Hz; phase is the integral of that sweep
	var phase := TAU * (55.0 * t + 5.0 * (1.0 - exp(-t * 18.0)))
	var body := sin(phase) * exp(-t * 5.0)
	var slap := randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.5
	return (body + slap) * 0.9


func _clap_sample(t: float) -> float:
	# two quick noise bursts, like a pair of hands slightly out of sync
	var env := exp(-t * 70.0) + 0.6 * exp(-maxf(t - 0.012, 0.0) * 70.0) * float(t > 0.012)
	return randf_range(-1.0, 1.0) * env * 0.6


func _clink_sample(t: float) -> float:
	return (sin(TAU * 2637.0 * t) + 0.6 * sin(TAU * 3951.0 * t)) * exp(-t * 12.0) * 0.45


func _fanfare_sample(t: float) -> float:
	var v := 0.0
	for i in FANFARE_NOTES.size():
		var local := t - i * FANFARE_GAP
		if local < 0.0:
			break
		var f: float = FANFARE_NOTES[i]
		var decay := 6.0 if i == FANFARE_NOTES.size() - 1 else 14.0
		var pluck := 0.0
		for k in range(1, 5):
			pluck += sin(TAU * f * k * local) / k
		v += pluck * exp(-local * decay) * 0.3
	return v
