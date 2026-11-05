extends Node3D
## Prototype: one city block of Kirkkokatu, Oulu, between Pakkahuoneenkatu
## (left) and Hallituskatu (right). Builds the scene in code.
##
## Layout (X runs along Kirkkokatu, the camera looks towards -Z):
##   z -8 .. -20  buildings on the far side
##   z -8 .. -5   far sidewalk
##   z -5 .. 2.5  street
##   z 2.5 .. 5.8 near sidewalk, then lamps and trees in the foreground

const Player = preload("res://scripts/player.gd")
const Npc = preload("res://scripts/npc.gd")
const Item = preload("res://scripts/item.gd")
const Hud = preload("res://scripts/hud.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const TILT_SHIFT = preload("res://shaders/tilt_shift.gdshader")

const BLOCK_HALF := 16.0
const CROSS_HALF := 23.0
const NPC_COUNT := 5

const FACADE_COLORS := [Color(0.93, 0.83, 0.55), Color(0.85, 0.6, 0.45), Color(0.78, 0.78, 0.74),
	Color(0.72, 0.45, 0.36), Color(0.9, 0.9, 0.85), Color(0.62, 0.7, 0.72), Color(0.88, 0.72, 0.5)]

var player
var hud
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var tilt_mat: ShaderMaterial
var npcs: Array = []
var items: Array = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_build_environment()
	_build_street()
	_build_buildings()
	_build_props()
	_build_camera()
	_build_post_process()

	player = Player.new()
	player.main = self
	add_child(player)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Hud.new()
	hud.main = self
	hud_layer.add_child(hud)
	add_child(TouchControls.new())

	GameState.day_ended.connect(_on_day_ended)
	GameState.player_died.connect(_on_player_died)
	_reset_world()


func _process(delta: float) -> void:
	var target_x := clampf(player.position.x, -10.0, 10.0)
	camera.position.x = lerpf(camera.position.x, target_x, 1.0 - exp(-4.0 * delta))
	_update_sun()
	tilt_mat.set_shader_parameter("drunk",
		clampf((GameState.promille - GameState.PROMILLE_DRUNK) / 1.5, 0.0, 1.0))
	if hud.mode == "dead" and hud.card_time > 1.0 and Input.is_action_just_pressed("action"):
		GameState.new_game()
		_reset_world()
		hud.hide_card()


# --- Game flow -------------------------------------------------------------

func _reset_world() -> void:
	for n in npcs:
		n.queue_free()
	npcs.clear()
	for it in items:
		if is_instance_valid(it):
			it.queue_free()
	items.clear()
	player.reset(Vector3(-12.0, 0.0, 3.8))
	camera.position.x = -10.0
	for i in NPC_COUNT:
		_spawn_npc(false)
	spawn_item(Item.Kind.CAN, Vector3(-8.0, 0, 4.4))
	spawn_item(Item.Kind.BOTTLE, Vector3(-3.0, 0, -6.2))
	spawn_item(Item.Kind.COIN, Vector3(2.5, 0, 3.2), 2)
	spawn_item(Item.Kind.FOOD, Vector3(7.0, 0, -6.6))
	spawn_item(Item.Kind.CAN, Vector3(11.0, 0, 0.5))
	spawn_item(Item.Kind.COIN, Vector3(14.0, 0, -6.0), 1)


func _on_day_ended(cause: String) -> void:
	hud.show_card("day", tr("DAY_N") % (GameState.day + 1), tr(cause))
	await get_tree().create_timer(2.2).timeout
	GameState.new_day()
	_reset_world()
	hud.hide_card()


func _on_player_died(cause: String) -> void:
	hud.show_card("dead", tr(cause), tr("SCORE") % GameState.score())


# --- Queries used by the player, NPCs and items ------------------------------

func find_npc_in_front(pos: Vector3, facing: int, reach: float):
	var best = null
	var best_d := INF
	for n in npcs:
		if n.is_down():
			continue
		var dx: float = (n.position.x - pos.x) * facing
		var dz: float = absf(n.position.z - pos.z)
		if dx >= -0.2 and dx <= reach and dz < 0.55 and dx < best_d:
			best = n
			best_d = dx
	return best


## True on a raised sidewalk, false on the street (and at the crossings).
## Stepping from one to the other means crossing a curb.
func is_sidewalk(pos: Vector3) -> bool:
	var ax := absf(pos.x)
	if ax >= BLOCK_HALF and ax <= CROSS_HALF:
		return false
	return pos.z < -5.0 or (pos.z > 2.5 and pos.z < 5.8)


func npc_at(pos: Vector3, radius: float):
	for n in npcs:
		if n.is_down():
			continue
		if Vector2(n.position.x - pos.x, n.position.z - pos.z).length() < radius:
			return n
	return null


func nearest_npc_distance(pos: Vector3) -> float:
	var best := INF
	for n in npcs:
		if not n.is_down():
			best = minf(best, Vector2(n.position.x - pos.x, n.position.z - pos.z).length())
	return best


func spawn_item(kind: int, pos: Vector3, value := 1):
	var it = Item.new()
	it.main = self
	it.setup(kind, value)
	add_child(it)
	it.global_position = pos
	items.append(it)
	return it


func remove_item(it) -> void:
	items.erase(it)
	it.queue_free()


## What a knocked-out passer-by drops: alcohol, food, money or nothing.
func spawn_loot(pos: Vector3) -> void:
	var r := rng.randf()
	var p := Vector3(pos.x + rng.randf_range(-0.4, 0.4), 0.0, pos.z + rng.randf_range(0.2, 0.5))
	if r < 0.35:
		spawn_item(Item.Kind.BOTTLE, p)
	elif r < 0.55:
		spawn_item(Item.Kind.FOOD, p)
	elif r < 0.85:
		spawn_item(Item.Kind.COIN, p, rng.randi_range(1, 5))


func respawn_npc(n) -> void:
	npcs.erase(n)
	n.queue_free()
	_spawn_npc(true)


func popup(text: String, pos: Vector3, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Color.BLACK
	add_child(l)
	l.global_position = pos
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y + 1.0, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


func _spawn_npc(at_edge: bool) -> void:
	var n = Npc.new()
	n.main = self
	var d := 1 if rng.randf() < 0.5 else -1
	var x := -Npc.EDGE_X * d if at_edge else rng.randf_range(-6.0, 15.0)
	var z := rng.randf_range(-7.2, -5.6) if rng.randf() < 0.5 else rng.randf_range(3.0, 5.0)
	n.setup(rng, x, z, d)
	add_child(n)
	npcs.append(n)


# --- Scene building ------------------------------------------------------------

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.42, 0.8)
	sky_mat.sky_horizon_color = Color(0.6, 0.72, 0.85)
	sky_mat.ground_horizon_color = Color(0.6, 0.6, 0.6)
	sky_mat.ground_bottom_color = Color(0.3, 0.3, 0.3)
	sky.sky_material = sky_mat
	env.sky = sky
	# Neutral ambient so shadows don't turn deep blue.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.62, 0.66)
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	_update_sun()


## The sun moves with the game clock (which only runs while the player acts).
func _update_sun() -> void:
	var h := GameState.clock_min / 60.0
	var f := clampf((h - 5.0) / 17.0, 0.0, 1.0)
	var day_light := sin(f * PI)
	var elev := maxf(day_light * 50.0, 4.0)
	var az := lerpf(-75.0, 75.0, f)
	sun.rotation_degrees = Vector3(-elev, az, 0.0)
	sun.light_energy = 1.0 * smoothstep(0.0, 0.25, day_light)
	sun.light_color = Color(1.0, 0.85, 0.7).lerp(Color(1, 0.98, 0.94), smoothstep(0.0, 0.5, day_light))
	env.ambient_light_energy = 0.25 + 0.45 * smoothstep(0.0, 0.4, day_light)
	env.background_energy_multiplier = 0.15 + 0.85 * smoothstep(0.0, 0.4, day_light)


func _build_street() -> void:
	var asphalt := Color(0.22, 0.23, 0.25)
	var walk := Color(0.5, 0.48, 0.45)
	# Base ground far around.
	_box(Vector3(0, -0.2, -10), Vector3(160, 0.2, 100), Color(0.4, 0.4, 0.4))
	# Kirkkokatu: block section and the next blocks beyond the crossings.
	_box(Vector3(0, -0.05, -1.25), Vector3(BLOCK_HALF * 2, 0.1, 7.5), asphalt)
	for s in [-1, 1]:
		_box(Vector3(s * 41.5, -0.05, -1.25), Vector3(37, 0.1, 7.5), asphalt)
		# Crossing streets (Pakkahuoneenkatu left, Hallituskatu right).
		_box(Vector3(s * (BLOCK_HALF + CROSS_HALF) * 0.5, -0.05, -10), Vector3(CROSS_HALF - BLOCK_HALF, 0.1, 80), asphalt)
		# Zebra crossings across Kirkkokatu.
		for i in 9:
			_box(Vector3(s * (BLOCK_HALF + 1.6), 0.005, -4.6 + i * 0.85), Vector3(2.4, 0.02, 0.45), Color(0.92, 0.92, 0.9))
	# Centre line.
	var x := -45.0
	while x < 45.0:
		if absf(x) < BLOCK_HALF - 1.0 or absf(x) > CROSS_HALF + 1.0:
			_box(Vector3(x, 0.005, -1.25), Vector3(1.6, 0.02, 0.12), Color(0.9, 0.85, 0.6))
		x += 3.2
	# Sidewalks (raised = curb).
	for zc in [[-6.5, 3.0], [4.15, 3.3]]:
		_box(Vector3(0, 0.06, zc[0]), Vector3(BLOCK_HALF * 2, 0.12, zc[1]), walk)
		for s in [-1, 1]:
			_box(Vector3(s * 41.5, 0.06, zc[0]), Vector3(37, 0.12, zc[1]), walk)


func _build_buildings() -> void:
	# Far side of this block.
	var x := -BLOCK_HALF
	var idx := 0
	while x < BLOCK_HALF - 0.5:
		var w := minf(rng.randf_range(5.0, 8.0), BLOCK_HALF - x)
		var h := rng.randf_range(9.0, 16.0)
		_building(Vector3(x + w * 0.5, 0, -8.0), w, h, FACADE_COLORS[rng.randi() % FACADE_COLORS.size()], idx == 2)
		x += w
		idx += 1
	# Corner blocks beyond the crossings and a background row for depth.
	for s in [-1, 1]:
		_building(Vector3(s * (CROSS_HALF + 9.0), 0, -8.0), 18.0, rng.randf_range(10.0, 15.0),
			FACADE_COLORS[rng.randi() % FACADE_COLORS.size()], false)
	for i in 8:
		var bx := -42.0 + i * 12.0
		_box(Vector3(bx, 9.0, -34.0), Vector3(11.0, 18.0 + rng.randf_range(-3, 4), 8.0), Color(0.62, 0.64, 0.68))
	# Street name signs: names stay in Finnish in every language.
	_street_sign("Kirkkokatu", Vector3(-BLOCK_HALF + 1.6, 3.4, -7.94))
	_street_sign("Kirkkokatu", Vector3(BLOCK_HALF - 1.6, 3.4, -7.94))
	_street_sign("Pakkahuoneenkatu", Vector3(-CROSS_HALF - 2.2, 3.4, -7.94))
	_street_sign("Hallituskatu", Vector3(CROSS_HALF + 1.8, 3.4, -7.94))


func _building(base: Vector3, w: float, h: float, col: Color, kiosk: bool) -> void:
	var depth := 12.0
	_box(base + Vector3(0, h * 0.5, -depth * 0.5), Vector3(w, h, depth), col)
	# Roof edge.
	_box(base + Vector3(0, h + 0.15, -depth * 0.5), Vector3(w + 0.2, 0.3, depth + 0.2), col.darkened(0.35))
	var glass := Color(0.22, 0.3, 0.4)
	var floors := int((h - 3.5) / 3.0)
	var cols := maxi(1, int((w - 1.0) / 1.7))
	var step := (w - 1.0) / cols
	for f in floors:
		for c in cols:
			var wx := base.x - w * 0.5 + 0.5 + step * (c + 0.5)
			_box(Vector3(wx, 4.8 + f * 3.0, base.z + 0.03), Vector3(0.9, 1.4, 0.08), glass)
	# Street level: shop window and a door.
	_box(Vector3(base.x - w * 0.15, 1.5, base.z + 0.03), Vector3(w * 0.5, 1.8, 0.08), Color(0.3, 0.38, 0.45))
	_box(Vector3(base.x + w * 0.3, 1.1, base.z + 0.04), Vector3(1.1, 2.2, 0.1), Color(0.35, 0.22, 0.15))
	if kiosk:
		_box(Vector3(base.x - w * 0.15, 2.8, base.z + 0.08), Vector3(w * 0.55, 0.6, 0.1), Color(0.85, 0.15, 0.15))
		var l := Label3D.new()
		l.text = tr("SIGN_KIOSK")
		l.font_size = 72
		l.pixel_size = 0.006
		l.modulate = Color.WHITE
		l.outline_size = 0
		l.position = Vector3(base.x - w * 0.15, 2.8, base.z + 0.15)
		add_child(l)


func _street_sign(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.006
	l.modulate = Color.WHITE
	l.outline_size = 0
	l.position = pos + Vector3(0, 0, 0.06)
	add_child(l)
	var w := text.length() * 0.15 + 0.3
	_box(pos, Vector3(w, 0.4, 0.05), Color(0.1, 0.3, 0.7))


func _build_props() -> void:
	# Lamp posts on the near sidewalk.
	var x := -40.0
	while x <= 40.0:
		if absf(absf(x) - (BLOCK_HALF + CROSS_HALF) * 0.5) > 4.0:
			_cyl(Vector3(x, 2.0, 5.5), 0.07, 4.0, Color(0.2, 0.22, 0.25))
			_box(Vector3(x, 4.05, 5.2), Vector3(0.25, 0.12, 0.7), Color(0.2, 0.22, 0.25))
		x += 10.0
	# Trees on the far sidewalk (the foreground stays low so the player is
	# never hidden).
	for tx in [-34.0, -27.0, -13.0, -1.5, 8.5, 29.0, 36.0]:
		_cyl(Vector3(tx, 1.2, -7.3), 0.15, 2.4, Color(0.35, 0.25, 0.18))
		_sphere(Vector3(tx, 3.3, -7.3), 1.3, Color(0.25, 0.5, 0.24))
	# Low hedges in the foreground, blurred by tilt-shift.
	for hx in [-30.0, -20.0, -4.0, 4.0, 20.0, 30.0]:
		_box(Vector3(hx, 0.35, 7.0), Vector3(3.0, 0.7, 0.8), Color(0.22, 0.45, 0.22))
	for bx in [-8.0, 9.5]:
		_box(Vector3(bx, 0.45, 5.4), Vector3(1.8, 0.1, 0.5), Color(0.45, 0.3, 0.2))
		_box(Vector3(bx, 0.22, 5.4), Vector3(1.6, 0.44, 0.08), Color(0.2, 0.2, 0.2))
	# Trash bins on the far sidewalk.
	for bx in [-10.5, 4.0, 12.5]:
		_cyl(Vector3(bx, 0.5, -7.5), 0.3, 0.8, Color(0.2, 0.35, 0.25))


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 36.0
	camera.position = Vector3(0, 10.5, 17.0)
	add_child(camera)
	camera.look_at(Vector3(0, 0.6, -1.5))
	camera.current = true


func _build_post_process() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tilt_mat = ShaderMaterial.new()
	tilt_mat.shader = TILT_SHIFT
	rect.material = tilt_mat
	layer.add_child(rect)


# --- Mesh helpers ---------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
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


func _cyl(pos: Vector3, r: float, h: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = _mat(c)
	mi.position = pos
	add_child(mi)
	return mi


func _sphere(pos: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = _mat(c)
	mi.position = pos
	add_child(mi)
	return mi
