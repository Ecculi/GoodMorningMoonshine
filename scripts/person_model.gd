extends Node3D
## Simple blocky person built from primitive meshes. Faces +X.
## The owner calls animate() with the world delta so frozen time
## also freezes the animation.

var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
## Left forearm, hinged at the elbow (child of arm_l).
var forearm_l: Node3D
var arm_r: Node3D
## Right forearm, hinged at the elbow (child of arm_r).
var forearm_r: Node3D
var hand: Node3D

var _walk_phase := 0.0
var _walk_amount := 0.0
var _punch_t := 0.0
## 0..1 while a punch is being charged (arm pulled back), otherwise -1.
var _windup := -1.0
var _raised := false
## Arm held straight out, pointing at something in front.
var pointing := false


var shirt_color: Color
var pants_color: Color
var skin_color: Color
var hair_color: Color


func _init(shirt: Color, pants: Color, skin: Color, hair: Color, size := 1.0) -> void:
	shirt_color = shirt
	pants_color = pants
	skin_color = skin
	hair_color = hair
	scale = Vector3.ONE * size
	leg_l = _limb(Vector3(0, 0.9, -0.1), Vector3(0.17, 0.88, 0.17), pants)
	leg_r = _limb(Vector3(0, 0.9, 0.1), Vector3(0.17, 0.88, 0.17), pants)
	# Shoes on the feet, toes forward (+X); they move with the legs.
	for leg in [leg_l, leg_r]:
		_shoes.append(_patch(leg, Vector3(0.05, -0.855, 0), Vector3(0.27, 0.09, 0.15), Color(0.12, 0.1, 0.09)))
		_shoes.append(_patch(leg, Vector3(0.17, -0.885, 0), Vector3(0.05, 0.03, 0.15), Color(0.85, 0.85, 0.82)))
		# Bare feet with toes, shown when the shoes are off.
		var foot := _patch(leg, Vector3(0.05, -0.865, 0), Vector3(0.24, 0.07, 0.13), skin)
		foot.visible = false
		_feet.append(foot)
		var toes := _patch(leg, Vector3(0.18, -0.885, 0), Vector3(0.04, 0.035, 0.13), skin.darkened(0.12))
		toes.visible = false
		_feet.append(toes)
	_box(Vector3(0, 1.22, 0), Vector3(0.28, 0.64, 0.46), shirt)
	_head = _sphere(Vector3(0, 1.69, 0), 0.16, skin)
	_head_parts.append(_head)
	_head_parts.append(_box(Vector3(-0.03, 1.81, 0), Vector3(0.28, 0.08, 0.32), hair))
	# Eyes (the face looks towards +X) and eyelids that close when tired.
	for ez in [-0.065, 0.065]:
		_head_parts.append(_box(Vector3(0.152, 1.72, ez), Vector3(0.02, 0.045, 0.045), Color(0.08, 0.08, 0.1)))
		_eyelids.append(_box(Vector3(0.162, 1.74, ez), Vector3(0.02, 0.006, 0.055), skin))
		_head_parts.append(_eyelids[-1])
	arm_l = _limb(Vector3(0, 1.5, -0.29), Vector3(0.12, 0.32, 0.12), shirt)
	forearm_l = _limb(Vector3(0, -0.31, 0), Vector3(0.115, 0.31, 0.115), shirt, arm_l)
	# Right arm in two parts so it can bend at the elbow for a charged punch.
	arm_r = _limb(Vector3(0, 1.5, 0.29), Vector3(0.12, 0.32, 0.12), shirt)
	forearm_r = _limb(Vector3(0, -0.31, 0), Vector3(0.115, 0.31, 0.115), shirt, arm_r)
	hand = Node3D.new()
	hand.position = Vector3(0, -0.35, 0)
	forearm_r.add_child(hand)


## `silly` 0..1: a very drunk, absurdly exaggerated walk (high kicks,
## flailing arms, bouncing). Returns the bounce height and backward lean
## so the owner can apply them to the whole body.
var _eyelids: Array = []
var _head: MeshInstance3D
## Everything on the head (turned together by turn_head()).
var _head_parts: Array = []
## Head turn to the left (+) or right (-) of the body, radians.
var head_yaw := 0.0
## 0..1: arms wrapped round the body against the cold.
var cold_hug := 0.0
## 0..1: left hand raised to the forehead against the sun.
var shade_eyes := 0.0
## Sitting on the ground, back to a wall, legs out in front.
var sitting := false:
	set(v):
		sitting = v
		position.y = -0.82 if v else 0.0
var silly_bounce := 0.0
var silly_lean := 0.0


func animate(walk_amount: float, dt: float, speed_mult := 1.0, silly := 0.0) -> void:
	_walk_amount = lerpf(_walk_amount, walk_amount, clampf(dt * 10.0, 0.0, 1.0))
	_walk_phase += dt * 9.0 * speed_mult * (1.0 - silly * 0.35)
	var ph := _walk_phase
	var s := sin(ph) * 0.55 * _walk_amount * (1.0 - 0.45 * crouch)
	var k := silly * _walk_amount
	# One leg kicks high forward, the other does a little skip.
	leg_l.rotation.z = lerpf(s, maxf(0.0, sin(ph)) * 1.8 - 0.25, k)
	leg_r.rotation.z = lerpf(-s, -0.45 * sin(ph) + 0.3 * sin(ph * 2.0), k)
	arm_l.rotation.z = lerpf(-s * 0.8, 1.3 * sin(ph + 1.0) + 0.5, k)
	if sitting:
		leg_l.rotation.z = PI * 0.5
		leg_r.rotation.z = PI * 0.5
		arm_l.rotation.z = 0.5
	silly_bounce = absf(sin(ph)) * 0.18 * k
	silly_lean = (0.22 + 0.08 * sin(ph * 2.0)) * k
	_animate_right_arm(dt, s, ph, k)
	# Cold: arms pulled in front of the body, hugging it.
	var hug := cold_hug * (1.0 - k)
	arm_l.rotation.x = -0.45 * hug
	arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.55, hug)
	forearm_l.rotation.z = lerpf(0.1, 1.2, hug)
	# Dazzled by the sun: the left hand goes up to the forehead like a
	# visor (upper arm forward and up, elbow bent back towards the face).
	if shade_eyes > 0.0:
		var e := shade_eyes
		arm_l.rotation.z = lerpf(arm_l.rotation.z, 2.0, e)
		arm_l.rotation.x = lerpf(arm_l.rotation.x, -0.35, e)
		forearm_l.rotation.z = lerpf(forearm_l.rotation.z, 1.78, e)
	# Sneaking: hands up in front of the chest, elbows bent.
	if crouch > 0.01:
		arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.7, crouch)
		forearm_l.rotation.z = lerpf(forearm_l.rotation.z, 1.4, crouch)
		if _punch_t <= 0.0 and _windup < 0.0 and not _raised:
			arm_r.rotation.z = lerpf(arm_r.rotation.z, 0.7, crouch)
			forearm_r.rotation.z = lerpf(forearm_r.rotation.z, 1.4, crouch)
	# Charging: the left hand comes up in front as a guard.
	if _pull > 0.01:
		arm_l.rotation.z = lerpf(arm_l.rotation.z, 1.0, _pull * 0.7)
		forearm_l.rotation.z = lerpf(forearm_l.rotation.z, 1.5, _pull * 0.7)
	if _punch_t <= 0.0 and _windup < 0.0 and not _raised:
		arm_r.rotation.x = lerpf(arm_r.rotation.x, 0.45, hug)
		arm_r.rotation.z = lerpf(arm_r.rotation.z, 0.35, hug)
		forearm_r.rotation.z = lerpf(forearm_r.rotation.z, 1.2, hug)


## Right arm angles as they are now; they ease towards each pose instead
## of jumping (_animate_right_arm).
var _arm_z := 0.0
var _arm_x := 0.0
var _fore_z := 0.15
## 0..1 how far the right shoulder is drawn back (charging) or thrown
## forward (negative, the punch).
var _pull := 0.0
## A punch goes a little upwards from straight ahead (radians).
const PUNCH_UP := 0.3
## Seconds the arm takes to snap straight when a punch is released.
const PUNCH_EXTEND := 0.07


## Right arm: walking swing, the charged pull-back, the punch and the
## raised fist. Poses blend smoothly; the punch itself snaps out fast,
## holds, and then the arm comes back softly.
func _animate_right_arm(dt: float, s: float, ph: float, k: float) -> void:
	var tz: float
	var tx := 0.0
	var tf := 0.15  # a relaxed little bend
	var tpull := 0.0
	var rate := 30.0
	if pointing and _punch_t <= 0.0 and _windup < 0.0:
		# Pointing: arm straight out in front, held there.
		tz = PI * 0.5
		tf = 0.0
		rate = 10.0
	elif _punch_t > 0.0:
		# Straight out in front, always a little upwards.
		_punch_t -= dt
		tz = PI * 0.5 + PUNCH_UP
		tf = 0.0
		tpull = -0.6
		# Snap out within PUNCH_EXTEND, then hold.
		rate = 3.0 / PUNCH_EXTEND
	elif _windup >= 0.0:
		# Charging: the forearm rises little by little from the elbow, from
		# hanging down to a right angle (90°) at full charge, with the upper
		# arm drawn a little back and out to the side (so it also shows when
		# walking towards or away from the camera) and the shoulder back.
		var w := _windup
		tz = lerpf(0.0, -0.3, w)
		tf = lerpf(0.15, PI * 0.5, w)
		tx = lerpf(-0.1, -0.35, w)
		tpull = lerpf(0.2, 0.8, w)
		rate = 12.0
	elif _raised:
		tz = 2.5
		rate = 14.0
	else:
		tz = lerpf(s * 0.8, -1.2 * sin(ph) + 0.6, k)
		# Coming back from a punch: soft, not a snap.
		if absf(_arm_z - tz) > 0.5 or absf(_fore_z - tf) > 0.5:
			rate = 9.0
	var a := 1.0 - exp(-rate * dt)
	_arm_z = lerpf(_arm_z, tz, a)
	_arm_x = lerpf(_arm_x, tx, a)
	_fore_z = lerpf(_fore_z, tf, a)
	_pull = lerpf(_pull, tpull, a)
	arm_r.rotation.z = _arm_z
	arm_r.rotation.x = _arm_x
	forearm_r.rotation.z = _fore_z
	# Shoulder back while charging, forward with the punch.
	arm_r.position.x = -0.08 * _pull


var _shoes: Array = []
var _feet: Array = []
## 0..1: sneaking (barefoot, not running): leaning forward, arms bent up
## in front, small careful steps.
var crouch := 0.0


## Shoe colour (the white toe caps stay white).
func set_shoe_color(c: Color) -> void:
	for i in range(0, _shoes.size(), 2):
		var m: StandardMaterial3D = _shoes[i].material_override
		m.albedo_color = c


## Barefoot (shoes lost) or not.
func set_shoes(on: bool) -> void:
	for s in _shoes:
		s.visible = on
	for f in _feet:
		f.visible = not on


## Soiled trousers after a night on the street: brown patches on the
## seat (back of the hips and thighs), yellow on the front.
var _soil: Array = []


func set_soiled(on: bool) -> void:
	for m in _soil:
		m.queue_free()
	_soil.clear()
	if not on:
		return
	var brown := Color(0.36, 0.24, 0.1)
	var yellow := Color(0.85, 0.75, 0.25)
	# On the hips (the body faces +X, so the seat is at -X).
	_soil.append(_patch(self, Vector3(-0.145, 0.99, 0), Vector3(0.012, 0.17, 0.36), brown))
	_soil.append(_patch(self, Vector3(0.145, 0.97, 0), Vector3(0.012, 0.13, 0.22), yellow))
	# On the thighs, moving with the legs.
	for leg in [leg_l, leg_r]:
		_soil.append(_patch(leg, Vector3(-0.088, -0.13, 0), Vector3(0.012, 0.24, 0.16), brown))
		_soil.append(_patch(leg, Vector3(0.088, -0.09, 0), Vector3(0.012, 0.16, 0.12), yellow))


func _patch(parent: Node3D, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Face colour: `target` mixed into the skin by `amount` (blue when cold,
## pale green when hungover).
func set_face_tint(target: Color, amount: float) -> void:
	if _head == null:
		return
	var m: StandardMaterial3D = _head.material_override
	m.albedo_color = skin_color.lerp(target, clampf(amount, 0.0, 1.0))


## Turns the head (and what is on it: hair, eyes, a cap...) by `yaw`
## radians around the neck, relative to the body.
func turn_head(yaw: float) -> void:
	if is_equal_approx(yaw, head_yaw):
		return
	var d := yaw - head_yaw
	head_yaw = yaw
	var parts: Array = _head_parts.duplicate()
	for c in get_children():
		if c.has_meta("head_extra") and not parts.has(c):
			parts.append(c)
	for c in parts:
		c.position = c.position.rotated(Vector3.UP, d)
		c.rotation.y += d


## 0 = eyes open, 1 = closed.
func set_eyes(closed: float) -> void:
	var h := 0.006 + 0.05 * clampf(closed, 0.0, 1.0)
	for lid in _eyelids:
		var bm: BoxMesh = lid.mesh
		bm.size.y = h
		lid.position.y = 1.745 - h * 0.5


## Get up from lying at `angle` (rotation.z) to standing over `time` seconds.
func rise_from(angle: float, time: float) -> void:
	rotation.z = angle
	position.y = 0.12
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "rotation:z", 0.0, time)
	tw.parallel().tween_property(self, "position:y", 0.0, time)


## Quick punch: the arm swings straight up to the front. A charged one
## (released from the bent pose) stays out a little longer.
func punch(charged := false) -> void:
	_punch_t = 0.3 if charged else 0.18
	_windup = -1.0


## 0..1 pulls the arm back for a charged punch, -1 releases it.
func set_windup(amount: float) -> void:
	_windup = amount


func raise_arm(on: bool) -> void:
	_raised = on


func lie_down() -> void:
	rotation.z = PI * 0.5
	position.y = 0.16


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
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


func _sphere(pos: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _mat(c)
	mi.position = pos
	add_child(mi)
	return mi


func _limb(pivot: Vector3, size: Vector3, c: Color, parent: Node3D = null) -> Node3D:
	var p := Node3D.new()
	p.position = pivot
	if parent != null:
		parent.add_child(p)
	else:
		add_child(p)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = Vector3(0, -size.y * 0.5, 0)
	p.add_child(mi)
	return p
