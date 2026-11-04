extends Node3D
## An item on the street, in the player's hand, or flying after a throw.

enum Kind { BOTTLE, CAN, FOOD, COIN, COFFEE, ENERGY }
enum St { GROUND, HELD, FLYING }

const FLIGHT_SPEED := 9.0

var main
var kind: Kind = Kind.CAN
var value := 1
var state: St = St.GROUND
## A dropped item waits until the player has stepped away, so it is not
## picked up again straight away.
var wait_far := false
var flight_time := 0.5

var _t := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _root: Node3D


func setup(k: Kind, v := 1) -> void:
	kind = k
	value = v
	_root = Node3D.new()
	add_child(_root)
	match kind:
		Kind.BOTTLE:
			_cyl(0.07, 0.3, Color(0.18, 0.42, 0.2), Vector3(0, 0.15, 0))
			_cyl(0.03, 0.12, Color(0.18, 0.42, 0.2), Vector3(0, 0.36, 0))
		Kind.CAN:
			_cyl(0.055, 0.17, Color(0.78, 0.8, 0.84), Vector3(0, 0.085, 0))
			_cyl(0.057, 0.07, Color(0.15, 0.35, 0.75), Vector3(0, 0.085, 0))
		Kind.FOOD:
			var mi := MeshInstance3D.new()
			var cm := CapsuleMesh.new()
			cm.radius = 0.05
			cm.height = 0.3
			mi.mesh = cm
			mi.material_override = _mat(Color(0.78, 0.32, 0.25))
			mi.rotation.z = PI * 0.5
			mi.position = Vector3(0, 0.05, 0)
			_root.add_child(mi)
		Kind.COFFEE:
			_cyl(0.055, 0.14, Color(0.95, 0.95, 0.93), Vector3(0, 0.07, 0))
			_cyl(0.05, 0.01, Color(0.35, 0.2, 0.1), Vector3(0, 0.142, 0))
			_cyl(0.057, 0.04, Color(0.6, 0.4, 0.25), Vector3(0, 0.06, 0))
		Kind.ENERGY:
			_cyl(0.05, 0.19, Color(0.1, 0.1, 0.12), Vector3(0, 0.095, 0))
			_cyl(0.052, 0.06, Color(0.4, 0.95, 0.2), Vector3(0, 0.1, 0))
		Kind.COIN:
			var c := _cyl(0.09, 0.02, Color(0.95, 0.75, 0.2), Vector3(0, 0.25, 0))
			c.rotation.x = PI * 0.5
			var m: StandardMaterial3D = c.material_override
			m.metallic = 0.8
			m.roughness = 0.3
	_root.scale = Vector3.ONE * 2.0


func can_pickup() -> bool:
	return state == St.GROUND and not wait_far


func _process(delta: float) -> void:
	match state:
		St.GROUND:
			if kind == Kind.COIN:
				_root.rotation.y += delta * 3.0
		St.FLYING:
			_fly(delta)


func _fly(delta: float) -> void:
	_t = minf(_t + delta / flight_time, 1.0)
	var p := _from.lerp(_to, _t)
	p.y += sin(PI * _t) * 1.0
	global_position = p
	_root.rotation.z += delta * 14.0
	var npc = main.npc_at(global_position, 0.6)
	if npc != null and global_position.y < 2.2:
		npc.hit_by_item(kind)
		_land()
	elif _t >= 1.0:
		_land()


func _land() -> void:
	_root.rotation = Vector3.ZERO
	global_position.y = 0.0
	state = St.GROUND
	# Bottles break when they hit something or the ground.
	if kind == Kind.BOTTLE:
		main.popup("*", global_position + Vector3(0, 0.4, 0), Color(0.6, 0.9, 0.6))
		main.remove_item(self)


func hold(hand: Node3D) -> void:
	state = St.HELD
	wait_far = false
	if get_parent() != null:
		get_parent().remove_child(self)
	hand.add_child(self)
	transform = Transform3D.IDENTITY
	position = Vector3(0, -0.2, 0)
	_root.scale = Vector3.ONE


func drop_at(pos: Vector3) -> void:
	_to_world()
	state = St.GROUND
	wait_far = true
	global_position = Vector3(pos.x, 0.0, pos.z)


func throw_from(start: Vector3, dir: Vector3, dist: float) -> void:
	_to_world()
	state = St.FLYING
	_from = start
	var land: Vector3 = main.clamp_walkable(start + dir.normalized() * dist)
	_to = Vector3(land.x, 0.0, land.z)
	dist = Vector2(_to.x - start.x, _to.z - start.z).length()
	flight_time = maxf(dist / FLIGHT_SPEED, 0.2)
	_t = 0.0
	global_position = start


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
