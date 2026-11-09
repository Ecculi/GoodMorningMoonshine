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
## `booth`: a politician's election stall on the far sidewalk today.
## `checkpoint`: a police breath test across the middle of the block.
static func build(seg: Vector3i, home_x := INF, home_type := "flat", booth := false, checkpoint := false) -> Node3D:
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
		if seg == CityMap.police_station():
			_police_station(root)
		if home_x != INF:
			_home_door(root, home_x, home_type)
	# Doors on the far side; bins, trees (and beggars) keep clear of them so
	# the action button never mixes up a door and a bin.
	var doors: Array = []
	for sh in root.get_meta("shops", []):
		doors.append(sh["x"])
	if home_x != INF:
		doors.append(home_x)
	if seg == CityMap.police_station():
		doors.append(CityMap.police_door_x())
	root.set_meta("doors", doors)
	if booth and not sea:
		var bx := clear_of_doors(root, rng, -11.0, 11.0)
		if not is_nan(bx):
			_booth(root, bx)
			doors.append(bx)  # bins keep clear of it like of a door
			root.set_meta("booth", bx)
	_props(root, rng, sea)
	if checkpoint:
		_checkpoint(root)
	_signs(root, seg)
	_roadworks(root, seg, rng)
	return root


## Where the way on is shut: at the end of the map a row of site fences
## with roadworks signs; a block closed for roadworks also gets cones, a
## dug-up hole and an excavator behind the fence. Also across a side
## street that is closed.
const FENCE_X := 21.8
const FENCE_UP_Z := -8.3
const FENCE_DOWN_Z := 6.3


static func _roadworks(root: Node3D, seg: Vector3i, rng: RandomNumberGenerator) -> void:
	for s in [-1, 1]:
		var nxt := CityMap.next_along(seg, s)
		if not CityMap.is_open(nxt):
			_fence_line(root, Vector3(s * FENCE_X, 0, -7.6), Vector3(s * FENCE_X, 0, 5.6))
			_roadwork_sign(root, Vector3(s * (FENCE_X - 0.5), 0, 2.2))
			if CityMap.is_valid(nxt):
				_site(root, Vector3(s * (FENCE_X + 6.0), 0, STREET_Z), rng, s)
				for i in 5:
					_cone(root, Vector3(s * (FENCE_X - 1.2), 0, -4.4 + i * 1.6))
		var cx: float = s * (BLOCK_HALF + CROSS_HALF) * 0.5
		for up in [true, false]:
			if CityMap.has_turn(seg, s > 0, up) and not CityMap.can_turn(seg, s > 0, up):
				var z: float = FENCE_UP_Z if up else FENCE_DOWN_Z
				_fence_line(root, Vector3(cx - 3.6, 0, z), Vector3(cx + 3.6, 0, z))
				_roadwork_sign(root, Vector3(cx + 2.4, 0, z + (0.5 if up else -0.5)))
				for i in 3:
					_cone(root, Vector3(cx - 2.0 + i * 2.0, 0, z + (1.0 if up else -1.0)))
				if up:
					_site(root, Vector3(cx, 0, z - 5.0), rng, s)


## Temporary site fence panels (mesh fence on concrete feet) from a to b.
static func _fence_line(root: Node3D, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var n := maxi(1, int(ceil(length / 2.2)))
	var along := (b - a) / float(n)
	var ang := atan2(-along.z, along.x)
	for i in n:
		var c := a + along * (i + 0.5)
		var holder := Node3D.new()
		holder.position = c
		holder.rotation.y = ang
		root.add_child(holder)
		var w := along.length()
		var mesh := _box(holder, Vector3(0, 1.0, 0), Vector3(w - 0.05, 1.7, 0.03), Color(0.75, 0.78, 0.8, 0.55))
		var mm: StandardMaterial3D = mesh.material_override
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for e in [-0.5, 0.5]:
			_box(holder, Vector3(e * w, 1.0, 0), Vector3(0.05, 1.8, 0.05), Color(0.6, 0.62, 0.65))
			_box(holder, Vector3(e * w, 0.08, 0), Vector3(0.22, 0.16, 0.6), Color(0.55, 0.55, 0.52))
		# Red and white striped board along the fence.
		var stripes := 4
		for k in stripes:
			var sx := -w * 0.5 + (k + 0.5) * w / stripes
			_box(holder, Vector3(sx, 0.75, 0.04), Vector3(w / stripes, 0.2, 0.03),
				Color(0.85, 0.12, 0.1) if k % 2 == 0 else Color(0.95, 0.95, 0.95))


static func _cone(root: Node3D, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.17
	cm.height = 0.55
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.45, 0.05)
	mi.material_override = m
	mi.position = pos + Vector3(0, 0.3, 0)
	root.add_child(mi)
	_box(root, pos + Vector3(0, 0.36, 0), Vector3(0.24, 0.07, 0.24), Color(0.95, 0.95, 0.95))
	_box(root, pos + Vector3(0, 0.02, 0), Vector3(0.38, 0.04, 0.38), Color(0.1, 0.1, 0.1))


## Triangular roadworks warning sign on a post (red edge, white inside,
## a little black digger figure).
static func _roadwork_sign(root: Node3D, pos: Vector3) -> void:
	_box(root, pos + Vector3(0, 0.75, 0), Vector3(0.06, 1.5, 0.06), Color(0.55, 0.56, 0.58))
	var outer := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.8, 0.7, 0.04)
	outer.mesh = pm
	var om := StandardMaterial3D.new()
	om.albedo_color = Color(0.85, 0.1, 0.1)
	outer.material_override = om
	outer.position = pos + Vector3(0, 1.75, 0.04)
	root.add_child(outer)
	var inner := MeshInstance3D.new()
	var pm2 := PrismMesh.new()
	pm2.size = Vector3(0.56, 0.48, 0.04)
	inner.mesh = pm2
	var im := StandardMaterial3D.new()
	im.albedo_color = Color(1.0, 0.85, 0.2)
	inner.material_override = im
	inner.position = pos + Vector3(0, 1.69, 0.07)
	root.add_child(inner)
	_box(root, pos + Vector3(0, 1.62, 0.1), Vector3(0.05, 0.16, 0.02), Color(0.05, 0.05, 0.05))
	_box(root, pos + Vector3(0.06, 1.58, 0.1), Vector3(0.12, 0.03, 0.02), Color(0.05, 0.05, 0.05))


## A dug-up patch of street with a pile of earth and an excavator.
static func _site(root: Node3D, pos: Vector3, rng: RandomNumberGenerator, s: int) -> void:
	_box(root, pos + Vector3(0, 0.0, 0), Vector3(5.0, 0.04, 3.4), Color(0.32, 0.24, 0.17))
	var pile := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.3
	sm.height = 1.4
	pile.mesh = sm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.4, 0.3, 0.2)
	pmat.roughness = 1.0
	pile.material_override = pmat
	pile.position = pos + Vector3(rng.randf_range(-1.5, 1.5), 0.0, -2.2)
	root.add_child(pile)
	# Excavator: tracks, body, cab, boom and dipper with a bucket in the hole.
	var ex := Node3D.new()
	ex.position = pos + Vector3(s * 1.0, 0, 1.6)
	ex.rotation.y = 0.0 if s < 0 else PI
	root.add_child(ex)
	var yellow := Color(0.95, 0.72, 0.1)
	for tz in [-0.75, 0.75]:
		_box(ex, Vector3(0, 0.35, tz), Vector3(3.0, 0.7, 0.55), Color(0.12, 0.12, 0.12))
	_box(ex, Vector3(0.2, 1.05, 0), Vector3(2.4, 0.7, 1.9), yellow)
	_box(ex, Vector3(-0.35, 1.85, -0.45), Vector3(1.1, 1.0, 0.95), yellow)
	var glass := _box(ex, Vector3(0.22, 1.95, -0.45), Vector3(0.04, 0.6, 0.8), Color(0.3, 0.4, 0.5))
	glass.position.x = 0.22
	var boom := _box(ex, Vector3(1.75, 2.05, 0.35), Vector3(2.4, 0.3, 0.3), yellow)
	boom.rotation.z = 0.55
	var dipper := _box(ex, Vector3(3.05, 1.35, 0.35), Vector3(0.25, 1.9, 0.25), yellow)
	dipper.rotation.z = -0.25
	_box(ex, Vector3(3.3, 0.35, 0.35), Vector3(0.6, 0.45, 0.7), Color(0.3, 0.3, 0.32))
	# Striped barrier on legs in front of the hole.
	_box(root, pos + Vector3(0, 0.9, 1.9), Vector3(3.0, 0.22, 0.05), Color(0.85, 0.12, 0.1))
	for lx in [-1.3, 1.3]:
		_box(root, pos + Vector3(lx, 0.45, 1.9), Vector3(0.06, 0.9, 0.06), Color(0.9, 0.9, 0.9))


static func _street(root: Node3D, seg: Vector3i) -> void:
	var asphalt := Color(0.22, 0.23, 0.25)
	var walk := Color(0.5, 0.48, 0.45)
	_box(root, Vector3(0, -0.2, -10), Vector3(160, 0.2, 100), Color(0.4, 0.4, 0.4))
	_box(root, Vector3(0, -0.05, STREET_Z), Vector3(BLOCK_HALF * 2, 0.1, 7.5), asphalt)
	for s in [-1, 1]:
		_box(root, Vector3(s * 41.5, -0.05, STREET_Z), Vector3(37, 0.1, 7.5), asphalt)
		# Crossing street: it only continues where there is a street on the map.
		var up := CityMap.has_turn(seg, s > 0, true)
		var down := CityMap.has_turn(seg, s > 0, false)
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
## [{"type": "kiosk", "bar" or "pharmacy", "x": door x}].
static func _buildings(root: Node3D, rng: RandomNumberGenerator, home_x: float) -> void:
	root.set_meta("shops", [])
	var x := -BLOCK_HALF
	var kiosk_idx := rng.randi() % 4 if rng.randf() < 0.5 else -1
	var bar_idx := rng.randi() % 4 if rng.randf() < 0.4 else -1
	if bar_idx == kiosk_idx:
		bar_idx = -1
	var pharm_idx := rng.randi() % 4 if rng.randf() < 0.3 else -1
	if pharm_idx == kiosk_idx or pharm_idx == bar_idx:
		pharm_idx = -1
	var idx := 0
	while x < BLOCK_HALF - 0.5:
		var w := minf(rng.randf_range(5.0, 8.0), BLOCK_HALF - x)
		var h := rng.randf_range(9.0, 16.0)
		var shop := ""
		if idx == kiosk_idx:
			shop = "kiosk"
		elif idx == bar_idx:
			shop = "bar"
		elif idx == pharm_idx:
			shop = "pharmacy"
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
		var sign_col: Color = SHOP_COLORS[shop]
		_box(root, Vector3(base.x - w * 0.15, 2.8, base.z + 0.08), Vector3(w * 0.55, 0.6, 0.1), sign_col)
		var key: String = SHOP_SIGNS[shop]
		if shop == "pharmacy":
			# A glowing green cross next to the door.
			var cx := door_x + 0.95
			for sz in [Vector3(0.5, 0.16, 0.06), Vector3(0.16, 0.5, 0.06)]:
				var cr := _box(root, Vector3(cx, 2.8, base.z + 0.3), sz, Color(0.2, 0.85, 0.35))
				var cm: StandardMaterial3D = cr.material_override
				cm.emission_enabled = true
				cm.emission = Color(0.2, 0.9, 0.35)
				cm.emission_energy_multiplier = 1.2
		var shop_text := TranslationServer.translate(key)
		var l := _label(shop_text, 72, 0.006)
		l.position = Vector3(base.x - w * 0.15, 2.8, base.z + 0.15)
		# Shop signs get blurry / scrambled just like street signs.
		l.set_meta("real_text", shop_text)
		l.add_to_group("street_sign")
		root.add_child(l)
		# Lit doorway so shops are easy to spot.
		var lit := _box(root, Vector3(door_x, 1.1, base.z + 0.06), Vector3(1.1, 2.2, 0.1), Color(0.95, 0.8, 0.45))
		var lm: StandardMaterial3D = lit.material_override
		lm.emission_enabled = true
		lm.emission = Color(0.9, 0.7, 0.35)
		lm.emission_energy_multiplier = 0.6
		# Striped awning over the door (things can get stuck on top).
		for k in 4:
			_box(root, Vector3(door_x - 0.75 + k * 0.5, AWNING_Y - 0.1 * (k % 2), -7.35),
				Vector3(0.5, 0.08, 1.1), sign_col if k % 2 == 0 else Color(0.95, 0.95, 0.92))
		# (The bar's bouncer is a character spawned by main.gd.)
		var shops: Array = root.get_meta("shops")
		shops.append({"type": shop, "x": door_x})


## Height of the top of a shop awning.
const AWNING_Y := 2.4
## Where a lost thing stuck up high sits: in the front of a tree top, or
## on top of an awning (y, z).
const TREE_ITEM := Vector2(2.35, -6.45)
const AWNING_ITEM := Vector2(AWNING_Y + 0.08, -7.1)


## Election stall: a table, a striped canopy on four poles and a sign
## board with a big smiling face. The politician stands behind the table.
static func _booth(root: Node3D, x: float) -> void:
	var blue := Color(0.15, 0.4, 0.8)
	_box(root, Vector3(x, 0.85, -6.7), Vector3(1.8, 0.06, 0.7), Color(0.95, 0.95, 0.95))
	_box(root, Vector3(x, 0.5, -6.38), Vector3(1.8, 0.66, 0.04), blue)
	for px in [-0.85, 0.85]:
		for pz in [-7.0, -6.4]:
			_cyl(root, Vector3(x + px, 1.2, pz), 0.03, 2.4, Color(0.8, 0.8, 0.82))
	for k in 5:
		_box(root, Vector3(x - 0.8 + k * 0.4, 2.42, -6.7), Vector3(0.4, 0.06, 0.8),
			blue if k % 2 == 0 else Color(0.97, 0.97, 0.97))
	# Sign board on the front of the canopy: a smiling face.
	_box(root, Vector3(x, 2.15, -6.28), Vector3(1.2, 0.5, 0.04), Color(0.97, 0.97, 0.97))
	_sphere(root, Vector3(x, 2.15, -6.25), 0.18, Color(1.0, 0.85, 0.3))
	for ex in [-0.06, 0.06]:
		_box(root, Vector3(x + ex, 2.2, -6.08), Vector3(0.03, 0.04, 0.02), Color(0.1, 0.1, 0.1))
	_box(root, Vector3(x, 2.1, -6.08), Vector3(0.14, 0.025, 0.02), Color(0.1, 0.1, 0.1))
	# Coffee pot and cups on the table.
	_cyl(root, Vector3(x - 0.5, 1.0, -6.7), 0.08, 0.24, Color(0.2, 0.2, 0.22))
	for cx in [-0.2, 0.0, 0.2]:
		_cyl(root, Vector3(x + cx, 0.93, -6.6), 0.035, 0.08, Color(0.97, 0.97, 0.95))
	for ox in [-0.6, 0.0, 0.6]:
		_obstacle(root, x + ox, -6.7, 0.4)


## Breath test checkpoint across the street at x = 0: a row of cones, a
## police sign board and blue lights on poles that blink (main.gd blinks
## the meshes listed in the root meta "blue_lights").
static func _checkpoint(root: Node3D) -> void:
	root.set_meta("checkpoint", 0.0)
	for i in 5:
		_cone(root, Vector3(-0.8, 0, -4.2 + i * 1.5))
	var lights: Array = []
	for z in [-5.3, 2.8]:
		_cyl(root, Vector3(-1.4, 1.1, z), 0.04, 2.2, Color(0.25, 0.27, 0.3))
		var l := _box(root, Vector3(-1.4, 2.3, z), Vector3(0.22, 0.16, 0.22), Color(0.2, 0.4, 1.0))
		var lm: StandardMaterial3D = l.material_override
		lm.emission_enabled = true
		lm.emission = Color(0.2, 0.45, 1.0)
		lights.append(l)
	root.set_meta("blue_lights", lights)
	_box(root, Vector3(-1.4, 1.3, -5.24), Vector3(0.9, 0.5, 0.05), Color(0.1, 0.25, 0.65))
	var text := TranslationServer.translate("SIGN_POLICE")
	var lb := _label(text, 48, 0.006)
	lb.position = Vector3(-1.4, 1.3, -5.2)
	root.add_child(lb)


## Shop sign colours and texts.
const SHOP_COLORS := {"kiosk": Color(0.85, 0.15, 0.15), "bar": Color(0.35, 0.12, 0.4),
	"pharmacy": Color(0.1, 0.5, 0.3)}
const SHOP_SIGNS := {"kiosk": "SIGN_KIOSK", "bar": "SIGN_BAR", "pharmacy": "SIGN_PHARMACY"}


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


## Police station front: grey-blue facade, blue POLIISI sign, glass door.
static func _police_station(root: Node3D) -> void:
	root.set_meta("shops", [])  # no shop doors hidden behind the station front
	var x := CityMap.police_door_x()
	_box(root, Vector3(x, 4.0, -7.93), Vector3(9.0, 8.0, 0.08), Color(0.62, 0.66, 0.72))
	_box(root, Vector3(x, 1.2, -7.86), Vector3(1.6, 2.4, 0.1), Color(0.55, 0.7, 0.8))
	_box(root, Vector3(x, 3.0, -7.84), Vector3(3.6, 0.7, 0.1), Color(0.1, 0.25, 0.65))
	var text := TranslationServer.translate("SIGN_POLICE")
	var l := _label(text, 72, 0.007)
	l.position = Vector3(x, 3.0, -7.76)
	l.set_meta("real_text", text)
	l.add_to_group("street_sign")
	root.add_child(l)
	for wx in [x - 3.0, x + 3.0]:
		_box(root, Vector3(wx, 1.5, -7.87), Vector3(1.8, 1.8, 0.08), Color(0.3, 0.38, 0.45))


## Solid things the player bumps into: root meta "obstacles" = [[x, z, r], ...].
static func _obstacle(root: Node3D, x: float, z: float, r: float) -> void:
	var obs: Array = root.get_meta("obstacles", [])
	obs.append([x, z, r])
	root.set_meta("obstacles", obs)


## Free space kept on both sides of a door (metres).
const DOOR_CLEAR := 3.0


## A random x on the far sidewalk at least DOOR_CLEAR from every door, or
## NAN if no such spot turned up.
static func clear_of_doors(root: Node3D, rng: RandomNumberGenerator, lo: float, hi: float) -> float:
	var doors: Array = root.get_meta("doors", [])
	for attempt in 30:
		var x := rng.randf_range(lo, hi)
		var ok := true
		for d in doors:
			if absf(x - float(d)) < DOOR_CLEAR:
				ok = false
				break
		if ok:
			return x
	return NAN


static func _props(root: Node3D, rng: RandomNumberGenerator, sea: bool) -> void:
	var x := -40.0
	while x <= 40.0:
		if absf(absf(x) - (BLOCK_HALF + CROSS_HALF) * 0.5) > 4.0:
			_cyl(root, Vector3(x, 2.0, 5.5), 0.07, 4.0, Color(0.2, 0.22, 0.25))
			_obstacle(root, x, 5.5, 0.15)
			_box(root, Vector3(x, 4.05, 5.2), Vector3(0.25, 0.12, 0.7), Color(0.2, 0.22, 0.25))
		x += 10.0
	if not sea:
		for i in rng.randi_range(2, 4):
			var tx := clear_of_doors(root, rng, -BLOCK_HALF + 1.5, BLOCK_HALF - 1.5)
			if is_nan(tx):
				continue
			_cyl(root, Vector3(tx, 1.2, -7.3), 0.15, 2.4, Color(0.35, 0.25, 0.18))
			_obstacle(root, tx, -7.3, 0.25)
			_sphere(root, Vector3(tx, 3.3, -7.3), 1.3, Color(0.25, 0.5, 0.24))
			var trees: Array = root.get_meta("trees", [])
			trees.append(tx)
			root.set_meta("trees", trees)
	for hx in [-30.0, -20.0, -4.0, 4.0, 20.0, 30.0]:
		_box(root, Vector3(hx, 0.35, 7.0), Vector3(3.0, 0.7, 0.8), Color(0.22, 0.45, 0.22))
	for i in rng.randi_range(0, 2):
		var bx := rng.randf_range(-12.0, 12.0)
		_box(root, Vector3(bx, 0.45, 5.4), Vector3(1.8, 0.1, 0.5), Color(0.45, 0.3, 0.2))
		for ox in [-0.6, 0.0, 0.6]:
			_obstacle(root, bx + ox, 5.4, 0.3)
		_box(root, Vector3(bx, 0.22, 5.4), Vector3(1.6, 0.44, 0.08), Color(0.2, 0.2, 0.2))
	for i in rng.randi_range(1, 3):
		var binx := clear_of_doors(root, rng, -14.0, 14.0)
		if is_nan(binx):
			continue
		_cyl(root, Vector3(binx, 0.5, -7.5), 0.3, 0.8, Color(0.2, 0.35, 0.25))
		_obstacle(root, binx, -7.5, 0.35)
		var bins: Array = root.get_meta("bins", [])
		bins.append(binx)
		root.set_meta("bins", bins)


## Blue street name signs on poles at both corners of the far sidewalk.
## Upper plate: this street, with a left-right arrow (it continues to the
## sides). Lower plate: the crossing street, with an up-down arrow (turn
## onto it by going up or down).
static func _signs(root: Node3D, seg: Vector3i) -> void:
	for s in [-1, 1]:
		var px: float = s * (BLOCK_HALF - 0.4)
		_cyl(root, Vector3(px, 1.5, -5.4), 0.05, 3.0, Color(0.25, 0.27, 0.3))
		_obstacle(root, px, -5.4, 0.12)
		_sign(root, CityMap.street_name(seg), Vector3(px - s * 1.3, 2.75, -5.36), false)
		_sign(root, CityMap.cross_name(seg, s > 0), Vector3(px + s * 1.3, 2.3, -5.36), true)


static func _sign(root: Node3D, text: String, pos: Vector3, vertical: bool) -> void:
	var text_w := text.length() * 0.25 + 0.3
	var arrow_w := 0.45
	var w := text_w + arrow_w
	_box(root, pos, Vector3(w, 0.42, 0.05), Color(0.1, 0.3, 0.7))
	var l := _label(text, 48, 0.008)
	l.position = pos + Vector3(-arrow_w * 0.5, 0, 0.04)
	l.set_meta("real_text", text)
	l.add_to_group("street_sign")
	root.add_child(l)
	_sign_arrow(root, pos + Vector3(w * 0.5 - arrow_w * 0.5, 0, 0.035), vertical)


## A white double arrow made of thin boxes: up-down or left-right.
static func _sign_arrow(root: Node3D, c: Vector3, vertical: bool) -> void:
	var white := Color(0.95, 0.95, 0.95)
	var half := 0.14
	var t := 0.035
	var shaft := Vector3(t, half * 2.0, 0.02) if vertical else Vector3(half * 2.0, t, 0.02)
	_box(root, c, shaft, white)
	for e in [-1.0, 1.0]:
		var tip := c + (Vector3(0, e * half, 0) if vertical else Vector3(e * half, 0, 0))
		for side in [-1.0, 1.0]:
			var head := _box(root, Vector3.ZERO, Vector3(0.1, t, 0.02), white)
			if vertical:
				# Chevron pointing up (e = 1) or down (e = -1).
				head.rotation.z = side * e * deg_to_rad(-45.0)
				head.position = tip + Vector3(side * 0.033, -e * 0.033, 0)
			else:
				head.rotation.z = -side * e * deg_to_rad(45.0)
				head.position = tip + Vector3(-e * 0.033, side * 0.033, 0)


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
