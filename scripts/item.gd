extends Node3D
## An item on the street, in the player's hand, or flying after a throw.

enum Kind { BOTTLE, CAN, FOOD, COIN, COFFEE, ENERGY, PILLS, BAG }
enum St { GROUND, HELD, FLYING }


var main
var kind: Kind = Kind.CAN
var value := 1
var state: St = St.GROUND
## A dropped item waits until the player has stepped away, so it is not
## picked up again straight away.
var wait_far := false
var flight_time := 0.5
## Plastic bag: what is inside, as [kind, value, drink] entries. Holding a
## bag, picked-up things go into it (see player._pickup); too many and it
## tears (BAG_MAX). A full bag is heavy to throw.
var contents: Array = []
const BAG_MAX := 5
## A bag with this many things in it hits like a bottle.
const BAG_HEAVY := 3
var _bag_body: MeshInstance3D

var _root: Node3D


## Bottle contents: what it is and how much it raises the per mille.
enum Drink { BOTTLE, BEER, SPIRITS, MYSTERY }
const DRINK_PROMILLE := {Drink.BOTTLE: 0.4, Drink.BEER: 0.25, Drink.SPIRITS: 0.6, Drink.MYSTERY: 0.9}
const DRINK_COLOR := {Drink.BOTTLE: Color(0.18, 0.42, 0.2), Drink.BEER: Color(0.45, 0.25, 0.08),
	Drink.SPIRITS: Color(0.85, 0.9, 0.95), Drink.MYSTERY: Color(0.55, 0.2, 0.7)}
var drink: Drink = Drink.BOTTLE
## How much a drink warms up a cold character: strong stuff burns warm.
const DRINK_WARMTH := {Drink.BOTTLE: 5.0, Drink.BEER: 0.0, Drink.SPIRITS: 25.0, Drink.MYSTERY: 20.0}


func setup(k: Kind, v := 1, d: Drink = Drink.BOTTLE) -> void:
	kind = k
	value = v
	drink = d
	_root = Node3D.new()
	add_child(_root)
	match kind:
		Kind.BOTTLE:
			var bc: Color = DRINK_COLOR[drink]
			_cyl(0.07, 0.3, bc, Vector3(0, 0.15, 0))
			_cyl(0.03, 0.12, bc, Vector3(0, 0.36, 0))
			if drink == Drink.MYSTERY:
				_cyl(0.072, 0.08, Color(0.95, 0.95, 0.9), Vector3(0, 0.15, 0))  # hand-written label
		Kind.CAN:
			_cyl(0.055, 0.17, Color(0.78, 0.8, 0.84), Vector3(0, 0.085, 0))
			_cyl(0.057, 0.07, Color(0.15, 0.35, 0.75), Vector3(0, 0.085, 0))
		Kind.FOOD:
			_build_sausage()
		Kind.COFFEE:
			_cyl(0.055, 0.14, Color(0.95, 0.95, 0.93), Vector3(0, 0.07, 0))
			_cyl(0.05, 0.01, Color(0.35, 0.2, 0.1), Vector3(0, 0.142, 0))
			_cyl(0.057, 0.04, Color(0.6, 0.4, 0.25), Vector3(0, 0.06, 0))
		Kind.BAG:
			var white := Color(0.95, 0.95, 0.93)
			_bag_body = _cyl(0.1, 0.24, white, Vector3(0, 0.12, 0))
			_bag_body.scale = Vector3(1.0, 1.0, 0.55)
			_cyl(0.102, 0.05, Color(0.2, 0.45, 0.85), Vector3(0, 0.15, 0)).scale = Vector3(1.0, 1.0, 0.56)
			for sx in [-0.05, 0.05]:
				var hd := _cyl(0.012, 0.09, white, Vector3(sx, 0.27, 0))
				hd.rotation.z = -sx * 6.0
		Kind.ENERGY:
			_cyl(0.05, 0.19, Color(0.1, 0.1, 0.12), Vector3(0, 0.095, 0))
			_cyl(0.052, 0.06, Color(0.4, 0.95, 0.2), Vector3(0, 0.1, 0))
		Kind.PILLS:
			# A small clear bag of pink and blue pills (dropped by a punk).
			var bag := _cyl(0.06, 0.02, Color(0.9, 0.92, 0.95, 0.6), Vector3(0, 0.02, 0))
			bag.scale = Vector3(1.0, 1.0, 0.7)
			for i in 5:
				var pc := Color(1.0, 0.45, 0.75) if i % 2 == 0 else Color(0.35, 0.6, 1.0)
				_cyl(0.012, 0.012, pc, Vector3(-0.03 + i * 0.015, 0.035, (i % 2) * 0.012 - 0.006))
		Kind.COIN:
			var c := _cyl(0.09, 0.02, Color(0.95, 0.75, 0.2), Vector3(0, 0.25, 0))
			c.rotation.x = PI * 0.5
			var m: StandardMaterial3D = c.material_override
			m.metallic = 0.8
			m.roughness = 0.3
	_root.scale = Vector3.ONE * 2.0


## Height of the ground: the sidewalks are a kerb (12 cm) higher than the
## street, so low things there don't sink into them.
static func ground_y(p: Vector3) -> float:
	if p.z < -5.0 or (p.z > 2.5 and p.z < 5.8):
		return 0.12
	return 0.0


## Food lying on the street (dogs go for it).
func can_be_eaten() -> bool:
	return kind == Kind.FOOD and state == St.GROUND


## Bag: bulges with what is inside.
func update_bag_look() -> void:
	if _bag_body == null:
		return
	var n := float(contents.size())
	_bag_body.scale = Vector3(1.0 + n * 0.07, 1.0 + n * 0.1, 0.55 + n * 0.08)


## What a thrown thing counts as when it hits someone: a heavy bag hits
## like a bottle (and can knock them out), a light one like a can.
func hit_kind() -> int:
	if kind == Kind.BAG:
		return Kind.BOTTLE if contents.size() >= BAG_HEAVY else Kind.CAN
	return kind


func can_pickup() -> bool:
	return state == St.GROUND and not wait_far


func _process(delta: float) -> void:
	match state:
		St.GROUND:
			if kind == Kind.COIN:
				_root.rotation.y += delta * 3.0
		St.FLYING:
			_fly(delta)
	if kind == Kind.FOOD:
		_flop(delta)


# --- Throwing: a real physics object --------------------------------------------

## Collision shape per kind, in the item's own (unscaled) units:
## [shape, radius or size, height, centre height].
const SHAPES := {
	Kind.BOTTLE: ["cyl", 0.07, 0.42, 0.21],
	Kind.CAN: ["cyl", 0.057, 0.17, 0.085],
	Kind.COFFEE: ["cyl", 0.057, 0.15, 0.075],
	Kind.ENERGY: ["cyl", 0.052, 0.19, 0.095],
	Kind.FOOD: ["capsule", 0.05, 0.3, 0.05],
	Kind.PILLS: ["box", 0.12, 0.04, 0.02],
	Kind.BAG: ["box", 0.2, 0.26, 0.13],
}
const MASS := {Kind.BOTTLE: 0.8, Kind.CAN: 0.15, Kind.COFFEE: 0.3, Kind.ENERGY: 0.35, Kind.FOOD: 0.2, Kind.PILLS: 0.05}
## Items fly on their own collision layer and hit the world only.
const ITEM_LAYER := 4
const WORLD_LAYER := 1

var _body: RigidBody3D = null
var _hit_done := false
var _still_t := 0.0
var _air_t := 0.0
var _frozen := false
var _saved_lv := Vector3.ZERO
var _saved_av := Vector3.ZERO


func _make_body(start: Vector3) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.top_level = true
	rb.mass = MASS.get(kind, 0.3) if kind != Kind.BAG else 0.1 + 0.3 * contents.size()
	rb.collision_layer = ITEM_LAYER
	rb.collision_mask = WORLD_LAYER
	rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	rb.contact_monitor = true
	rb.max_contacts_reported = 2
	rb.linear_damp = 0.05
	rb.angular_damp = 0.4
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35 if kind != Kind.FOOD else 0.05
	pm.friction = 0.7
	rb.physics_material_override = pm
	var spec: Array = SHAPES.get(kind, ["box", 0.1, 0.1, 0.05])
	var k := 2.0  # the street look is twice the size
	var cs := CollisionShape3D.new()
	match spec[0]:
		"cyl":
			var cy := CylinderShape3D.new()
			cy.radius = spec[1] * k
			cy.height = spec[2] * k
			cs.shape = cy
		"capsule":
			var cp := CapsuleShape3D.new()
			cp.radius = spec[1] * k
			cp.height = spec[2] * k
			cs.shape = cp
			cs.rotation.z = PI * 0.5
		_:
			var bx := BoxShape3D.new()
			bx.size = Vector3(spec[1], spec[2], spec[1] * 0.7) * k
			cs.shape = bx
	cs.position = Vector3(0, spec[3] * k, 0)
	rb.add_child(cs)
	add_child(rb)
	rb.global_position = start
	rb.body_entered.connect(_on_body_hit)
	return rb


func _fly(delta: float) -> void:
	if _body == null or not is_instance_valid(_body):
		return
	# The physics pauses with the game world (like the rag dolls).
	var freeze := GameState.world_dt <= 0.0 and not GameState.over
	if freeze != _frozen:
		_frozen = freeze
		if freeze:
			_saved_lv = _body.linear_velocity
			_saved_av = _body.angular_velocity
			_body.freeze = true
		else:
			_body.freeze = false
			_body.linear_velocity = _saved_lv
			_body.angular_velocity = _saved_av
	global_transform = _body.global_transform
	if _frozen:
		return
	_air_t += delta
	# Storm: the wind bends the throw; light things far more than heavy.
	var wind: Vector3 = main.wind_at(_body.global_position)
	if wind != Vector3.ZERO:
		var k: float = WIND_DRAG / (MASS.get(kind, 0.3) + 0.2)
		var lv := _body.linear_velocity
		lv.x += (wind.x - lv.x) * k * delta
		lv.z += (wind.z - lv.z) * k * 0.6 * delta
		_body.linear_velocity = lv
	var centre := _body.global_position + _body.global_transform.basis.y * 0.15
	if not _hit_done and main.knock_high_lost(centre):
		_hit_done = true
		_bounce_off()
	if not _hit_done:
		var npc = main.npc_at(centre, 0.6)
		var animal = main.animal_at(centre, 0.5)
		if npc != null and centre.y < 2.2:
			_hit_done = true
			npc.hit_by_item(hit_kind())
			_bounce_off()
			if kind == Kind.BOTTLE and _shatters():
				_break()
				return
		elif animal != null and centre.y < 1.2 and kind != Kind.FOOD:
			# Food is left to land (a dog goes for it); anything else hits.
			_hit_done = true
			animal.hit_by_item(hit_kind())
			_bounce_off()
			if kind == Kind.BOTTLE and _shatters():
				_break()
				return
	# At rest (or lost): lie where it ended up.
	if _body.linear_velocity.length() < 0.25 and _body.angular_velocity.length() < 1.5:
		_still_t += delta
	else:
		_still_t = 0.0
	if _still_t > 0.3 or _air_t > 6.0 or _body.global_position.y < -2.0:
		_settle()


## Hit someone: it glances back off them.
func _bounce_off() -> void:
	var v := _body.linear_velocity
	_body.linear_velocity = Vector3(-v.x * 0.25, maxf(v.y, 1.0) * 0.5, -v.z * 0.25)


## A thrown bottle breaks on the first thing it hits (street, wall, person)
## half the time; otherwise it survives that and doesn't break any more.
## Everything else gets rolling resistance once it touches down, so it
## doesn't roll on like a wheel; the soft sausage stops almost at once.
func _on_body_hit(_other: Node) -> void:
	if state != St.FLYING:
		return
	if kind == Kind.BOTTLE and _air_t > 0.05 and _shatters():
		_break()
		return
	if _body != null and is_instance_valid(_body):
		if kind == Kind.FOOD:
			_body.angular_damp = 9.0
			_body.linear_damp = 3.5
		else:
			_body.angular_damp = maxf(_body.angular_damp, 1.6)
			_body.linear_damp = maxf(_body.linear_damp, 0.6)


## Storm: how strongly the wind drags a flying thing (divided by mass).
const WIND_DRAG := 0.7


## Decided once per throw, on the first impact.
const SHATTER_CHANCE := 0.5
var _shatter_rolled := false
var _will_shatter := false


func _shatters() -> bool:
	if not _shatter_rolled:
		_shatter_rolled = true
		_will_shatter = randf() < SHATTER_CHANCE
	return _will_shatter


## Smashes into shards that stay on the street.
func _break() -> void:
	if state != St.FLYING:
		return
	state = St.GROUND
	main.popup("*", global_position + Vector3(0, 0.4, 0), Color(0.6, 0.9, 0.6))
	main.spawn_glass(global_position, DRINK_COLOR[drink])
	if _body != null and is_instance_valid(_body):
		_body.queue_free()
	_body = null
	main.remove_item(self)


## Lying still: back to an ordinary item on the street, in the pose it
## landed in.
func _settle() -> void:
	var xf := _body.global_transform
	_body.queue_free()
	_body = null
	state = St.GROUND
	var o := xf.origin
	o.y = maxf(o.y, 0.0)
	global_transform = Transform3D(xf.basis.orthonormalized(), o)
	if kind == Kind.FOOD:
		_flop_ground()


func hold(hand: Node3D) -> void:
	state = St.HELD
	wait_far = false
	if get_parent() != null:
		get_parent().remove_child(self)
	hand.add_child(self)
	transform = Transform3D.IDENTITY
	position = Vector3(0, -0.2, 0)
	_root.scale = Vector3.ONE
	_flop_vel = 0.0
	_flop_off = 0.0


func drop_at(pos: Vector3) -> void:
	_to_world()
	state = St.GROUND
	if kind == Kind.FOOD:
		_flop_ground()
	wait_far = true
	global_position = Vector3(pos.x, ground_y(pos), pos.z)


## Thrown: a physics body with a start velocity aimed to come down about
## `dist` metres away, spinning; it bounces and rolls from there.
## `via`: a point the throw must pass through (a lost thing up a tree);
## Vector3.INF = an ordinary throw that lands `dist` away.
func throw_from(start: Vector3, dir: Vector3, dist: float, via := Vector3.INF) -> void:
	_to_world()
	state = St.FLYING
	_hit_done = false
	_shatter_rolled = false
	_still_t = 0.0
	_air_t = 0.0
	_frozen = false
	var land: Vector3 = main.clamp_walkable(start + dir.normalized() * dist)
	var flat := Vector3(land.x - start.x, 0.0, land.z - start.z)
	var t := clampf(flat.length() / 7.0, 0.3, 0.9)
	var vy := (0.1 - start.y + 0.5 * 9.8 * t * t) / t
	flight_time = t
	if via != Vector3.INF:
		# Lobbed up so that it passes through `via` after t seconds (and
		# lands a moment later).
		flat = Vector3(via.x - start.x, 0.0, via.z - start.z)
		t = clampf(flat.length() / 6.0, 0.4, 1.0)
		vy = (via.y - start.y + 0.5 * 9.8 * t * t) / t
		flight_time = t * 1.6
	global_position = start
	_body = _make_body(start)
	_body.linear_velocity = flat / t + Vector3(0, vy, 0)
	# Tumbling end over end across the throw, plus a little wobble.
	var spin_axis := Vector3.UP.cross(flat.normalized() if flat.length() > 0.01 else Vector3.RIGHT)
	_body.angular_velocity = spin_axis * randf_range(6.0, 12.0) + Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))


## Knocked out of the hand (e.g. hit by a car): flies off with velocity
## `vel`, spinning wildly, as a physics object.
func launch(start: Vector3, vel: Vector3) -> void:
	_to_world()
	state = St.FLYING
	_hit_done = true  # it hits nobody on the way
	_shatter_rolled = false
	_still_t = 0.0
	_air_t = 0.0
	_frozen = false
	global_position = start
	_body = _make_body(start)
	_body.linear_velocity = vel
	_body.angular_velocity = Vector3(randf_range(-14, 14), randf_range(-8, 8), randf_range(-14, 14))


func _to_world() -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	main.add_child(self)
	transform = Transform3D.IDENTITY
	_root.scale = Vector3.ONE * 2.0
	_root.rotation = Vector3.ZERO


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m


func _cyl(r: float, h: float, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = _mat(c)
	mi.position = pos
	_root.add_child(mi)
	return mi


# --- The sausage: floppy ---------------------------------------------------------

## The sausage is four short pieces hinged in the middle and between the
## pieces, so it can sag. In the hand both ends droop and swing with the
## movement; in the air it flaps as it tumbles; on the street it lies with
## a lazy bend.
var _flop_pivots: Array = []  # [side, inner pivot, outer pivot]
var _flop_off := 0.0
var _flop_vel := 0.0
var _flop_last := Vector3.INF
var _flop_bend := 0.0
const SAUSAGE_SEG := 0.075
const SAUSAGE_R := 0.05


func _build_sausage() -> void:
	var col := Color(0.78, 0.32, 0.25)
	var centre := Node3D.new()
	centre.position = Vector3(0, SAUSAGE_R, 0)
	_root.add_child(centre)
	for side in [1.0, -1.0]:
		var p1 := Node3D.new()
		centre.add_child(p1)
		_sausage_piece(p1, side, col, false)
		var p2 := Node3D.new()
		p2.position = Vector3(side * SAUSAGE_SEG, 0, 0)
		p1.add_child(p2)
		_sausage_piece(p2, side, col, true)
		_flop_pivots.append([side, p1, p2])
	_flop_bend = randf_range(-0.35, 0.35)
	_flop_ground()


func _sausage_piece(pivot: Node3D, side: float, col: Color, tip: bool) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = SAUSAGE_R
	cm.height = SAUSAGE_SEG + SAUSAGE_R * (1.4 if tip else 0.9)
	mi.mesh = cm
	mi.material_override = _mat(col.darkened(0.05 if tip else 0.0))
	mi.rotation.z = PI * 0.5
	mi.position = Vector3(side * SAUSAGE_SEG * (0.6 if tip else 0.5), 0, 0)
	pivot.add_child(mi)


## Sets the bend: `down` sags both ends (radians per joint), `sideways`
## curves the sausage flat.
func _set_bend(down: float, sideways: float) -> void:
	for f in _flop_pivots:
		var side: float = f[0]
		for p in [f[1], f[2]]:
			p.rotation.z = -side * down
			p.rotation.y = side * sideways


func _flop(delta: float) -> void:
	if _flop_pivots.is_empty():
		return
	match state:
		St.HELD:
			# Hanging from the hand: ends droop, and swing on a spring
			# when the hand moves up/down or speeds up.
			var p := global_position
			if _flop_last != Vector3.INF and delta > 0.0:
				var v := (p - _flop_last) / delta
				_flop_vel += (-v.y * 0.6 + absf(v.x) * 0.15) * delta * 6.0
			_flop_last = p
			_flop_vel += (-_flop_off * 60.0 - _flop_vel * 7.0) * delta
			_flop_off += _flop_vel * delta
			_set_bend(clampf(0.45 + _flop_off, 0.0, 1.1), 0.0)
		St.FLYING:
			# Flapping as it tumbles.
			var spin := _body.angular_velocity.length() if _body != null and is_instance_valid(_body) else 0.0
			_set_bend(sin(Time.get_ticks_msec() / 1000.0 * 14.0) * 0.5 * clampf(spin / 6.0, 0.2, 1.0), 0.0)
		_:
			_flop_last = Vector3.INF


## Lying on the street: flat, with a lazy sideways curve.
func _flop_ground() -> void:
	_set_bend(0.0, _flop_bend)
