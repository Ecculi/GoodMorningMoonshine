extends RefCounted
## Builds the 3D scenery for one block. The look is seeded by the block,
## so the same block always looks the same.
##
## Layout (X runs along the street, the camera looks towards -Z):
##   z -8 .. -20  buildings on the far side (or the sea on Rantakatu)
##   z -8 .. -5   far sidewalk
##   z -5 .. 2.5  street
##   z 2.5 .. 5.8 near sidewalk, low hedges in the foreground
## The crossing streets are at x = ±16 .. ±23.

const CityMap = preload("res://scripts/city_map.gd")
const PersonModel = preload("res://scripts/person_model.gd")

const BLOCK_HALF := 16.0
const CROSS_HALF := 23.0
const STREET_Z := -1.25

const FACADE_COLORS := [Color(0.93, 0.83, 0.55), Color(0.85, 0.6, 0.45), Color(0.78, 0.78, 0.74),
	Color(0.72, 0.45, 0.36), Color(0.9, 0.9, 0.85), Color(0.62, 0.7, 0.72), Color(0.88, 0.72, 0.5)]


## `home_x` is the x of the player's home door if home is in this block.
static func build(seg: Vector3i, home_x := INF, home_type := "flat") -> Node3D:
	var root := Node3D.new()
	root.name = "Block"
	var rng := RandomNumberGenerator.new()
	rng.seed = CityMap.seed_of(seg)
	var sea := CityMap.far_side_is_sea(seg)
	_street(root, seg)
	if sea:
		_sea(root)
	else:
		_buildings(root, rng, home_x)
		if home_x != INF:
			_home_door(root, home_x, home_type)
	_props(root, rng, sea)
	_signs(root, seg)
	return root


static func _street(root: Node3D, seg: Vector3i) -> void:
	var asphalt := Color(0.22, 0.23, 0.25)
	var walk := Color(0.5, 0.48, 0.45)
	_box(root, Vector3(0, -0.2, -10), Vector3(160, 0.2, 100), Color(0.4, 0.4, 0.4))
	_box(root, Vector3(0, -0.05, STREET_Z), Vector3(BLOCK_HALF * 2, 0.1, 7.5), asphalt)
	for s in [-1, 1]:
		_box(root, Vector3(s * 41.5, -0.05, STREET_Z), Vector3(37, 0.1, 7.5), asphalt)
		# Crossing street: it only continues where there is a street on the map.
		var up := CityMap.can_turn(seg, s > 0, true)
		var down := CityMap.can_turn(seg, s > 0, false)
		var z_far := -40.0 if up else -5.0
		var z_near := 25.0 if down else 2.5
		var cx: float = s * (BLOCK_HALF + CROSS_HALF) * 0.5
		_box(root, Vector3(cx, -0.05, (z_far + z_near) * 0.5), Vector3(CROSS_HALF - BLOCK_HALF, 0.1, z_near - z_far), asphalt)
		if not up:
			_box(root, Vector3(cx, 0.06, -6.5), Vector3(CROSS_HALF - BLOCK_HALF, 0.12, 3.0), walk)
		if not down:
			_box(root, Vector3(cx, 0.06, 4.15), Vector3(CROSS_HALF - BLOCK_HALF, 0.12, 3.3), walk)
		for i in 9:
			_box(root, Vector3(s * (BLOCK_HALF + 1.6), 0.005, -4.6 + i * 0.85), Vector3(2.4, 0.02, 0.45), Color(0.92, 0.92, 0.9))
	var x := -45.0
	while x < 45.0:
		if absf(x) < BLOCK_HALF - 1.0 or absf(x) > CROSS_HALF + 1.0:
			_box(root, Vector3(x, 0.005, STREET_Z), Vector3(1.6, 0.02, 0.12), Color(0.9, 0.85, 0.6))
		x += 3.2
	for zc in [[-6.5, 3.0], [4.15, 3.3]]:
		_box(root, Vector3(0, 0.06, zc[0]), Vector3(BLOCK_HALF * 2, 0.12, zc[1]), walk)
		for s in [-1, 1]:
			_box(root, Vector3(s * 41.5, 0.06, zc[0]), Vector3(37, 0.12, zc[1]), walk)


static func _sea(root: Node3D) -> void:
	var water := _box(root, Vector3(0, -0.08, -40), Vector3(160, 0.1, 64), Color(0.16, 0.36, 0.5))
	var m: StandardMaterial3D = water.material_override
	m.roughness = 0.2
	# Railing along the shore.
	_box(root, Vector3(0, 0.9, -7.9), Vector3(90, 0.06, 0.06), Color(0.2, 0.2, 0.22))
	var x := -45.0
	while x <= 45.0:
		_box(root, Vector3(x, 0.5, -7.9), Vector3(0.06, 0.9, 0.06), Color(0.2, 0.2, 0.22))
		x += 2.0


## Shops in this block are listed in the root's "shops" meta:
## [{"type": "kiosk" or "bar", "x": door x}].
static func _buildings(root: Node3D, rng: RandomNumberGenerator, home_x: float) -> void:
	root.set_meta("shops", [])
	var x := -BLOCK_HALF
	var kiosk_idx := rng.randi() % 4 if rng.randf() < 0.5 else -1
	var bar_idx := rng.randi() % 4 if rng.randf() < 0.4 else -1
	if bar_idx == kiosk_idx:
		bar_idx = -1
	var idx := 0
	while x < BLOCK_HALF - 0.5:
		var w := minf(rng.randf_range(5.0, 8.0), BLOCK_HALF - x)
		var h := rng.randf_range(9.0, 16.0)
		var shop := ""
		if idx == kiosk_idx:
			shop = "kiosk"
		elif idx == bar_idx:
			shop = "bar"
		# Never a shop door right next to the home door.
		var door_x := x + w * 0.5 + w * 0.3
		if home_x != INF and absf(door_x - home_x) < 2.5:
			shop = ""
		_building(root, Vector3(x + w * 0.5, 0, -8.0), w, h, FACADE_COLORS[rng.randi() % FACADE_COLORS.size()], shop)
		x += w
		idx += 1
	for s in [-1, 1]:
		_building(root, Vector3(s * (CROSS_HALF + 9.0), 0, -8.0), 18.0, rng.randf_range(10.0, 15.0),
			FACADE_COLORS[rng.randi() % FACADE_COLORS.size()], "")
	for i in 8:
		_box(root, Vector3(-42.0 + i * 12.0, 9.0, -34.0), Vector3(11.0, 18.0 + rng.randf_range(-3, 4), 8.0), Color(0.62, 0.64, 0.68))


static func _building(root: Node3D, base: Vector3, w: float, h: float, col: Color, shop: String) -> void:
	var depth := 12.0
	_box(root, base + Vector3(0, h * 0.5, -depth * 0.5), Vector3(w, h, depth), col)
	_box(root, base + Vector3(0, h + 0.15, -depth * 0.5), Vector3(w + 0.2, 0.3, depth + 0.2), col.darkened(0.35))
	var glass := Color(0.22, 0.3, 0.4)
	var floors := int((h - 3.5) / 3.0)
	var cols := maxi(1, int((w - 1.0) / 1.7))
	var step := (w - 1.0) / cols
	for f in floors:
		for c in cols:
			var wx := base.x - w * 0.5 + 0.5 + step * (c + 0.5)
			_box(root, Vector3(wx, 4.8 + f * 3.0, base.z + 0.03), Vector3(0.9, 1.4, 0.08), glass)
	_box(root, Vector3(base.x - w * 0.15, 1.5, base.z + 0.03), Vector3(w * 0.5, 1.8, 0.08), Color(0.3, 0.38, 0.45))
	_box(root, Vector3(base.x + w * 0.3, 1.1, base.z + 0.04), Vector3(1.1, 2.2, 0.1), Color(0.35, 0.22, 0.15))
	if shop != "":
		var door_x := base.x + w * 0.3
		var sign_col := Color(0.85, 0.15, 0.15) if shop == "kiosk" else Color(0.35, 0.12, 0.4)
		_box(root, Vector3(base.x - w * 0.15, 2.8, base.z + 0.08), Vector3(w * 0.55, 0.6, 0.1), sign_col)
		var key := "SIGN_KIOSK" if shop == "kiosk" else "SIGN_BAR"
		var l := _label(TranslationServer.translate(key), 72, 0.006)
		l.position = Vector3(base.x - w * 0.15, 2.8, base.z + 0.15)
		root.add_child(l)
		# Lit doorway so shops are easy to spot.
		var lit := _box(root, Vector3(door_x, 1.1, base.z + 0.06), Vector3(1.1, 2.2, 0.1), Color(0.95, 0.8, 0.45))
		var lm: StandardMaterial3D = lit.material_override
		lm.emission_enabled = true
		lm.emission = Color(0.9, 0.7, 0.35)
		lm.emission_energy_multiplier = 0.6
		if shop == "bar":
			# The bouncer stands next to the bar door, facing the street.
			var b = PersonModel.new(Color(0.08, 0.08, 0.09), Color(0.08, 0.08, 0.09), Color(0.85, 0.68, 0.55), Color(0.1, 0.1, 0.1), 1.12)
			b.position = Vector3(door_x + 1.0, 0.12, -7.3)
			b.rotation.y = -PI * 0.5
			root.add_child(b)
		var shops: Array = root.get_meta("shops")
		shops.append({"type": shop, "x": door_x})


## Home door. Flat: green door, doormat, warm lamp. Basement: low grey
## metal door down a few steps, with a padlock. Friend: blue door with a
## doorbell.
static func _home_door(root: Node3D, x: float, home_type: String) -> void:
	if home_type == "basement":
		_box(root, Vector3(x, 0.13, -7.25), Vector3(1.3, 0.04, 1.0), Color(0.18, 0.18, 0.2))
		_box(root, Vector3(x, 0.75, -7.88), Vector3(1.0, 1.5, 0.12), Color(0.45, 0.47, 0.5))
		_box(root, Vector3(x + 0.3, 0.8, -7.8), Vector3(0.12, 0.16, 0.06), Color(0.9, 0.75, 0.25))
		var bulb := _sphere(root, Vector3(x, 1.75, -7.78), 0.08, Color(1.0, 0.9, 0.6))
		var bm: StandardMaterial3D = bulb.material_override
		bm.emission_enabled = true
		bm.emission = Color(1.0, 0.85, 0.5)
		return
	if home_type == "friend":
		_box(root, Vector3(x, 1.15, -7.9), Vector3(1.3, 2.3, 0.14), Color(0.85, 0.85, 0.85))
		_box(root, Vector3(x, 1.1, -7.84), Vector3(1.0, 2.1, 0.12), Color(0.2, 0.35, 0.7))
		_box(root, Vector3(x + 0.75, 1.3, -7.82), Vector3(0.12, 0.18, 0.06), Color(0.95, 0.95, 0.9))
		_box(root, Vector3(x + 0.75, 1.3, -7.78), Vector3(0.05, 0.05, 0.04), Color(0.9, 0.2, 0.2))
		return
	_box(root, Vector3(x, 1.15, -7.9), Vector3(1.3, 2.3, 0.14), Color(0.92, 0.9, 0.82))
	_box(root, Vector3(x, 1.1, -7.84), Vector3(1.0, 2.1, 0.12), Color(0.15, 0.55, 0.3))
	_box(root, Vector3(x + 0.35, 1.1, -7.76), Vector3(0.08, 0.08, 0.06), Color(0.9, 0.8, 0.3))
	_box(root, Vector3(x, 0.14, -7.3), Vector3(1.0, 0.03, 0.6), Color(0.55, 0.35, 0.2))
	var lamp := _sphere(root, Vector3(x, 2.55, -7.75), 0.12, Color(1.0, 0.85, 0.4))
	var m: StandardMaterial3D = lamp.material_override
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.4)
	m.emission_energy_multiplier = 2.0


static func _props(root: Node3D, rng: RandomNumberGenerator, sea: bool) -> void:
	var x := -40.0
	while x <= 40.0:
		if absf(absf(x) - (BLOCK_HALF + CROSS_HALF) * 0.5) > 4.0:
			_cyl(root, Vector3(x, 2.0, 5.5), 0.07, 4.0, Color(0.2, 0.22, 0.25))
			_box(root, Vector3(x, 4.05, 5.2), Vector3(0.25, 0.12, 0.7), Color(0.2, 0.22, 0.25))
		x += 10.0
	if not sea:
		for i in rng.randi_range(2, 4):
			var tx := rng.randf_range(-BLOCK_HALF + 1.5, BLOCK_HALF - 1.5)
			_cyl(root, Vector3(tx, 1.2, -7.3), 0.15, 2.4, Color(0.35, 0.25, 0.18))
			_sphere(root, Vector3(tx, 3.3, -7.3), 1.3, Color(0.25, 0.5, 0.24))
	for hx in [-30.0, -20.0, -4.0, 4.0, 20.0, 30.0]:
		_box(root, Vector3(hx, 0.35, 7.0), Vector3(3.0, 0.7, 0.8), Color(0.22, 0.45, 0.22))
	for i in rng.randi_range(0, 2):
		var bx := rng.randf_range(-12.0, 12.0)
		_box(root, Vector3(bx, 0.45, 5.4), Vector3(1.8, 0.1, 0.5), Color(0.45, 0.3, 0.2))
		_box(root, Vector3(bx, 0.22, 5.4), Vector3(1.6, 0.44, 0.08), Color(0.2, 0.2, 0.2))
	for i in rng.randi_range(1, 3):
		_cyl(root, Vector3(rng.randf_range(-14.0, 14.0), 0.5, -7.5), 0.3, 0.8, Color(0.2, 0.35, 0.25))


## Blue street name signs on poles at both corners of the far sidewalk:
## this street's name and the crossing street's name.
static func _signs(root: Node3D, seg: Vector3i) -> void:
	for s in [-1, 1]:
		var px: float = s * (BLOCK_HALF - 0.4)
		_cyl(root, Vector3(px, 1.5, -5.4), 0.05, 3.0, Color(0.25, 0.27, 0.3))
		_sign(root, CityMap.street_name(seg), Vector3(px - s * 1.1, 2.75, -5.36))
		_sign(root, CityMap.cross_name(seg, s > 0), Vector3(px + s * 1.1, 2.3, -5.36))


static func _sign(root: Node3D, text: String, pos: Vector3) -> void:
	var l := _label(text, 48, 0.008)
	l.position = pos + Vector3(0, 0, 0.04)
	l.set_meta("real_text", text)
	l.add_to_group("street_sign")
	root.add_child(l)
	var w := text.length() * 0.25 + 0.3
	_box(root, pos, Vector3(w, 0.42, 0.05), Color(0.1, 0.3, 0.7))


static func _label(text: String, size: int, pixel: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = Color.WHITE
	l.outline_size = 0
	return l


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


static func _box(root: Node3D, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	root.add_child(mi)
	return mi


static func _cyl(root: Node3D, pos: Vector3, r: float, h: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = _mat(c)
	mi.position = pos
	root.add_child(mi)
	return mi


static func _sphere(root: Node3D, pos: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = _mat(c)
	mi.position = pos
	root.add_child(mi)
	return mi
