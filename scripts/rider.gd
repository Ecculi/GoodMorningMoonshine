extends Node3D
## A cyclist or an e-scooter rider tearing along the sidewalk (from day 4).
## Rings the bell / honks when the player is in the way ahead, swerves a
## little, and knocks the player over if they don't step aside. Rides on
## out of the block and is gone. Moves in world time.
## Broken glass: a scooter crashes spectacularly (the rider flies off as a
## rag doll); a bike gets a flat tyre and wobbles about, maybe out onto
## the road under a car.

const PersonModel = preload("res://scripts/person_model.gd")
const Ragdoll = preload("res://scripts/ragdoll.gd")
## Seconds a crashed rider lies there before being cleared away.
const CRASH_LINGER := 7.0

const EDGE_X := 30.0

var main
var kind := "bike"  # "bike" or "scooter"
var dir := 1
var speed := 6.0
var lane_z := 4.2
var _model
var _wheels: Array = []
var _warned := false
var _hit := false
var _swerve := 0.0
var _t := 0.0
## Vehicle parts (each in its own holder) so they can tumble in a crash.
var _holders: Array = []
var crashed := false
var _crash_t := 0.0
var _ragdoll = null
## Flat tyre (bike): wobbles and drifts about.
var flat := false
var _drift := 0.0
var _drift_t := 0.0


func setup(rng: RandomNumberGenerator, d: int) -> void:
	dir = d
	kind = "bike" if rng.randf() < 0.55 else "scooter"
	speed = rng.randf_range(5.5, 7.0) if kind == "bike" else rng.randf_range(4.5, 6.0)
	# One of the two sidewalks, near its middle.
	lane_z = rng.randf_range(-7.0, -5.8) if rng.randf() < 0.5 else rng.randf_range(3.3, 4.8)
	position = Vector3(-EDGE_X * dir, 0, lane_z)
	var shirt := Color.from_hsv(rng.randf(), 0.6, 0.85)
	_model = PersonModel.new(shirt, Color(0.15, 0.15, 0.2), Color(0.95, 0.8, 0.68), Color(0.2, 0.15, 0.1), 1.0)
	add_child(_model)
	_model.rotation.y = 0.0 if dir > 0 else PI
	if kind == "bike":
		_build_bike()
		_model.position.y = 0.35
	else:
		_build_scooter()
		_model.position.y = 0.12
	# A helmet for the cyclist.
	if kind == "bike":
		var h := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.19
		sm.height = 0.22
		h.mesh = sm
		h.material_override = _mat(Color(0.95, 0.85, 0.1))
		h.position = Vector3(0, 1.78, 0)
		_model.add_child(h)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m


func _part(mesh: Mesh, pos: Vector3, rot: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation = rot
	var holder := Node3D.new()
	holder.rotation.y = 0.0 if dir > 0 else PI
	add_child(holder)
	_holders.append(holder)
	holder.add_child(mi)
	return mi


func _wheel(x: float, r: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.05
	_wheels.append(_part(cm, Vector3(x, r, 0), Vector3(PI * 0.5, 0, 0), Color(0.1, 0.1, 0.1)))


func _bar(from: Vector3, to: Vector3, c: Color) -> void:
	var bm := BoxMesh.new()
	bm.size = Vector3((to - from).length(), 0.04, 0.04)
	var mid := (from + to) * 0.5
	var ang := atan2(to.y - from.y, to.x - from.x)
	_part(bm, mid, Vector3(0, 0, ang), c)


func _build_bike() -> void:
	var frame := Color(0.8, 0.15, 0.15)
	_wheel(0.5, 0.33)
	_wheel(-0.5, 0.33)
	_bar(Vector3(-0.5, 0.33, 0), Vector3(0.0, 0.75, 0), frame)
	_bar(Vector3(0.0, 0.75, 0), Vector3(0.5, 0.33, 0), frame)
	_bar(Vector3(-0.5, 0.33, 0), Vector3(0.1, 0.4, 0), frame)
	_bar(Vector3(0.45, 0.33, 0), Vector3(0.38, 1.0, 0), frame)  # fork
	_bar(Vector3(0.3, 1.0, -0.25), Vector3(0.3, 1.0, 0.25), Color(0.2, 0.2, 0.2))  # handlebar (approx.)


func _build_scooter() -> void:
	_wheel(0.35, 0.1)
	_wheel(-0.35, 0.1)
	var deck := BoxMesh.new()
	deck.size = Vector3(0.7, 0.05, 0.16)
	_part(deck, Vector3(0, 0.15, 0), Vector3.ZERO, Color(0.15, 0.15, 0.17))
	_bar(Vector3(0.35, 0.15, 0), Vector3(0.3, 1.1, 0), Color(0.25, 0.25, 0.3))
	_bar(Vector3(0.3, 1.1, -0.22), Vector3(0.3, 1.1, 0.22), Color(0.2, 0.2, 0.2))


func _process(_delta: float) -> void:
	var dt: float = GameState.world_dt
	if dt <= 0.0 or main == null:
		return
	_t += dt
	if crashed:
		_crash_t += dt
		if _crash_t > CRASH_LINGER:
			main.remove_rider(self)
		return
	# Over broken glass.
	if main.glass_at(position) != null:
		if kind == "scooter":
			main.popup("!", position + Vector3(0, 2.2, 0), Color(1, 0.5, 0.4))
			crash(Vector3(dir * speed * 0.9, 3.2, randf_range(-0.8, 0.8)))
			return
		elif not flat:
			flat = true
			main.popup("pssh!", position + Vector3(0, 1.8, 0), Color(0.85, 0.9, 1.0))
	var p: Vector3 = main.player.position
	var ahead: float = (p.x - position.x) * dir
	var dz: float = p.z - position.z
	# Player in the way ahead: ring / honk once and swerve a bit.
	if not _warned and ahead > 0.0 and ahead < 7.0 and absf(dz) < 0.9:
		_warned = true
		main.popup("kling!" if kind == "bike" else "piip!", position + Vector3(0, 2.2, 0), Color(1, 1, 0.6))
	if ahead > 0.0 and ahead < 4.0 and absf(dz) < 1.0:
		_swerve = move_toward(_swerve, -signf(dz if dz != 0.0 else 1.0) * 0.6, dt * 1.5)
	else:
		_swerve = move_toward(_swerve, 0.0, dt * 0.8)
	if flat:
		_wobble(dt)
	position.x += dir * speed * dt
	position.z = lane_z + _swerve
	# Too late: the player is knocked over.
	if not _hit and absf(p.x - position.x) < 0.55 and absf(p.z - position.z) < 0.45 and not main.player.is_helpless():
		_hit = true
		main.player.hit_by_rider(dir, speed)
		main.popup("!", position + Vector3(0, 2.2, 0), Color(1, 0.5, 0.4))
	# Pedalling / standing.
	if kind == "bike":
		_model.animate(1.0, dt, speed / 2.0)
	else:
		_model.animate(0.0, dt)
	if absf(position.x) > EDGE_X + 1.0:
		main.remove_rider(self)


## Flat tyre: slower, the bike leans from side to side and heads off in
## odd directions now and then, a little more often towards the road.
func _wobble(dt: float) -> void:
	speed = move_toward(speed, 3.4, dt * 1.2)
	_drift_t -= dt
	if _drift_t <= 0.0:
		_drift_t = randf_range(0.35, 0.9)
		var to_road := signf(-1.2 - lane_z)
		_drift = randf_range(-2.0, 2.0) + to_road * 0.7
	lane_z = clampf(lane_z + _drift * dt, -7.3, 5.4)
	rotation.x = sin(_t * 8.0) * 0.12 + _drift * 0.05


## Hit by a car while wobbling on the road.
func hit_by_car(car_dir: int, car_speed: float) -> void:
	if crashed:
		return
	main.popup("!", position + Vector3(0, 2.2, 0), Color(1, 0.4, 0.3))
	main.shake(0.15)
	crash(Vector3(car_dir * car_speed * 1.0, 4.5, randf_range(-1.0, 1.0)))


## Off the vehicle: the rider flies on as a rag doll and the bike or
## scooter tumbles over and slides to a stop.
func crash(vel: Vector3) -> void:
	if crashed:
		return
	crashed = true
	rotation.x = 0.0
	_ragdoll = Ragdoll.new()
	add_child(_ragdoll)
	_ragdoll.build(_model, vel)
	_model.visible = false
	var slide := Vector3(vel.x * 0.25, 0.0, vel.z * 0.2)
	for h in _holders:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(h, "rotation:x", PI * 0.5 * (1.0 if randf() < 0.5 else -1.0), 0.35)
		tw.parallel().tween_property(h, "position", h.position + slide, 0.8)
