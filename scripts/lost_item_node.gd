extends Node3D
## One of the player's lost belongings lying in the street. From afar it
## is only a grey shape; it gets its real colours when the player is close
## (closer without glasses).

const LostItems = preload("res://scripts/lost_items.gd")

var id := ""
var main
var _model: Node3D
var _grey := StandardMaterial3D.new()
var _revealed := false


func setup(item_id: String) -> void:
	id = item_id
	_model = LostItems.build_mesh(id)
	_model.scale = Vector3.ONE * 2.2
	add_child(_model)
	_grey.albedo_color = Color(0.45, 0.45, 0.47)
	_grey.roughness = 1.0
	_set_revealed(false)


func _process(_delta: float) -> void:
	var p: Vector3 = main.player.position
	var d := Vector2(p.x - position.x, p.z - position.z).length()
	var reach := LostItems.REVEAL_DIST_NO_GLASSES if GameState.is_lost("glasses") else LostItems.REVEAL_DIST
	var want := d < reach
	if want != _revealed:
		_set_revealed(want)


func _set_revealed(on: bool) -> void:
	_revealed = on
	for c in _model.get_children():
		if c is MeshInstance3D:
			c.material_overlay = null
			c.transparency = 0.0
			if not on:
				c.material_overlay = _grey
