extends Node3D
## A car driving along the street (right-hand traffic). Stops for anyone on
## a zebra crossing and for the car in front; anyone walking on the road
## elsewhere may get run over. Lives in world time.

const HALF_LEN := 2.1
const MAX_SPEED := 7.5
const ACCEL := 9.0
const STOP_GAP := 1.6
const FOLLOW_GAP := 6.5
const HIT_DAMAGE := 20.0
const EDGE_X := 34.0
## Lanes: cars going right (+x) use the near lane, cars going left the far one.
const LANE_RIGHT := 0.6
const LANE_LEFT := -3.1

const COLORS := [Color(0.8, 0.15, 0.15), Color(0.15, 0.3, 0.75), Color(0.92, 0.92, 0.9),
	Color(0.15, 0.15, 0.17), Color(0.85, 0.7, 0.15), Color(0.3, 0.55, 0.35), Color(0.6, 0.6, 0.65)]

var main
var dir := 1
var speed := MAX_SPEED
var _hit_cool := 0.0
## After throwing someone onto the bonnet: drive on for a while, then brake.
var _brake_in := -1.0
var braking := false
var _stop_t := 0.0


func setup(rng: RandomNumberGenerator, d: int, x: float) -> void:
	dir = d
	position = Vector3(x, 0, LANE_RIGHT if d > 0 else LANE_LEFT)
	var col: Color = COLORS[rng.randi() % COLORS.size()]
	_box(Vector3(0, 0.55, 0), Vector3(HALF_LEN * 2.0, 0.6, 1.7), col)
	_box(Vector3(-0.2 * dir, 1.1, 0), Vector3(2.2, 0.55, 1.55), col.lightened(0.15))
	_box(Vector3(0.83 * dir, 1.1, 0), Vector3(0.05, 0.45, 1.4), Color(0.3, 0.4, 0.5))  # windscreen
	_box(Vector3(-1.25 * dir, 1.1, 0), Vector3(0.05, 0.45, 1.4), Color(0.3, 0.4, 0.5))
	for wx in [-1.3, 1.3]:
		for wz in [-0.8, 0.8]:
			var w := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.33
			cm.bottom_radius = 0.33
			cm.height = 0.25
			cm.radial_segments = 12
			w.mesh = cm
			w.material_override = _mat(Color(0.08, 0.08, 0.08))
			w.rotation.x = PI * 0.5
			w.position = Vector3(wx, 0.33, wz)
			add_child(w)
	# Headlights at the front.
	for lz in [-0.6, 0.6]:
		var l := _box(Vector3(HALF_LEN * dir, 0.6, lz), Vector3(0.06, 0.16, 0.3), Color(1, 0.95, 0.75))
		var m: StandardMaterial3D = l.material_override
		m.emission_enabled = true
		m.emission = Color(1, 0.9, 0.6)


func _process(_delta: float) -> void:
	var dt: float = GameState.world_dt
	if dt <= 0.0:
		return
	_hit_cool = maxf(0.0, _hit_cool - dt)
	var want := MAX_SPEED
	if _brake_in >= 0.0:
		_brake_in -= dt
		if _brake_in < 0.0:
			braking = true
	if braking:
		# Emergency stop, wait a moment, then drive on.
		speed = move_toward(speed, 0.0, 26.0 * dt)
		if speed <= 0.0:
			_stop_t += dt
			if _stop_t > 1.5:
				braking = false
				_stop_t = 0.0
		position.x += dir * speed * dt
		return
	# Someone on a zebra crossing ahead: stop in front of it.
	for cw_x in main.crosswalk_xs():
		var ahead: float = (cw_x - position.x) * dir
		if ahead > 0.0 and ahead < 14.0 and main.someone_on_crosswalk(cw_x):
			var room: float = ahead - HALF_LEN - STOP_GAP - 1.2
			want = minf(want, maxf(0.0, room * 1.6))
	# Keep a gap to the car in front.
	for other in main.cars:
		if other == self or other.dir != dir:
			continue
		var gap: float = (other.position.x - position.x) * dir
		if gap > 0.0 and gap < FOLLOW_GAP + 6.0:
			want = minf(want, maxf(0.0, (gap - FOLLOW_GAP) * 2.0))
	speed = move_toward(speed, want, ACCEL * dt)
	position.x += dir * speed * dt
	if speed > 2.0 and _hit_cool <= 0.0:
		_check_hits()
	if absf(position.x) > EDGE_X:
		main.remove_car(self)


## Anyone in the car's way on the road gets hit.
func _check_hits() -> void:
	var p = main.player
	if not p.is_helpless() and absf(p.position.x - position.x) < HALF_LEN + 0.3 and absf(p.position.z - position.z) < 1.1:
		_hit_cool = 1.0
		if main.rng.randf() < 0.6:
			# Onto the bonnet; brake after a random while.
			p.start_bonnet_ride(self)
			_brake_in = main.rng.randf_range(1.0, 2.5)
		else:
			# Straight under the wheels; the car doesn't slow down.
			p.run_over()
	for n in main.npcs:
		if n.is_down():
			continue
		if absf(n.position.x - position.x) < HALF_LEN + 0.3 and absf(n.position.z - position.z) < 1.1:
			n.take_hit(10, self)
			_hit_cool = 1.0


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	return m


func _box(pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	add_child(mi)
	return mi
