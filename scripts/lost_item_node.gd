extends Node3D
## One of the player's lost belongings lying in the street. From afar it
## is only a grey shape; when the player is close (closer without glasses)
## it gets its real colours and stands out: it turns and bobs, a glowing
## ring pulses on the ground round it and an arrow bounces above it.

const LostItems = preload("res://scripts/lost_items.gd")

var id := ""
var main
var _model: Node3D
var _grey := StandardMaterial3D.new()
var _revealed := false
var _ring: MeshInstance3D
var _arrow: Label3D
var _t := 0.0


func setup(item_id: String) -> void:
	id = item_id
	_model = LostItems.build_mesh(id)
	_model.scale = Vector3.ONE * 2.2
	add_child(_model)
	_grey.albedo_color = Color(0.45, 0.45, 0.47)
	_grey.roughness = 1.0
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.52
	_ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1, 0.85, 0.2, 0.85)
	rm.emission_enabled = true
	rm.emission = Color(1, 0.8, 0.2)
	rm.emission_energy_multiplier = 1.5
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = rm
	_ring.position = Vector3(0, 0.03, 0)
	add_child(_ring)
	_arrow = Label3D.new()
	_arrow.text = "▼"
	_arrow.font_size = 96
	_arrow.pixel_size = 0.005
	_arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_arrow.no_depth_test = true
	_arrow.modulate = Color(1, 0.85, 0.2)
	_arrow.outline_size = 18
	add_child(_arrow)
	_set_revealed(false)


## Height of the ground under the item: the sidewalks are a kerb (12 cm)
## higher than the street; flat things (phone, wallet, keys) sank out of
## sight into the sidewalk otherwise.
func _ground_y() -> float:
	if position.z < -5.0 or (position.z > 2.5 and position.z < 5.8):
		return 0.13
	return 0.01


func _process(_delta: float) -> void:
	var p: Vector3 = main.player.position
	var d := Vector2(p.x - position.x, p.z - position.z).length()
	var reach := LostItems.REVEAL_DIST_NO_GLASSES if GameState.is_lost("glasses") else LostItems.REVEAL_DIST
	var want := d < reach
	if want != _revealed:
		_set_revealed(want)
	if _revealed:
		_t += _delta
		_model.rotation.y += _delta * 1.5
		_model.position.y = _ground_y() + 0.1 + absf(sin(_t * 3.0)) * 0.12
		var k := 1.0 + 0.15 * sin(_t * 5.0)
		_ring.scale = Vector3(k, 1.0, k)
		_ring.position.y = _ground_y() + 0.02
		_arrow.position = Vector3(0, 1.25 + absf(sin(_t * 4.0)) * 0.2, 0)


func _set_revealed(on: bool) -> void:
	_revealed = on
	_ring.visible = on
	_arrow.visible = on
	if not on:
		_model.position.y = _ground_y()
	for c in _model.get_children():
		if c is MeshInstance3D:
			c.material_overlay = null
			c.transparency = 0.0
			if not on:
				c.material_overlay = _grey
