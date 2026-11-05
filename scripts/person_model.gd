extends Node3D
## Simple blocky person built from primitive meshes. Faces +X.
## The owner calls animate() with the world delta so frozen time
## also freezes the animation.

var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
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
	_box(Vector3(0, 1.22, 0), Vector3(0.28, 0.64, 0.46), shirt)
	_sphere(Vector3(0, 1.69, 0), 0.16, skin)
	_box(Vector3(-0.03, 1.81, 0), Vector3(0.28, 0.08, 0.32), hair)
	# Eyes (the face looks towards +X) and eyelids that close when tired.
	for ez in [-0.065, 0.065]:
		_box(Vector3(0.152, 1.72, ez), Vector3(0.02, 0.045, 0.045), Color(0.08, 0.08, 0.1))
		_eyelids.append(_box(Vector3(0.162, 1.74, ez), Vector3(0.02, 0.006, 0.055), skin))
	arm_l = _limb(Vector3(0, 1.5, -0.29), Vector3(0.12, 0.62, 0.12), shirt)
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
var silly_bounce := 0.0
var silly_lean := 0.0


func animate(walk_amount: float, dt: float, speed_mult := 1.0, silly := 0.0) -> void:
	_walk_amount = lerpf(_walk_amount, walk_amount, clampf(dt * 10.0, 0.0, 1.0))
	_walk_phase += dt * 9.0 * speed_mult * (1.0 - silly * 0.35)
	var ph := _walk_phase
	var s := sin(ph) * 0.55 * _walk_amount
	var k := silly * _walk_amount
	# One leg kicks high forward, the other does a little skip.
	leg_l.rotation.z = lerpf(s, maxf(0.0, sin(ph)) * 1.8 - 0.25, k)
	leg_r.rotation.z = lerpf(-s, -0.45 * sin(ph) + 0.3 * sin(ph * 2.0), k)
	arm_l.rotation.z = lerpf(-s * 0.8, 1.3 * sin(ph + 1.0) + 0.5, k)
	silly_bounce = absf(sin(ph)) * 0.18 * k
	silly_lean = (0.22 + 0.08 * sin(ph * 2.0)) * k
	forearm_r.rotation.z = 0.0
	if _punch_t > 0.0:
		# Straight arm forward (quick jab or the released charged punch).
		_punch_t -= dt
		arm_r.rotation.z = PI * 0.5
	elif _windup >= 0.0:
		# Charging: elbow bends and the arm is drawn back, the fist cocked
		# up by the shoulder; further the longer it charges.
		arm_r.rotation.z = lerpf(-0.2, -0.9, _windup)
		forearm_r.rotation.z = lerpf(1.6, 2.9, _windup)
	elif _raised:
		arm_r.rotation.z = 2.5
	else:
		arm_r.rotation.z = lerpf(s * 0.8, -1.2 * sin(ph) + 0.6, k)
		forearm_r.rotation.z = 0.15  # a relaxed little bend


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
	arm_r.rotation.z = PI * 0.5
	forearm_r.rotation.z = 0.0


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
