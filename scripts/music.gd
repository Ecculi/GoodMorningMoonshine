extends Node
## Quiet background music, made in code at start (no music files): a slow,
## slightly melancholy street tune, and a livelier one inside the bar.
##
## It follows how drunk the character is:
## - drunk: the pitch sways and the tempo slips (pitch_scale wobbles, more
##   the drunker);
## - hungover (under the hangover limit): thin and tinny through a band-pass
##   filter, and quieter.
## Inside the bar the bar's own tune plays instead.

const RATE := 16000
const STREET_DB := -17.0
const BAR_DB := -12.0

var main
var _street: AudioStreamPlayer
var _bar: AudioStreamPlayer
var _bus := -1
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _slip := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 77
	_bus = AudioServer.bus_count
	AudioServer.add_bus(_bus)
	AudioServer.set_bus_name(_bus, "Music")
	AudioServer.set_bus_send(_bus, "Master")
	var bp := AudioEffectBandPassFilter.new()
	bp.cutoff_hz = 1400.0
	bp.resonance = 0.6
	AudioServer.add_bus_effect(_bus, bp)
	AudioServer.set_bus_effect_enabled(_bus, 0, false)
	_street = _player(_street_tune(), STREET_DB)


func _player(stream: AudioStreamWAV, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.bus = "Music"
	add_child(p)
	p.play()
	return p


func _process(delta: float) -> void:
	_t += delta
	var in_bar := GameState.modal == "shop" and main != null and main.shop_type == "bar"
	if in_bar and _bar == null:
		_bar = _player(_bar_tune(), -80.0)  # made the first time it's needed
	var hung := GameState.promille < GameState.PROMILLE_HANGOVER
	AudioServer.set_bus_effect_enabled(_bus, 0, hung)
	var street_db := STREET_DB - (6.0 if hung else 0.0) - (8.0 if GameState.over else 0.0)
	if GameState.modal == "shop" and not in_bar:
		street_db -= 8.0  # muffled inside a shop
	_street.volume_db = move_toward(_street.volume_db, -80.0 if in_bar else street_db, delta * 40.0)
	if _bar != null:
		_bar.volume_db = move_toward(_bar.volume_db, BAR_DB if in_bar else -80.0, delta * 40.0)
	# Drunk: the pitch sways (two slow waves) and the tempo slips now and
	# then (a short random dip that eases back).
	var drunk := clampf((GameState.promille - 0.8) / 2.2, 0.0, 1.0)
	_slip = move_toward(_slip, 0.0, delta * 0.15)
	if _rng.randf() < delta * 0.4 * drunk:
		_slip = -_rng.randf_range(0.02, 0.06) * drunk
	var sway := (sin(_t * 0.9) * 0.6 + sin(_t * 2.3) * 0.4) * 0.05 * drunk
	var pitch := clampf(1.0 + sway + _slip, 0.8, 1.2)
	_street.pitch_scale = pitch
	if _bar != null:
		_bar.pitch_scale = pitch


# --- The tunes ----------------------------------------------------------------

const A3 := 220.0


func _note(semi: float) -> float:
	return A3 * pow(2.0, semi / 12.0)


## Street: Am – F – C – G, two seconds each; soft pad chords, a plucked
## bass and a slow pentatonic melody.
func _street_tune() -> AudioStreamWAV:
	var bar := 2.0
	var chords := [[0, 3, 7], [-4, 0, 3], [3, 7, 10], [-2, 2, 5]]
	var bass := [-12, -16, -9, -14]
	var melody := [[0.0, 12], [0.5, 15], [1.0, 19], [2.0, 17], [2.75, 15], [4.0, 15], [4.5, 12], [5.0, 10],
		[6.0, 14], [6.5, 12], [7.0, 10]]
	var buf := PackedFloat32Array()
	buf.resize(int(bar * 4.0 * RATE))
	for i in 4:
		for s in chords[i]:
			_add(buf, i * bar, bar, _note(s), "pad", 0.07)
		_add(buf, i * bar, 0.6, _note(bass[i]), "pluck", 0.22)
		_add(buf, i * bar + 1.0, 0.6, _note(bass[i] + 7), "pluck", 0.14)
	for m in melody:
		_add(buf, m[0], 0.7, _note(m[1]), "bell", 0.12)
	return _wav(buf)


## Bar: a bouncier Am – Dm – E – Am, a beat on every quarter.
func _bar_tune() -> AudioStreamWAV:
	var beat := 0.25
	var chords := [[0, 3, 7], [5, 8, 12], [7, 11, 14], [0, 3, 7]]
	var bass := [-12, -7, -5, -12]
	var buf := PackedFloat32Array()
	buf.resize(int(beat * 32.0 * RATE))
	for i in 4:
		for b in 8:
			var t0 := (i * 8 + b) * beat
			if b % 2 == 0:
				_add(buf, t0, 0.15, 55.0, "kick", 0.5)
				_add(buf, t0, beat * 1.8, _note(bass[i] + (7 if b % 4 == 2 else 0)), "pluck", 0.2)
			else:
				for s in chords[i]:
					_add(buf, t0, 0.18, _note(s + 12), "pluck", 0.05)
	return _wav(buf)


## Adds one note to `buf`: starts at `t0`, lasts `dur` seconds.
func _add(buf: PackedFloat32Array, t0: float, dur: float, f: float, kind: String, amp: float) -> void:
	var i0 := int(t0 * RATE)
	var n := int(dur * RATE)
	for k in n:
		var i := i0 + k
		if i >= buf.size():
			i -= buf.size()  # wrap round: the loop has no seam
		var t := float(k) / RATE
		var v := 0.0
		match kind:
			"pad":
				var env := minf(t / 0.3, 1.0) * minf((dur - t) / 0.4, 1.0)
				v = sin(TAU * f * t) * env
			"pluck":
				v = (sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.0 * t)) * exp(-t * 6.0)
			"bell":
				v = (sin(TAU * f * t) + 0.25 * sin(TAU * f * 3.0 * t)) * exp(-t * 4.0) * minf(t / 0.01, 1.0)
			"kick":
				v = sin(TAU * (f + 90.0 * exp(-t * 30.0)) * t) * exp(-t * 18.0)
		buf[i] += v * amp


func _wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = buf.size()
	return w
