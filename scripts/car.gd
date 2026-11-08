extends Node3D
## A car driving along the street (right-hand traffic). Stops for anyone on
## a zebra crossing and for the car in front; anyone walking on the road
## elsewhere may get run over. Lives in world time.
## Broken glass punctures a tyre: the car doesn't brake but slows down
## little by little, swerving about, until it stops or crashes into a
## wall, another car or someone.

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
## Stopped because the driver got out to fight; `driver` is that NPC.
var parked := false
var driver = null
## Half the car's width (for bumping into its side).
const HALF_WIDTH := 0.85
## Flat tyre: slowing (m/s²) and how hard it swerves.
const FLAT_SLOWDOWN := 0.9
const FLAT_SWERVE := 2.4
## The car body can't go past the house walls (far side) or the hedges
## (near side).
const WALL_Z := -7.0
const HEDGE_Z := 5.0
var flat := false
## Crashed or rolled to a stop with a flat: stays put.
var wrecked := false
var _drift := 0.0
var _drift_t := 0.0
## The street ahead is shut (end of the map or roadworks): at x = turn_at
## the car turns into the side street, up (away from the camera, -1) or
## down (+1); turn_z = 0 means it just drives on.
var turn_at := INF
var turn_z := 0
var _turning := false


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
	if wrecked:
		speed = 0.0
		return
	if _turning:
		_drive_turn(dt)
		return
	if turn_z != 0 and not flat and (position.x - turn_at) * dir >= 0.0:
		_turning = true
		_drive_turn(dt)
		return
	if flat:
		_drive_flat(dt)
		return
	if speed > 1.0 and _on_glass():
		_puncture()
		return
	if parked:
		speed = 0.0
		# The driver is gone (block change etc.): drive on.
		if driver == null or not is_instance_valid(driver):
			parked = false
			driver = null
		return
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
	# Someone lying on the road in this lane ahead: stop in front of them.
	var lying: Array = []
	if main.player.is_helpless() and main.player._ride_car == null:
		lying.append(main.player.position)
	for n in main.npcs:
		if n.is_down():
			lying.append(n.position)
	for lp in lying:
		var ahead2: float = (lp.x - position.x) * dir
		if ahead2 > 0.0 and ahead2 < 14.0 and absf(lp.z - position.z) < 1.6:
			want = minf(want, maxf(0.0, (ahead2 - HALF_LEN - 1.0) * 1.6))
	# Keep a gap to the car in front. A wreck in the way is driven round
	# slowly on the other side of it.
	var lane := LANE_RIGHT if dir > 0 else LANE_LEFT
	var want_z := lane
	for other in main.cars:
		if other == self or absf(other.position.z - position.z) > 2.2:
			continue
		var gap: float = (other.position.x - position.x) * dir
		if other.wrecked:
			if gap > -HALF_LEN * 2.0 and gap < 14.0 and absf(other.position.z - lane) < 2.0:
				want_z = other.position.z + (2.0 if other.position.z < -1.25 else -2.0)
				want = minf(want, 3.0)
				if gap > 0.0 and gap < HALF_LEN * 2.0 + 0.6 and absf(other.position.z - position.z) < HALF_WIDTH * 2.0:
					want = 0.0
			continue
		if other.dir != dir or absf(other.position.z - position.z) > 1.6:
			continue
		if gap > 0.0 and gap < FOLLOW_GAP + 6.0:
			want = minf(want, maxf(0.0, (gap - FOLLOW_GAP) * 2.0))
	position.z = move_toward(position.z, want_z, 1.8 * dt)
	speed = move_toward(speed, want, ACCEL * dt)
	position.x += dir * speed * dt
	if speed > 2.0 and _hit_cool <= 0.0 and not parked:
		_check_hits()
	if absf(position.x) > EDGE_X:
		main.remove_car(self)


## Round the corner into the side street and away along it.
func _drive_turn(dt: float) -> void:
	speed = move_toward(speed, 4.5, ACCEL * dt)
	var want_rot := float(dir) * float(-turn_z) * PI * 0.5
	rotation.y = lerp_angle(rotation.y, want_rot, 1.0 - exp(-5.0 * dt))
	# Along the car's nose.
	var a := rotation.y
	var fwd := Vector3(cos(a) * dir, 0.0, -sin(a) * dir)
	position += fwd * speed * dt
	if position.z < -30.0 or position.z > 24.0:
		main.remove_car(self)


## Any shards under the car's footprint?
func _on_glass() -> bool:
	for g in main.glass:
		if absf(g.position.x - position.x) < HALF_LEN and absf(g.position.z - position.z) < HALF_WIDTH + 0.2:
			return true
	return false


## A shard in the tyre: bang, and from now on it swerves about.
func _puncture() -> void:
	flat = true
	braking = false
	_brake_in = -1.0
	main.popup("PAM!", position + Vector3(0, 1.8, 0), Color(1, 0.85, 0.4))
	main.shake(0.06)


## Flat tyre: no braking for anything, just slowing down bit by bit while
## the car pulls one way and then the other, more often towards its own
## kerb. Ends against a wall, a hedge or another car, or rolls to a stop.
func _drive_flat(dt: float) -> void:
	speed = move_toward(speed, 0.0, FLAT_SLOWDOWN * dt)
	_drift_t -= dt
	if _drift_t <= 0.0:
		_drift_t = main.rng.randf_range(0.3, 0.8)
		var kerb := 1.0 if dir > 0 else -1.0
		_drift = main.rng.randf_range(-FLAT_SWERVE, FLAT_SWERVE) + kerb * 0.6
	var pull := speed / MAX_SPEED + 0.25
	position.z += _drift * pull * dt
	position.x += dir * speed * dt
	# Nose turned the way it is swerving, and the flat corner sags.
	rotation.y = lerp_angle(rotation.y, -_drift * pull * 0.12 * dir, 1.0 - exp(-6.0 * dt))
	rotation.x = 0.04 * dir
	if speed > 2.0 and _hit_cool <= 0.0:
		_check_hits()
	if position.z < WALL_Z or position.z > HEDGE_Z:
		position.z = clampf(position.z, WALL_Z, HEDGE_Z)
		_crash()
		return
	for other in main.cars:
		if other != self and absf(other.position.x - position.x) < HALF_LEN * 2.0 \
				and absf(other.position.z - position.z) < HALF_WIDTH * 2.0:
			_crash()
			other.hit_by_wreck()
			return
	if speed <= 0.0:
		wrecked = true
	if absf(position.x) > EDGE_X:
		main.remove_car(self)


func _crash() -> void:
	if wrecked:
		return
	if speed > 1.5:
		main.popup("KRÄSH!", position + Vector3(0, 2.0, 0), Color(1, 0.55, 0.3), 1.4)
		main.shake(0.1 + speed * 0.02)
	wrecked = true
	speed = 0.0


## A swerving car ran into this one: it stops dead too.
func hit_by_wreck() -> void:
	if not wrecked:
		main.popup("KRÄSH!", position + Vector3(0, 2.0, 0), Color(1, 0.55, 0.3), 1.4)
	wrecked = true
	speed = 0.0
	parked = false


## Someone walked into the side: sometimes the car stops and the driver
## gets out to fight.
func side_bump(p: Node3D) -> void:
	if flat or wrecked or parked or driver != null or main.rng.randf() > 0.33:
		return
	parked = true
	speed = 0.0
	var side := signf(p.position.z - position.z)
	driver = main.spawn_driver(self, Vector3(position.x, 0.0, position.z + side * (HALF_WIDTH + 0.45)))


## The driver is back in the car: drive on.
func driver_back() -> void:
	driver = null
	parked = false


## Anyone in the car's way on the road gets hit.
func _check_hits() -> void:
	var p = main.player
	if not p.is_helpless() and p.car_grace <= 0.0 and absf(p.position.x - position.x) < HALF_LEN + 0.3 and absf(p.position.z - position.z) < 1.1:
		_hit_cool = 1.0
		var r: float = main.rng.randf()
		if r < 0.65:
			# The bumper hits: thrown at once as a rag doll, further the
			# faster the car; the driver slams on the brakes.
			p.hit_by_car_front(dir, speed)
			_brake_in = 0.15
		elif r < 0.9:
			# Sometimes up onto the bonnet; brake after a random while.
			p.start_bonnet_ride(self)
			_brake_in = main.rng.randf_range(0.3, 0.9)
		else:
			# Rarely straight under the wheels; the car doesn't slow down.
			p.run_over(dir)
	for n in main.npcs:
		if n.is_down():
			continue
		if absf(n.position.x - position.x) < HALF_LEN + 0.3 and absf(n.position.z - position.z) < 1.1:
			n.take_hit(10, self)
			_hit_cool = 1.0
	# A cyclist wobbling about on the road.
	for rd in main.riders:
		if not rd.crashed and absf(rd.position.x - position.x) < HALF_LEN + 0.3 and absf(rd.position.z - position.z) < 1.1:
			rd.hit_by_car(dir, speed)
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
