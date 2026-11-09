extends Node
## Sound effects, all made in code when the game starts (no sound files):
## short tones, sweeps and filtered noise shaped with envelopes.
##
## play(name, pos): `pos` = where in the world it happens (heard from the
## camera, quieter further away); Vector3.INF = a UI sound (found thing,
## achievement). World sounds pause while the world is frozen.

const RATE := 22050
const POOL_3D := 10
const POOL_2D := 4

var _streams := {}
var _pool3: Array = []
var _pool2: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1234
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 12.0
		p.max_distance = 60.0
		add_child(p)
		_pool3.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool2.append(p)
	_build()


## Plays sound `name` (see _build for the names).
func play(sound: String, pos := Vector3.INF, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	var player: Node = null
	var pool: Array = _pool2 if pos == Vector3.INF else _pool3
	for p in pool:
		if not p.playing:
			player = p
			break
	if player == null:
		player = pool[0]  # all busy: cut the oldest one short
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = pitch * _rng.randf_range(0.94, 1.06)
	if pos != Vector3.INF:
		player.global_position = pos
	player.stream_paused = false
	player.play()


func _process(_delta: float) -> void:
	# World sounds wait while time stands still (not on the death or day
	# cards, where the last sound may ring out).
	var frozen := GameState.world_dt <= 0.0 and not GameState.over
	for p in _pool3:
		if p.playing or p.stream_paused:
			p.stream_paused = frozen


# --- Synthesis --------------------------------------------------------------

func _build() -> void:
	_streams["punch"] = _make(0.16, func(t, n): return _thump(t, 110.0, 50.0, 0.12) * 0.9 + n * _env(t, 0.0, 0.03) * 0.5)
	_streams["hit"] = _make(0.25, func(t, n): return _thump(t, 80.0, 40.0, 0.2) + n * _env(t, 0.0, 0.06) * 0.6)
	_streams["glug"] = _make(0.42, _glug)
	_streams["break"] = _make(0.5, _break)
	_streams["bark"] = _make(0.38, _bark)
	_streams["whimper"] = _make(0.5, _whimper)
	_streams["gull"] = _make(0.55, _gull)
	_streams["brake"] = _make(0.7, _brake)
	_streams["bump"] = _make(0.3, func(t, n): return _thump(t, 70.0, 35.0, 0.25) + n * _env(t, 0.0, 0.1) * 0.7)
	_streams["bell"] = _make(0.6, func(t, _n): return (_ping(t, 3100.0, 0.25) + _ping(t - 0.15, 3100.0, 0.4)) * 0.5)
	_streams["horn"] = _make(0.35, func(t, n): return signf(sin(_phase("horn", 440.0))) * 0.25 * _env(t, 0.01, 0.33))
	_streams["fall"] = _make(0.35, func(t, n): return _thump(t, 75.0, 40.0, 0.22) + n * _env(t, 0.0, 0.25) * 0.35)
	_streams["found"] = _make(0.4, func(t, n): return _arp(t, [523.25, 659.25, 783.99], 0.09) * 0.45)
	_streams["achievement"] = _make(0.9, func(t, n): return _arp(t, [523.25, 659.25, 783.99, 1046.5], 0.12) * 0.45)
	_streams["splash"] = _make(0.8, func(t, n): return _lowpass("splash", n, 0.35) * _env(t, 0.01, 0.78) * 1.2)
	_streams["slurp"] = _make(0.5, func(t, n): return _lowpass("slurp", n, 0.05 + 0.3 * t) * _env(t, 0.05, 0.45) * 1.3)
	_streams["tear"] = _make(0.25, func(t, n): return n * (0.5 + 0.5 * signf(sin(t * 260.0))) * _env(t, 0.0, 0.24) * 0.6)
	_streams["cheer"] = _make(0.6, _cheer)


## Builds a mono 16-bit sound `length` seconds long from `gen(t, noise)`.
func _make(length: float, gen: Callable) -> AudioStreamWAV:
	_phases.clear()
	_lp.clear()
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = gen.call(t, _rng.randf_range(-1.0, 1.0))
		var s := int(clampf(v, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Attack/decay envelope: rises over `att` seconds, falls to 0 at att + dec.
func _env(t: float, att: float, dec: float) -> float:
	if t < 0.0:
		return 0.0
	if t < att:
		return t / att
	return clampf(1.0 - (t - att) / dec, 0.0, 1.0)


var _phases := {}
var _lp := {}


## A running oscillator phase (so sweeps don't click).
func _phase(key: String, freq: float) -> float:
	var p: float = _phases.get(key, 0.0) + TAU * freq / RATE
	_phases[key] = fmod(p, TAU)
	return p


## One-pole low-pass on noise (k 0..1: higher = brighter).
func _lowpass(key: String, x: float, k: float) -> float:
	var y: float = _lp.get(key, 0.0)
	y += (x - y) * clampf(k, 0.0, 1.0)
	_lp[key] = y
	return y


## A falling low sine: the body of a blow or a fall.
func _thump(t: float, f0: float, f1: float, dur: float) -> float:
	var f := lerpf(f0, f1, clampf(t / dur, 0.0, 1.0))
	return sin(_phase("thump", f)) * _env(t, 0.004, dur)


func _ping(t: float, f: float, dur: float) -> float:
	if t < 0.0:
		return 0.0
	return (sin(TAU * f * t) + 0.4 * sin(TAU * f * 1.5 * t)) * exp(-t * 6.0 / dur) * 0.6


## Notes one after another, each ringing on.
func _arp(t: float, notes: Array, step: float) -> float:
	var v := 0.0
	for i in notes.size():
		var tt := t - i * step
		if tt >= 0.0:
			v += sin(TAU * notes[i] * tt) * exp(-tt * 7.0) * 0.6
	return v


func _whimper(t: float, _n: float) -> float:
	var f := 900.0 + 500.0 * sin(t / 0.5 * PI) + 40.0 * sin(t * 40.0)
	return sin(_phase("whimper", f)) * _env(t, 0.03, 0.47) * 0.6


func _brake(t: float, n: float) -> float:
	var f := 2300.0 + 120.0 * sin(t * 55.0)
	return (sin(_phase("brake", f)) * 0.35 + n * 0.25) * _env(t, 0.02, 0.68)


func _cheer(t: float, n: float) -> float:
	var hum := sin(_phase("cheer", 330.0 + 30.0 * sin(t * 9.0))) * 0.15
	return (_lowpass("cheer", n, 0.2) * 0.8 + hum) * _env(t, 0.05, 0.55)


func _glug(t: float, _n: float) -> float:
	var v := 0.0
	for i in 3:
		var tt := t - i * 0.13
		if tt >= 0.0 and tt < 0.1:
			v += sin(TAU * (220.0 + 2400.0 * tt) * tt) * _env(tt, 0.01, 0.09)
	return v * 0.7


func _break(t: float, n: float) -> float:
	var v := n * _env(t, 0.0, 0.07) * 0.8
	for i in 6:
		var tt := t - 0.02 - i * 0.055
		if tt >= 0.0:
			v += sin(TAU * (3000.0 + i * 650.0) * tt) * exp(-tt * 40.0) * 0.35
	return v


func _bark(t: float, n: float) -> float:
	var v := 0.0
	for i in 2:
		var tt := t - i * 0.2
		if tt >= 0.0 and tt < 0.14:
			var f := lerpf(420.0, 260.0, tt / 0.14)
			var saw := fmod(f * tt, 1.0) * 2.0 - 1.0
			v += (saw * 0.6 + n * 0.3) * _env(tt, 0.01, 0.13)
	return v * 0.7


func _gull(t: float, _n: float) -> float:
	var v := 0.0
	for i in 2:
		var tt := t - i * 0.27
		if tt >= 0.0 and tt < 0.24:
			var f := lerpf(1900.0, 1150.0, tt / 0.24) + 60.0 * sin(tt * 90.0)
			var saw := fmod(f * tt, 1.0) * 2.0 - 1.0
			v += (sin(TAU * f * tt) * 0.5 + saw * 0.2) * _env(tt, 0.02, 0.22)
	return v * 0.6
