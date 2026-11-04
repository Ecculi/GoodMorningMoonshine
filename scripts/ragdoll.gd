extends Node3D
## A floppy physics copy of a PersonModel ("rag doll") for falls and hits:
## body parts are rigid boxes joined with pin joints. The parts are
## top-level, so they move freely while this node stays with its owner.
## Physics pauses while the game world is frozen.

const PART_LAYER := 2
const WORLD_LAYER := 1

var parts: Array = []
var torso: RigidBody3D
var _frozen := false


## Builds the rag doll in the model's current place and pose and gives it
## a push (`velocity`, metres per second).
func build(model: Node3D, velocity: Vector3) -> void:
	var xf: Transform3D = model.global_transform
	var s: float = model.scale.x
	var shirt: Color = model.shirt_color
	var pants: Color = model.pants_color
	var skin: Color = model.skin_color
	torso = _part(xf, Vector3(0, 1.22, 0), Vector3(0.28, 0.64, 0.46), shirt, 3.0, s, velocity)
	# The head sits rigidly on the torso (a loose neck let it sink into the
	# body).
	_dress_head(torso, model, s, Vector3(0, 0.47, 0) * s, skin)
	var leg_l := _part(xf, Vector3(0, 0.46, -0.1), Vector3(0.17, 0.88, 0.17), pants, 0.9, s, velocity)
	var leg_r := _part(xf, Vector3(0, 0.46, 0.1), Vector3(0.17, 0.88, 0.17), pants, 0.9, s, velocity)
	var arm_l := _part(xf, Vector3(0, 1.19, -0.29), Vector3(0.12, 0.62, 0.12), shirt, 0.6, s, velocity)
	var arm_r := _part(xf, Vector3(0, 1.19, 0.29), Vector3(0.12, 0.62, 0.12), shirt, 0.6, s, velocity)
	_joint(xf, Vector3(0, 0.9, -0.1), torso, leg_l)
	_joint(xf, Vector3(0, 0.9, 0.1), torso, leg_r)
	_joint(xf, Vector3(0, 1.5, -0.29), torso, arm_l)
	_joint(xf, Vector3(0, 1.5, 0.29), torso, arm_r)
	# A little spin makes it look less stiff.
	torso.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-2, 2), randf_range(-3, 3))


## Make the head look like the walking model's: round, with hair, eyes and
## any hat (police cap).
func _dress_head(body: RigidBody3D, model: Node3D, s: float, at: Vector3, skin: Color) -> void:
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16 * s
	sm.height = 0.32 * s
	sm.radial_segments = 12
	sm.rings = 6
	head.mesh = sm
	var m0 := StandardMaterial3D.new()
	m0.albedo_color = skin
	head.material_override = m0
	head.position = at
	body.add_child(head)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.16 * s
	cs.shape = sph
	cs.position = at
	body.add_child(cs)
	_head_mesh(body, at + Vector3(-0.03, 0.12, 0) * s, Vector3(0.28, 0.08, 0.32) * s, model.hair_color)
	for ez in [-0.065, 0.065]:
		_head_mesh(body, at + Vector3(0.152, 0.03, ez) * s, Vector3(0.02, 0.045, 0.045) * s, Color(0.08, 0.08, 0.1))
	for c in model.get_children():
		if c is MeshInstance3D and c.has_meta("head_extra"):
			var bm: BoxMesh = c.mesh
			var m: StandardMaterial3D = c.material_override
			_head_mesh(body, at + (c.position - Vector3(0, 1.69, 0)) * s, bm.size * s, m.albedo_color)


func _head_mesh(head: RigidBody3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	mi.material_override = m
	mi.position = pos
	head.add_child(mi)


## Where the model's feet should go and which way it should lie (rotation.z
## for a model facing `facing`) so that getting up starts from the same
## pose the rag doll ended in.
func lying_pose(facing: int, s: float) -> Dictionary:
	var t := torso_position()
	var up: Vector3 = torso.global_transform.basis.y
	var head_x := 1.0 if up.x >= 0.0 else -1.0
	var feet := Vector3(t.x - head_x * 1.22 * s, 0.0, t.z)
	# Model faces +x when facing > 0; head towards local -x = rotation +90°.
	var local_head := head_x * float(facing)
	return {"feet": feet, "angle": PI * 0.5 if local_head < 0.0 else -PI * 0.5}


func torso_position() -> Vector3:
	return torso.global_position if torso != null else global_position


## Velocities saved while frozen, so the fall continues where it stopped.
var _saved: Array = []


func _physics_process(_delta: float) -> void:
	var freeze := GameState.world_dt <= 0.0 and not GameState.over
	if freeze == _frozen:
		return
	_frozen = freeze
	if freeze:
		_saved.clear()
		for p in parts:
			_saved.append([p.linear_velocity, p.angular_velocity])
			p.freeze = true
	else:
		for i in parts.size():
			parts[i].freeze = false
			if i < _saved.size():
				parts[i].linear_velocity = _saved[i][0]
				parts[i].angular_velocity = _saved[i][1]


func _part(xf: Transform3D, local: Vector3, size: Vector3, col: Color, mass: float, s: float, velocity: Vector3) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.top_level = true
	rb.mass = mass
	rb.linear_damp = 0.4
	rb.angular_damp = 2.0
	rb.collision_layer = PART_LAYER
	rb.collision_mask = WORLD_LAYER
	rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size * s
	cs.shape = shape
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size * s
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	mi.material_override = m
	rb.add_child(mi)
	add_child(rb)
	rb.global_transform = Transform3D(xf.basis.orthonormalized(), xf * local)
	rb.linear_velocity = velocity + Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.5), randf_range(-0.5, 0.5))
	parts.append(rb)
	return rb


func _joint(xf: Transform3D, local: Vector3, a: RigidBody3D, b: RigidBody3D) -> void:
	var j := PinJoint3D.new()
	add_child(j)
	j.top_level = true
	j.global_position = xf * local
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)
