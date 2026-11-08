extends Node3D
## Broken glass on the street where a thrown bottle smashed. Stays in the
## block for the rest of the day. Bad news for anything on wheels: an
## e-scooter crashes, a bike or a car gets a flat tyre. Hurts bare feet.

const RADIUS := 0.55

var main


func setup(rng: RandomNumberGenerator, col: Color) -> void:
	for i in 14:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.04, 0.12), 0.012, rng.randf_range(0.03, 0.08))
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(col.r, col.g, col.b, 0.85).lightened(0.25)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = 0.3
		m.roughness = 0.05
		m.emission_enabled = true
		m.emission = col.lightened(0.5) * 0.25
		mi.material_override = m
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * RADIUS
		mi.position = Vector3(cos(a) * r, 0.006, sin(a) * r)
		mi.rotation.y = rng.randf() * TAU
		add_child(mi)
	# The bottle's neck, a bigger piece.
	var neck := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.035
	cm.height = 0.12
	neck.mesh = cm
	var nm := StandardMaterial3D.new()
	nm.albedo_color = Color(col.r, col.g, col.b, 0.9)
	nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nm.roughness = 0.1
	neck.material_override = nm
	neck.rotation.z = PI * 0.5
	neck.rotation.y = rng.randf() * TAU
	neck.position = Vector3(rng.randf_range(-0.2, 0.2), 0.03, rng.randf_range(-0.2, 0.2))
	add_child(neck)


## Is `p` (on the ground plane) on the shards? `extra` widens it (a car).
func covers(p: Vector3, extra := 0.0) -> bool:
	var r := RADIUS + extra
	return Vector2(p.x - position.x, p.z - position.z).length_squared() < r * r
