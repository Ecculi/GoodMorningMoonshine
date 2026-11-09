extends Node3D
## Street sweeper (street cleaning special day). Crawls slowly along one
## sidewalk or the street with its brushes spinning and an amber light
## blinking, and sucks up everything lying in its way: bottles, cans,
## food, coins and the player's own lost things (those are dumped in some
## other block further away). Walk into it and it knocks you over. Lives
## in world time.

const Item = preload("res://scripts/item.gd")

const SPEED := 1.5
const HALF_LEN := 1.4
const HALF_WIDTH := 0.8
## How wide a strip the brushes sweep.
const SWEEP_HALF := 1.1
const EDGE_X := 30.0
## Lanes it drives in: the far sidewalk, the street, the near sidewalk.
const LANES := [-6.4, -1.25, 4.0]

var main
var dir := 1
var _brushes: Array = []
var _beacon: MeshInstance3D
var _t := 0.0
var _hit_cool := 0.0


func setup(rng: RandomNumberGenerator, d: int) -> void:
	dir = d
	position = Vector3(-EDGE_X * d, 0, LANES[rng.randi() % LANES.size()])
	var orange := Color(0.95, 0.5, 0.1)
	_box(Vector3(-0.3 * dir, 0.75, 0), Vector3(2.0, 1.0, 1.4), orange)
	_box(Vector3(0.75 * dir, 1.05, 0), Vector3(0.9, 1.3, 1.3), orange.lightened(0.1))  # cab
	_box(Vector3(1.21 * dir, 1.3, 0), Vector3(0.04, 0.6, 1.1), Color(0.3, 0.4, 0.5))  # windscreen
	_box(Vector3(-0.3 * dir, 0.75, 0.71), Vector3(1.8, 0.12, 0.02), Color(0.95, 0.95, 0.95))  # stripe
	for wx in [-0.9, 0.7]:
		for wz in [-0.62, 0.62]:
			var w := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.25
			cm.bottom_radius = 0.25
			cm.height = 0.18
			w.mesh = cm
			w.material_override = _mat(Color(0.08, 0.08, 0.08))
			w.rotation.x = PI * 0.5
			w.position = Vector3(wx * dir, 0.25, wz)
			add_child(w)
	# Round brushes under the front corners.
	for bz in [-0.55, 0.55]:
		var b := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.38
		bm.bottom_radius = 0.38
		bm.height = 0.08
		b.mesh = bm
		b.material_override = _mat(Color(0.25, 0.2, 0.12))
		b.position = Vector3(HALF_LEN * dir, 0.06, bz)
		add_child(b)
		_brushes.append(b)
	_beacon = _box(Vector3(0.75 * dir, 1.8, 0), Vector3(0.2, 0.16, 0.2), Color(1.0, 0.65, 0.1))
	var m: StandardMaterial3D = _beacon.material_override
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.1)


func _process(_delta: float) -> void:
	var dt: float = GameState.world_dt
	if dt <= 0.0 or main == null:
		return
	_t += dt
	_hit_cool = maxf(0.0, _hit_cool - dt)
	position.x += dir * SPEED * dt
	for b in _brushes:
		b.rotation.y += dt * 12.0 * dir
	var bm: StandardMaterial3D = _beacon.material_override
	bm.emission_energy_multiplier = 3.0 if int(_t * 3.0) % 2 == 0 else 0.3
	_sweep()
	_check_hits()
	if absf(position.x) > EDGE_X + 1.0:
		main.remove_sweeper(self)


## Sucks up whatever lies on the ground in front of it.
func _sweep() -> void:
	var front := position.x + dir * HALF_LEN
	for it in main.items.duplicate():
		if not is_instance_valid(it) or it.state != Item.St.GROUND or it == main.player.hand_item:
			continue
		var p: Vector3 = it.global_position
		if absf(p.x - front) < 0.5 and absf(p.z - position.z) < SWEEP_HALF:
			main.popup("slurp", p + Vector3(0, 1.0, 0), Color(0.9, 0.9, 0.95), 0.8)
			main.remove_item(it)
	for ln in main.lost_nodes.duplicate():
		if ln.high > 0.0 or ln.has_meta("flying"):
			continue
		if absf(ln.position.x - front) < 0.5 and absf(ln.position.z - position.z) < SWEEP_HALF:
			main.lost_swept(ln)


## Walking into it (or standing in its way) knocks the character over.
func _check_hits() -> void:
	if _hit_cool > 0.0:
		return
	var p = main.player
	if not p.is_helpless() and absf(p.position.x - position.x) < HALF_LEN + 0.3 \
			and absf(p.position.z - position.z) < HALF_WIDTH + 0.3:
		_hit_cool = 1.5
		p.hit_by_sweeper(dir)
	for n in main.npcs:
		if not n.is_down() and absf(n.position.x - position.x) < HALF_LEN + 0.3 \
				and absf(n.position.z - position.z) < HALF_WIDTH + 0.3:
			n.position.z += 1.2 if n.position.z > position.z else -1.2  # steps aside


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
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
