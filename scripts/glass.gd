extends Node3D
## Broken glass on the street where a thrown bottle smashed. Stays in the
## block for the rest of the day. Bad news for anything on wheels: an
## e-scooter crashes, a bike or a car gets a flat tyre. Hurts bare feet.

const RADIUS := 0.55

var main


## Shared by all shards of the same colour: making new transparent,
## glinting materials for every bottle made the game hitch (above all in
## the browser), so they are made once per colour and reused, like the
## meshes (the size varies by scale).
static var _shard_mats := {}
static var _neck_mats := {}
static var _shard_mesh: BoxMesh
static var _neck_mesh: CylinderMesh


static func shard_material(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if not _shard_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(col.r, col.g, col.b, 0.85).lightened(0.25)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = 0.3
		m.roughness = 0.05
		m.emission_enabled = true
		m.emission = col.lightened(0.5) * 0.25
		_shard_mats[key] = m
	return _shard_mats[key]


static func neck_material(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if not _neck_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(col.r, col.g, col.b, 0.9)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.1
		_neck_mats[key] = m
	return _neck_mats[key]


static func _meshes() -> void:
	if _shard_mesh == null:
		_shard_mesh = BoxMesh.new()
		_shard_mesh.size = Vector3(1, 0.012, 1)
		_neck_mesh = CylinderMesh.new()
		_neck_mesh.top_radius = 0.025
		_neck_mesh.bottom_radius = 0.035
		_neck_mesh.height = 0.12
		_neck_mesh.radial_segments = 10
		_neck_mesh.rings = 1


func setup(rng: RandomNumberGenerator, col: Color) -> void:
	_meshes()
	var sm := shard_material(col)
	for i in 14:
		var mi := MeshInstance3D.new()
		mi.mesh = _shard_mesh
		mi.material_override = sm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3(rng.randf_range(0.04, 0.12), 1.0, rng.randf_range(0.03, 0.08))
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * RADIUS
		mi.position = Vector3(cos(a) * r, 0.006, sin(a) * r)
		mi.rotation.y = rng.randf() * TAU
		add_child(mi)
	# The bottle's neck, a bigger piece.
	var neck := MeshInstance3D.new()
	neck.mesh = _neck_mesh
	neck.material_override = neck_material(col)
	neck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	neck.rotation.z = PI * 0.5
	neck.rotation.y = rng.randf() * TAU
	neck.position = Vector3(rng.randf_range(-0.2, 0.2), 0.03, rng.randf_range(-0.2, 0.2))
	add_child(neck)


## Is `p` (on the ground plane) on the shards? `extra` widens it (a car).
func covers(p: Vector3, extra := 0.0) -> bool:
	var r := RADIUS + extra
	return Vector2(p.x - position.x, p.z - position.z).length_squared() < r * r
