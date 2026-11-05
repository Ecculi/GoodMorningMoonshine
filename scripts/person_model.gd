extends Node3D
## Simple blocky person built from primitive meshes. Faces +X.
## The owner calls animate() with the world delta so frozen time
## also freezes the animation.

var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var hand: Node3D

var _walk_phase := 0.0
var _walk_amount := 0.0
var _punch_t := 0.0
var _raised := false
var _windup := -1.0


func _init(shirt: Color, pants: Color, skin: Color, hair: Color, size := 1.0) -> void:
	scale = Vector3.ONE * size
	leg_l = _limb(Vector3(0, 0.9, -0.1), Vector3(0.17, 0.88, 0.17), pants)
	leg_r = _limb(Vector3(0, 0.9, 0.1), Vector3(0.17, 0.88, 0.17), pants)
	_box(Vector3(0, 1.22, 0), Vector3(0.28, 0.64, 0.46), shirt)
	_sphere(Vector3(0, 1.69, 0), 0.16, skin)
	_box(Vector3(-0.03, 1.81, 0), Vector3(0.28, 0.08, 0.32), hair)
	arm_l = _limb(Vector3(0, 1.5, -0.29), Vector3(0.12, 0.62, 0.12), shirt)
	arm_r = _limb(Vector3(0, 1.5, 0.29), Vector3(0.12, 0.62, 0.12), shirt)
	hand = Node3D.new()
	hand.position = Vector3(0, -0.66, 0)
	arm_r.add_child(hand)


func animate(walk_amount: float, dt: float, speed_mult := 1.0) -> void:
	_walk_amount = lerpf(_walk_amount, walk_amount, clampf(dt * 10.0, 0.0, 1.0))
	_walk_phase += dt * 9.0 * speed_mult
	var s := sin(_walk_phase) * 0.55 * _walk_amount
	leg_l.rotation.z = s
	leg_r.rotation.z = -s
	arm_l.rotation.z = -s * 0.8
	if _punch_t > 0.0:
		_punch_t -= dt
		arm_r.rotation.z = PI * 0.5
	elif _windup >= 0.0:
		# Arm pulled back behind the body, further the longer it charges.
		arm_r.rotation.z = lerpf(-0.4, -1.4, _windup)
	elif _raised:
		arm_r.rotation.z = 2.5
	else:
		arm_r.rotation.z = s * 0.8


func punch() -> void:
	_punch_t = 0.18
	arm_r.rotation.z = PI * 0.5


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


func _limb(pivot: Vector3, size: Vector3, c: Color) -> Node3D:
	var p := Node3D.new()
	p.position = pivot
	add_child(p)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = Vector3(0, -size.y * 0.5, 0)
	p.add_child(mi)
	return p
