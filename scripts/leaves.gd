extends Node3D
## Leaves blown about by the wind in the current block.
##
## - The wind has a slowly changing base along the street plus gusts that
##   build up and die away.
## - Leaves lying on the ground skitter along when the wind picks up and
##   lift off in a strong gust.
## - Airborne leaves fall slowly with the classic "falling leaf" swing:
##   side to side like a pendulum, slowing at each end of the swing and
##   tilting with it, and tumble in strong wind.
## - Now and then a gust lifts a small heap of leaves together and swirls
##   it along.
## Leaves move only while game time runs (GameState.world_dt). Rain makes
## them wet and heavy; under snow there are none.

const CityMap = preload("res://scripts/city_map.gd")

const X_MIN := -27.0
const X_MAX := 27.0
const Z_MIN := -7.8
const Z_MAX := 5.6
const GROUND_LEAVES := 26
const SIDEWALK_Y := 0.12
const GRAVITY := 9.8
## Air drag: horizontal (leaves follow the wind quickly) and vertical
## (keeps the fall slow, about 1 m/s).
const DRAG_H := 2.2
const DRAG_V := 7.5
const COLORS := [Color(0.85, 0.55, 0.12), Color(0.75, 0.3, 0.1), Color(0.92, 0.75, 0.2),
	Color(0.55, 0.32, 0.12), Color(0.68, 0.18, 0.08), Color(0.6, 0.55, 0.2)]

var seg := Vector3i.ZERO
var _leaves: Array = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0
## Base wind along the street (m/s), drifting slowly.
var _base := 1.0
var _base_target := 1.0
var _base_cd := 0.0
## Current gust: strength (m/s) and its life.
var _gust := 0.0
var _gust_peak := 0.0
var _gust_t := 0.0
var _gust_len := 0.0
var _gust_cd := 4.0
var _wet := false
## No leaves at all (snow).
var _off := false


func setup(segment: Vector3i, weather: String) -> void:
	seg = segment
	_rng.seed = CityMap.seed_of(seg) ^ hash(GameState.day)
	if weather == "snow":
		_off = true  # covered by snow
		return
	_wet = weather == "rain"
	_base = _rng.randf_range(-1.5, 1.5)
	_base_target = _base
	for i in GROUND_LEAVES:
		var p := Vector3(_rng.randf_range(X_MIN, X_MAX), 0.0, _rng.randf_range(Z_MIN, Z_MAX))
		# Leaves gather by the walls and the curbs.
		if _rng.randf() < 0.5:
			p.z = [-7.7, -5.1, 2.6, 5.5][_rng.randi() % 4] + _rng.randf_range(-0.15, 0.15)
		p.y = _ground_y(p)
		_add_leaf(p, false)


func _add_leaf(p: Vector3, airborne: bool, vel := Vector3.ZERO) -> Dictionary:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	var s := _rng.randf_range(0.08, 0.14)
	qm.size = Vector2(s, s * 0.75)
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	var c: Color = COLORS[_rng.randi() % COLORS.size()]
	if _wet:
		c = c.darkened(0.3)
	m.albedo_color = c.lerp(Color(0.5, 0.35, 0.15), _rng.randf_range(0.0, 0.3))
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	mi.material_override = m
	add_child(mi)
	var lf := {
		"mi": mi, "pos": p, "vel": vel, "air": airborne,
		"yaw": _rng.randf_range(0.0, TAU),
		"pitch": 0.0, "roll": 0.0,
		# Swing (falling-leaf pendulum).
		"phase": _rng.randf_range(0.0, TAU),
		"freq": _rng.randf_range(2.2, 3.6),
		"amp": _rng.randf_range(0.5, 1.1),
		"swing": Vector2.from_angle(_rng.randf_range(0.0, TAU)),
		"spin": _rng.randf_range(-3.0, 3.0),
		# Wind speed it takes to move / lift this leaf (heavier when wet).
		"slide_at": _rng.randf_range(1.8, 3.0) * (2.0 if _wet else 1.0),
		"lift_at": _rng.randf_range(4.0, 6.0) * (2.0 if _wet else 1.0),
		# Swirl around the centre of a blown heap.
		"swirl": Vector3.ZERO, "swirl_t": 0.0,
		# Flips: now and then the wind catches the leaf and it somersaults
		# once, looping a little in the air.
		"flip_cd": _rng.randf_range(0.5, 3.0), "flip_t": 0.0, "flip_len": 0.6,
		"flip_axis": 0, "flip_dir": 1.0, "flip_ang": 0.0,
	}
	_leaves.append(lf)
	_apply(lf)
	return lf


func _ground_y(p: Vector3) -> float:
	var ax := absf(p.x)
	var far := p.z < -5.0
	var near := p.z > 2.5 and p.z < 5.8
	if not far and not near:
		return 0.0
	if ax < 16.0 or ax > 23.0:
		return SIDEWALK_Y
	# In a crossing the sidewalk is there only where the crossing street ends.
	if far and not CityMap.can_turn(seg, p.x > 0.0, true):
		return SIDEWALK_Y
	if near and not CityMap.can_turn(seg, p.x > 0.0, false):
		return SIDEWALK_Y
	return 0.0


## Wind at a point: base + gust, with a little variation along the street
## so neighbouring leaves don't move in lockstep.
func _wind(p: Vector3) -> Vector3:
	var w := _base + _gust
	var wobble := sin(_t * 0.7 + p.x * 0.35) * 0.4 + sin(_t * 1.9 + p.z * 0.8) * 0.25
	var side := sin(_t * 0.5 + p.x * 0.2) * 0.35 * absf(w)
	return Vector3(w * (1.0 + wobble * 0.3) + wobble, 0.0, side)


func _process(_delta: float) -> void:
	var dt: float = GameState.world_dt
	if dt <= 0.0 or _off:
		return
	dt = minf(dt, 0.05)
	_t += dt
	_update_wind(dt)
	for lf in _leaves:
		if lf["air"]:
			_fly(lf, dt)
		else:
			_on_ground(lf, dt)
		_wrap(lf)
		_apply(lf)


func _update_wind(dt: float) -> void:
	_base_cd -= dt
	if _base_cd <= 0.0:
		_base_cd = _rng.randf_range(6.0, 14.0)
		# Mostly keeps its direction, sometimes turns.
		var dir := signf(_base_target) if _rng.randf() < 0.8 else -signf(_base_target)
		if dir == 0.0:
			dir = 1.0
		_base_target = dir * _rng.randf_range(0.3, 2.0)
	_base = move_toward(_base, _base_target, dt * 0.25)
	if _gust_len > 0.0:
		# Rise quickly (first quarter), fade out slowly.
		_gust_t += dt
		var k := _gust_t / _gust_len
		var env := k / 0.25 if k < 0.25 else 1.0 - (k - 0.25) / 0.75
		_gust = signf(_base if _base != 0.0 else 1.0) * _gust_peak * clampf(env, 0.0, 1.0)
		if _gust_t >= _gust_len:
			_gust_len = 0.0
			_gust = 0.0
	else:
		_gust_cd -= dt
		if _gust_cd <= 0.0:
			_gust_cd = _rng.randf_range(5.0, 12.0)
			_gust_len = _rng.randf_range(2.0, 4.0)
			_gust_t = 0.0
			_gust_peak = _rng.randf_range(3.0, 7.5)
			if not _wet and _rng.randf() < 0.45:
				_blow_heap()


## A small heap of leaves whirled up together by a gust, coming in from
## the upwind side of the view or rising from the ground.
func _blow_heap() -> void:
	var up := signf(_base if _base != 0.0 else 1.0)
	var cam_x: float = 0.0
	var main = get_parent().get_parent() if get_parent() != null else null
	if main != null and main.get("player") != null:
		cam_x = main.player.position.x
	var c := Vector3(clampf(cam_x - up * _rng.randf_range(6.0, 11.0), X_MIN, X_MAX), 0.0,
		[-7.4, -5.3, 2.8, 5.2][_rng.randi() % 4])
	c.y = _ground_y(c)
	var n := _rng.randi_range(5, 9)
	var swirl_dir := 1.0 if _rng.randf() < 0.5 else -1.0
	for i in n:
		var p := c + Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(0.0, 0.25), _rng.randf_range(-0.3, 0.3))
		var v := Vector3(up * _rng.randf_range(1.5, 3.0), _rng.randf_range(2.0, 3.5), _rng.randf_range(-0.4, 0.4))
		var lf := _add_leaf(p, true, v)
		lf["swirl"] = c
		lf["swirl_t"] = _rng.randf_range(1.5, 2.5) * swirl_dir
	# Don't let leaves pile up forever: drop the oldest ground ones.
	while _leaves.size() > GROUND_LEAVES + 24:
		var old: Dictionary = _leaves.pop_front()
		old["mi"].queue_free()


func _fly(lf: Dictionary, dt: float) -> void:
	var p: Vector3 = lf["pos"]
	var v: Vector3 = lf["vel"]
	var w := _wind(p)
	var wind_speed := absf(w.x)
	# Pendulum swing: horizontal velocity along the swing direction, the
	# fall speeds up through the middle of the swing and slows at the ends.
	lf["phase"] += dt * lf["freq"]
	var osc := sin(lf["phase"])
	var amp: float = lf["amp"] / (1.0 + wind_speed * 0.25)
	var sw: Vector2 = lf["swing"]
	var swing_v := Vector3(sw.x, 0.0, sw.y) * osc * amp
	var target := w + swing_v
	# Drag towards the wind (and the swing), gravity against vertical drag.
	v.x += (target.x - v.x) * DRAG_H * dt
	v.z += (target.z - v.z) * DRAG_H * dt
	var fall := -GRAVITY / DRAG_V * (0.55 + 0.6 * absf(cos(lf["phase"])))
	# Gusts lift a little (updraft at the front of a gust).
	fall += clampf(_gust * 0.08, 0.0, 0.6) * (1.0 if _gust_t < _gust_len * 0.3 else 0.0)
	v.y += (fall - v.y) * DRAG_V * dt * 0.5
	# A blown heap swirls around its centre for a moment.
	var st: float = lf["swirl_t"]
	if absf(st) > 0.0:
		var c: Vector3 = lf["swirl"]
		c.x += w.x * dt
		lf["swirl"] = c
		var r := Vector2(p.x - c.x, p.z - c.z)
		var tang := Vector2(-r.y, r.x).normalized() * signf(st) * 1.6
		v.x += tang.x * dt * 3.0
		v.z += tang.y * dt * 3.0
		st = move_toward(st, 0.0, dt)
		lf["swirl_t"] = st
	_flip(lf, v, dt, wind_speed)
	v = lf["vel"]
	p += v * dt
	# Tilt with the swing; tumble when the wind is strong.
	lf["roll"] = osc * 0.9
	lf["pitch"] += dt * lf["spin"] * (0.4 + wind_speed * 0.5)
	lf["yaw"] += dt * lf["spin"] * 0.3
	var gy := _ground_y(p)
	if p.y <= gy + 0.005:
		p.y = gy + 0.005
		lf["air"] = false
		v = Vector3.ZERO
		# Lands flat, mostly face up.
		lf["pitch"] = 0.0
		lf["roll"] = 0.0
		lf["swirl_t"] = 0.0
		lf["flip_t"] = 0.0
		lf["flip_ang"] = 0.0
	lf["pos"] = p
	lf["vel"] = v


## Somersault: a full turn about a random axis over about half a second,
## while the leaf loops through a small circle (an eddy catches it).
## More often in stronger wind.
func _flip(lf: Dictionary, v: Vector3, dt: float, wind_speed: float) -> void:
	var ft: float = lf["flip_t"]
	if ft <= 0.0:
		lf["flip_ang"] = 0.0
		lf["flip_cd"] -= dt * (0.5 + wind_speed * 0.45)
		if lf["flip_cd"] <= 0.0 and lf["pos"].y > 0.6:
			lf["flip_cd"] = _rng.randf_range(1.5, 5.0)
			lf["flip_len"] = _rng.randf_range(0.4, 0.8)
			lf["flip_t"] = lf["flip_len"]
			lf["flip_axis"] = _rng.randi() % 2
			lf["flip_dir"] = 1.0 if _rng.randf() < 0.5 else -1.0
		lf["vel"] = v
		return
	var flen: float = lf["flip_len"]
	ft = maxf(0.0, ft - dt)
	lf["flip_t"] = ft
	var k := 1.0 - ft / flen  # 0 -> 1 through the flip
	# Ease in and out so the turn starts and ends softly.
	var ang := (k * k * (3.0 - 2.0 * k)) * TAU * float(lf["flip_dir"])
	lf["flip_ang"] = ang
	# Loop: velocity around a small vertical circle (radius ~0.25 m).
	var w := TAU / flen
	var r := 0.25
	var dir: float = lf["flip_dir"]
	v.x += -sin(k * TAU) * r * w * dir * dt * 6.0
	v.y += cos(k * TAU) * r * w * dt * 6.0
	lf["vel"] = v


func _on_ground(lf: Dictionary, dt: float) -> void:
	var p: Vector3 = lf["pos"]
	var v: Vector3 = lf["vel"]
	var w := _wind(p)
	var ws := w.length()
	var slide_at: float = lf["slide_at"]
	var lift_at: float = lf["lift_at"]
	if ws > slide_at:
		# Skitter along the ground in jerks, now and then flipping over.
		var push := (ws - slide_at) * 0.45
		v.x += (w.normalized().x * push - v.x) * 3.0 * dt
		v.z += (w.normalized().z * push * 0.5 - v.z) * 3.0 * dt
		if _rng.randf() < dt * 1.5:
			v.x *= 1.8
			lf["yaw"] += _rng.randf_range(-0.6, 0.6)
		if _rng.randf() < dt * 0.8:
			lf["roll"] = PI if lf["roll"] == 0.0 else 0.0  # flips
		if ws > lift_at and _rng.randf() < dt * 1.2:
			lf["air"] = true
			v.y = _rng.randf_range(1.2, 2.8)
			lf["phase"] = _rng.randf_range(0.0, TAU)
	else:
		v = v.move_toward(Vector3.ZERO, 4.0 * dt)
	p.x += v.x * dt
	p.z = clampf(p.z + v.z * dt, Z_MIN, Z_MAX)
	# Over the curb: up onto the sidewalk or down onto the street.
	p.y = _ground_y(p) + 0.005
	lf["pos"] = p
	lf["vel"] = v


## Leaves blown out of the area come back from the upwind side, in the air.
func _wrap(lf: Dictionary) -> void:
	var p: Vector3 = lf["pos"]
	if p.x > X_MAX or p.x < X_MIN:
		var from_left := p.x > X_MAX
		p.x = X_MIN + 0.5 if from_left else X_MAX - 0.5
		p.z = _rng.randf_range(Z_MIN, Z_MAX)
		p.y = _rng.randf_range(1.0, 3.5)
		lf["air"] = true
		lf["vel"] = Vector3(_wind(p).x, 0.0, 0.0)
	p.z = clampf(p.z, Z_MIN, Z_MAX)
	lf["pos"] = p


func _apply(lf: Dictionary) -> void:
	var mi: MeshInstance3D = lf["mi"]
	mi.position = lf["pos"]
	# Quad faces +Z: tip it flat (-90° about X), then yaw, swing and tumble.
	# A flip in progress adds a full turn about one axis on top.
	var pitch: float = lf["pitch"]
	var roll: float = lf["roll"]
	if lf["flip_axis"] == 0:
		pitch += lf["flip_ang"]
	else:
		roll += lf["flip_ang"]
	var b := Basis(Vector3.UP, lf["yaw"]) * Basis(Vector3.FORWARD, roll) \
		* Basis(Vector3.RIGHT, pitch - PI * 0.5)
	mi.basis = b
