extends Node3D
## A hallucination after a punk's pills: something that isn't there
## floats about the street for a few seconds, glowing, bobbing and
## turning, then fades away. Kinds: a pink elephant, a giant mushroom, a
## big eye and a spinning spiral. Moves in real time (the visions don't
## care whether the world is frozen).

var kind := "elephant"
var life := 7.0
var _t := 0.0
var _mats: Array = []
var _drift := Vector3.ZERO
var _spin := 0.0
var _base_scale := 1.0


func setup(k: String, rng: RandomNumberGenerator) -> void:
	kind = k
	life = rng.randf_range(5.0, 9.0)
	_drift = Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.05, 0.15), rng.randf_range(-0.2, 0.2))
	_spin = rng.randf_range(-1.2, 1.2)
	_base_scale = rng.randf_range(0.8, 1.5)
	match kind:
		"elephant":
			_elephant(Color.from_hsv(rng.randf_range(0.88, 0.98), 0.45, 1.0))
		"mushroom":
			_mushroom(Color.from_hsv(rng.randf(), 0.8, 1.0))
		"eye":
			_eye(Color.from_hsv(rng.randf(), 0.7, 0.9))
		_:
			_spiral(rng)
	scale = Vector3.ONE * 0.01


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.6
	_mats.append(m)
	return m


func _box(pos: Vector3, size: Vector3, c: Color, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _ball(pos: Vector3, r: float, c: Color, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = _mat(c)
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _elephant(c: Color) -> void:
	_ball(Vector3(0, 0.9, 0), 0.55, c)                          # body
	_ball(Vector3(0.6, 1.2, 0), 0.35, c)                        # head
	for z in [-0.32, 0.32]:
		var ear := _box(Vector3(0.5, 1.25, z), Vector3(0.05, 0.45, 0.35), c.lightened(0.15))
		ear.rotation.y = 0.4 * signf(z)
	var trunk := _box(Vector3(0.95, 0.95, 0), Vector3(0.12, 0.55, 0.12), c)
	trunk.rotation.z = 0.5
	for p in [Vector2(0.3, -0.25), Vector2(0.3, 0.25), Vector2(-0.3, -0.25), Vector2(-0.3, 0.25)]:
		_box(Vector3(p.x, 0.3, p.y), Vector3(0.18, 0.6, 0.18), c)
	for z in [-0.15, 0.15]:
		_ball(Vector3(0.88, 1.3, z), 0.05, Color(0.05, 0.05, 0.1))
	# Tiny wings, of course.
	for z in [-0.5, 0.5]:
		var w := _box(Vector3(-0.1, 1.35, z), Vector3(0.35, 0.03, 0.25), Color(1, 1, 1, 0.8))
		w.set_meta("wing", z)


func _mushroom(c: Color) -> void:
	_box(Vector3(0, 0.6, 0), Vector3(0.3, 1.2, 0.3), Color(0.95, 0.92, 0.85))
	var cap := _ball(Vector3(0, 1.3, 0), 0.75, c)
	cap.scale = Vector3(1.0, 0.45, 1.0)
	for i in 7:
		var a := TAU * float(i) / 7.0
		_ball(Vector3(cos(a) * 0.45, 1.5, sin(a) * 0.45), 0.08, Color(1, 1, 1))


func _eye(c: Color) -> void:
	var white := _ball(Vector3(0, 1.4, 0), 0.6, Color(1, 1, 1, 0.95))
	white.scale = Vector3(1.0, 0.75, 0.3)
	var iris := _ball(Vector3(0, 1.4, 0.15), 0.3, c)
	iris.scale = Vector3(1.0, 1.0, 0.3)
	var pupil := _ball(Vector3(0, 1.4, 0.24), 0.14, Color(0.02, 0.02, 0.05))
	pupil.scale = Vector3(1.0, 1.0, 0.3)


func _spiral(rng: RandomNumberGenerator) -> void:
	var h0 := rng.randf()
	for i in 40:
		var a := float(i) * 0.45
		var r := 0.08 + float(i) * 0.022
		_ball(Vector3(cos(a) * r, 1.4 + sin(a) * r, 0), 0.06, Color.from_hsv(fmod(h0 + float(i) * 0.025, 1.0), 0.8, 1.0))


func _process(delta: float) -> void:
	_t += delta
	# Swell in, wobble, shrink and fade out.
	var k_in := clampf(_t / 0.8, 0.0, 1.0)
	var k_out := clampf((life - _t) / 1.5, 0.0, 1.0)
	var wob := 1.0 + 0.08 * sin(_t * 3.1)
	scale = Vector3(wob, 1.0 / wob, wob) * _base_scale * k_in * (0.6 + 0.4 * k_out)
	position += _drift * delta
	position.y += sin(_t * 1.7) * 0.25 * delta
	rotation.y += _spin * delta * (3.0 if kind == "spiral" else 1.0)
	if kind == "spiral":
		rotation.z += delta * 2.5
	for c in get_children():
		if c.has_meta("wing"):
			c.rotation.x = sin(_t * 18.0) * 0.7 * signf(float(c.get_meta("wing")))
	var a := 0.75 * minf(k_in, k_out)
	for m in _mats:
		m.albedo_color.a = a
		# Colours drift as you look at them.
		m.albedo_color.h = fmod(m.albedo_color.h + delta * 0.05, 1.0)
	if _t >= life:
		queue_free()
