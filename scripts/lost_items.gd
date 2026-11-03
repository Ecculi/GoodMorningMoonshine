extends RefCounted
## The character's own belongings that can get lost overnight: their ids,
## HUD icons (no text) and 3D models.

const IDS := ["wallet", "phone", "glasses", "sunglasses", "shoes", "jacket", "keys", "idcard"]

## How close a lost item must be before it is recognisable (metres).
const REVEAL_DIST := 4.0
const REVEAL_DIST_NO_GLASSES := 1.6

const COLORS := {
	"wallet": Color(0.45, 0.28, 0.15),
	"phone": Color(0.12, 0.12, 0.14),
	"glasses": Color(0.15, 0.15, 0.18),
	"sunglasses": Color(0.05, 0.05, 0.06),
	"shoes": Color(0.55, 0.3, 0.15),
	"jacket": Color(0.25, 0.4, 0.3),
	"keys": Color(0.85, 0.75, 0.3),
	"idcard": Color(0.3, 0.55, 0.85),
}


## Draws the icon for `id` centred at `c`. `mode`: "own" (in colour),
## "lost" (grey), "blob" (forgotten: just a grey smudge).
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, mode: String) -> void:
	if mode == "blob":
		ci.draw_circle(c, s * 0.42, Color(0.55, 0.55, 0.58, 0.8))
		ci.draw_circle(c + Vector2(s * 0.18, -s * 0.12), s * 0.22, Color(0.55, 0.55, 0.58, 0.8))
		return
	var col: Color = COLORS[id] if mode == "own" else Color(0.5, 0.5, 0.52, 0.75)
	var light := col.lightened(0.5) if mode == "own" else Color(0.7, 0.7, 0.72, 0.75)
	var w := maxf(2.0, s * 0.08)
	match id:
		"wallet":
			ci.draw_rect(Rect2(c - Vector2(s * 0.4, s * 0.28), Vector2(s * 0.8, s * 0.56)), col)
			ci.draw_rect(Rect2(c + Vector2(s * 0.1, -s * 0.1), Vector2(s * 0.3, s * 0.2)), light)
		"phone":
			ci.draw_rect(Rect2(c - Vector2(s * 0.22, s * 0.42), Vector2(s * 0.44, s * 0.84)), col)
			ci.draw_rect(Rect2(c - Vector2(s * 0.17, s * 0.34), Vector2(s * 0.34, s * 0.6)), light)
		"glasses", "sunglasses":
			var fill := id == "sunglasses"
			for sx in [-1.0, 1.0]:
				if fill:
					ci.draw_circle(c + Vector2(sx * s * 0.22, 0), s * 0.17, col)
				else:
					ci.draw_arc(c + Vector2(sx * s * 0.22, 0), s * 0.17, 0, TAU, 20, col, w, true)
			ci.draw_line(c + Vector2(-s * 0.06, -s * 0.03), c + Vector2(s * 0.06, -s * 0.03), col, w)
			ci.draw_line(c + Vector2(-s * 0.39, -s * 0.03), c + Vector2(-s * 0.48, -s * 0.12), col, w)
			ci.draw_line(c + Vector2(s * 0.39, -s * 0.03), c + Vector2(s * 0.48, -s * 0.12), col, w)
		"shoes":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.3), c + Vector2(-s * 0.1, -s * 0.3),
				c + Vector2(-s * 0.05, 0), c + Vector2(s * 0.42, s * 0.08), c + Vector2(s * 0.42, s * 0.25),
				c + Vector2(-s * 0.4, s * 0.25)]), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, s * 0.18), Vector2(s * 0.82, s * 0.08)), light)
		"jacket":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.15, -s * 0.4), c + Vector2(s * 0.15, -s * 0.4),
				c + Vector2(s * 0.45, -s * 0.2), c + Vector2(s * 0.45, s * 0.1), c + Vector2(s * 0.3, s * 0.1),
				c + Vector2(s * 0.3, s * 0.42), c + Vector2(-s * 0.3, s * 0.42), c + Vector2(-s * 0.3, s * 0.1),
				c + Vector2(-s * 0.45, s * 0.1), c + Vector2(-s * 0.45, -s * 0.2)]), col)
			ci.draw_line(c + Vector2(0, -s * 0.35), c + Vector2(0, s * 0.42), light, w)
		"keys":
			ci.draw_arc(c + Vector2(-s * 0.2, 0), s * 0.18, 0, TAU, 20, col, w * 1.3, true)
			ci.draw_line(c + Vector2(-s * 0.02, 0), c + Vector2(s * 0.45, 0), col, w * 1.3)
			ci.draw_line(c + Vector2(s * 0.3, 0), c + Vector2(s * 0.3, s * 0.15), col, w * 1.3)
			ci.draw_line(c + Vector2(s * 0.42, 0), c + Vector2(s * 0.42, s * 0.12), col, w * 1.3)
		"idcard":
			ci.draw_rect(Rect2(c - Vector2(s * 0.42, s * 0.28), Vector2(s * 0.84, s * 0.56)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.34, -s * 0.18), Vector2(s * 0.24, s * 0.32)), light)
			ci.draw_line(c + Vector2(0, -s * 0.08), c + Vector2(s * 0.32, -s * 0.08), light, w)
			ci.draw_line(c + Vector2(0, s * 0.06), c + Vector2(s * 0.26, s * 0.06), light, w)


## A small 3D model of the item lying on the ground.
static func build_mesh(id: String) -> Node3D:
	var root := Node3D.new()
	var col: Color = COLORS[id]
	match id:
		"wallet":
			_box(root, Vector3(0, 0.03, 0), Vector3(0.22, 0.05, 0.15), col)
		"phone":
			_box(root, Vector3(0, 0.015, 0), Vector3(0.16, 0.02, 0.3), col)
			_box(root, Vector3(0, 0.03, 0), Vector3(0.13, 0.005, 0.25), Color(0.3, 0.45, 0.6))
		"glasses", "sunglasses":
			for sx in [-1.0, 1.0]:
				_box(root, Vector3(sx * 0.08, 0.04, 0), Vector3(0.12, 0.07, 0.02), col if id == "sunglasses" else Color(0.7, 0.8, 0.85))
			_box(root, Vector3(0, 0.07, 0), Vector3(0.3, 0.02, 0.02), col)
		"shoes":
			for sz in [-1.0, 1.0]:
				_box(root, Vector3(0, 0.06, sz * 0.08), Vector3(0.3, 0.12, 0.11), col)
		"jacket":
			_box(root, Vector3(0, 0.04, 0), Vector3(0.6, 0.08, 0.5), col)
		"keys":
			_box(root, Vector3(0, 0.02, 0), Vector3(0.16, 0.03, 0.05), col)
			_box(root, Vector3(-0.1, 0.02, 0), Vector3(0.06, 0.03, 0.08), col)
		"idcard":
			_box(root, Vector3(0, 0.01, 0), Vector3(0.2, 0.01, 0.13), col)
	return root


static func _box(root: Node3D, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	mi.material_override = m
	mi.position = pos
	root.add_child(mi)
	return mi
