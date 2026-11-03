extends Node3D
## Game world: shows one block of the Oulu city centre at a time.
## Walking past the end of a block continues to the next block of the same
## street; walking up or down a crossing street at an intersection turns 90°
## onto that street. See city_map.gd and block_builder.gd.

const Player = preload("res://scripts/player.gd")
const Npc = preload("res://scripts/npc.gd")
const Item = preload("res://scripts/item.gd")
const Hud = preload("res://scripts/hud.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const CityMap = preload("res://scripts/city_map.gd")
const BlockBuilder = preload("res://scripts/block_builder.gd")
const TILT_SHIFT = preload("res://shaders/tilt_shift.gdshader")

const BLOCK_HALF := BlockBuilder.BLOCK_HALF
const CROSS_HALF := BlockBuilder.CROSS_HALF
const CROSS_CENTER := (BLOCK_HALF + CROSS_HALF) * 0.5
const STREET_Z := BlockBuilder.STREET_Z
## Walkable band along the street (sidewalk to sidewalk).
const Z_MIN := -7.4
const Z_MAX := 5.2
## How far up/down a crossing street the player walks before the view turns.
const TURN_UP_Z := -11.0
const TURN_DOWN_Z := 8.0
## How far past the block end the player walks before the next block.
const NEXT_BLOCK_X := 24.5
const EDGE_LIMIT_X := 21.0

var player
var hud
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var tilt_mat: ShaderMaterial
var level: Node3D
var segment: Vector3i = CityMap.START
var npcs: Array = []
var items: Array = []
var rng := RandomNumberGenerator.new()

## Items left on the ground in blocks visited today: key -> [[kind, pos, value], ...].
## Cleared every morning, so the content changes daily.
var _block_items := {}
var _focus_y := 0.58


func _ready() -> void:
	rng.randomize()
	_build_environment()
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
	_new_game()


func _process(delta: float) -> void:
	_check_transitions()
	var target_x := clampf(player.position.x, -10.0, 10.0)
	camera.position.x = lerpf(camera.position.x, target_x, 1.0 - exp(-4.0 * delta))
	_update_sun()
	_update_focus(delta)
	tilt_mat.set_shader_parameter("drunk",
		clampf((GameState.promille - GameState.PROMILLE_DRUNK) / 1.5, 0.0, 1.0))
	if hud.mode == "dead" and hud.card_time > 1.0 and Input.is_action_just_pressed("action"):
		GameState.new_game()
		_new_game()
		hud.hide_card()


# --- Moving around the map ------------------------------------------------------

## Keeps the player on walkable ground: the street band, plus the crossing
## streets at both ends where the map continues.
func clamp_walkable(p: Vector3) -> Vector3:
	var max_x := NEXT_BLOCK_X + 0.5 if CityMap.is_valid(CityMap.next_along(segment, 1)) else EDGE_LIMIT_X
	var min_x := -NEXT_BLOCK_X - 0.5 if CityMap.is_valid(CityMap.next_along(segment, -1)) else -EDGE_LIMIT_X
	p.x = clampf(p.x, min_x, max_x)
	var right := p.x > 0.0
	var ax := absf(p.x)
	var in_cross := ax > BLOCK_HALF + 0.4 and ax < CROSS_HALF - 0.4
	var z_min := TURN_UP_Z - 0.5 if in_cross and CityMap.can_turn(segment, right, true) else Z_MIN
	var z_max := TURN_DOWN_Z + 0.5 if in_cross and CityMap.can_turn(segment, right, false) else Z_MAX
	p.z = clampf(p.z, z_min, z_max)
	# Off the street band only inside the crossing street.
	if p.z < Z_MIN or p.z > Z_MAX:
		p.x = signf(p.x) * clampf(ax, BLOCK_HALF + 0.4, CROSS_HALF - 0.4)
	return p


func _check_transitions() -> void:
	if GameState.over:
		return
	var p: Vector3 = player.position
	if p.x >= NEXT_BLOCK_X:
		_go_to(CityMap.next_along(segment, 1), Vector3(-NEXT_BLOCK_X + 0.5, 0, p.z), 1)
	elif p.x <= -NEXT_BLOCK_X:
		_go_to(CityMap.next_along(segment, -1), Vector3(NEXT_BLOCK_X - 0.5, 0, p.z), -1)
	elif p.z <= TURN_UP_Z:
		_turn(p.x > 0.0, true)
	elif p.z >= TURN_DOWN_Z:
		_turn(p.x > 0.0, false)


func _turn(at_right: bool, up: bool) -> void:
	var t := CityMap.turn(segment, at_right, up)
	var enter_right: bool = t["enter_right"]
	var x := CROSS_CENTER if enter_right else -CROSS_CENTER
	_go_to(t["seg"], Vector3(x, 0, STREET_Z), -1 if enter_right else 1)


func _go_to(seg: Vector3i, pos: Vector3, facing: int) -> void:
	if not CityMap.is_valid(seg):
		return
	_save_block_items()
	_enter_block(seg, pos, facing)
	hud.fade_in()


func _enter_block(seg: Vector3i, pos: Vector3, facing: int) -> void:
	_clear_block_content()
	segment = seg
	if level != null:
		level.queue_free()
	level = BlockBuilder.build(seg)
	add_child(level)
	player.position = pos
	player.facing = facing
	camera.position.x = clampf(pos.x, -10.0, 10.0)
	_populate_block()


func _clear_block_content() -> void:
	for n in npcs:
		n.queue_free()
	npcs.clear()
	var keep = player.hand_item
	for it in items:
		if is_instance_valid(it) and it != keep:
			it.queue_free()
	items.clear()
	if keep != null:
		items.append(keep)


func _save_block_items() -> void:
	var saved := []
	for it in items:
		if is_instance_valid(it) and it != player.hand_item and it.state == Item.St.GROUND:
			saved.append([it.kind, it.global_position, it.value])
	_block_items[_key(segment)] = saved


func _populate_block() -> void:
	var key := _key(segment)
	if _block_items.has(key):
		for entry in _block_items[key]:
			spawn_item(entry[0], entry[1], entry[2])
	else:
		for i in rng.randi_range(2, 5):
			var r := rng.randf()
			var kind: int = Item.Kind.CAN
			if r < 0.15:
				kind = Item.Kind.BOTTLE
			elif r < 0.35:
				kind = Item.Kind.FOOD
			elif r < 0.65:
				kind = Item.Kind.COIN
			spawn_item(kind, Vector3(rng.randf_range(-15.0, 15.0), 0, _random_z()), rng.randi_range(1, 3))
	for i in rng.randi_range(2, 5):
		_spawn_npc(false)


func _key(seg: Vector3i) -> String:
	return "%d_%d_%d" % [seg.x, seg.y, seg.z]


func _random_z() -> float:
	var r := rng.randf()
	if r < 0.4:
		return rng.randf_range(-7.2, -5.4)
	if r < 0.8:
		return rng.randf_range(3.0, 5.0)
	return rng.randf_range(-4.5, 2.0)


# --- Game flow -------------------------------------------------------------------

func _new_game() -> void:
	_block_items.clear()
	player.reset(Vector3.ZERO)
	_enter_block(CityMap.random_segment(rng), Vector3(-12.0, 0, 3.8), 1)


## The next day starts where the character fell asleep.
func _new_day() -> void:
	_block_items.clear()
	var p: Vector3 = player.position
	p.x = clampf(p.x, -BLOCK_HALF + 1.0, BLOCK_HALF - 1.0)
	p.z = clampf(p.z, Z_MIN, Z_MAX)
	_enter_block(segment, p, player.facing)


func _on_day_ended(cause: String) -> void:
	hud.show_card("day", tr("DAY_N") % (GameState.day + 1), tr(cause))
	await get_tree().create_timer(2.2).timeout
	GameState.new_day()
	_new_day()
	hud.hide_card()


func _on_player_died(cause: String) -> void:
	hud.show_card("dead", tr(cause), tr("SCORE") % GameState.score())


# --- Queries used by the player, NPCs and items -------------------------------------

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
	var x := -Npc.EDGE_X * d
	if not at_edge:
		# Not right next to the player.
		x = rng.randf_range(-15.0, 15.0)
		if absf(x - player.position.x) < 4.0:
			x = clampf(x + 8.0 * signf(x - player.position.x + 0.01), -15.0, 15.0)
	var z := rng.randf_range(-7.2, -5.6) if rng.randf() < 0.5 else rng.randf_range(3.0, 5.0)
	n.setup(rng, x, z, d)
	add_child(n)
	npcs.append(n)


# --- Light, camera, post-processing -------------------------------------------------

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


## The sun always shines from the same compass direction on the map and
## moves with the game clock. On screen its direction depends on which way
## the current street runs, so it (and the shadows) turn with the view.
func _update_sun() -> void:
	var h := GameState.clock_min / 60.0
	var f := clampf((h - 5.0) / 17.0, 0.0, 1.0)
	var day_light := sin(f * PI)
	var elev := deg_to_rad(maxf(day_light * 45.0, 4.0))
	var sun_az := lerpf(60.0, 300.0, f)  # east in the morning, south at noon, west in the evening
	var rel := deg_to_rad(sun_az - CityMap.VIEW_AZIMUTH[segment.x])
	# Screen: forward (camera look) = -Z, right = +X.
	var to_sun := Vector3(cos(elev) * sin(rel), sin(elev), -cos(elev) * cos(rel))
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	sun.light_energy = 1.0 * smoothstep(0.0, 0.25, day_light)
	sun.light_color = Color(1.0, 0.85, 0.7).lerp(Color(1, 0.98, 0.94), smoothstep(0.0, 0.5, day_light))
	env.ambient_light_energy = 0.35 + 0.55 * smoothstep(0.0, 0.4, day_light)
	env.background_energy_multiplier = 0.15 + 0.85 * smoothstep(0.0, 0.4, day_light)


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


## The sharp tilt-shift band follows the player vertically on screen.
func _update_focus(delta: float) -> void:
	var p: Vector3 = player.global_position + Vector3(0, 0.9, 0)
	if camera.is_position_behind(p):
		return
	var h := get_viewport().get_visible_rect().size.y
	var target := clampf(camera.unproject_position(p).y / h, 0.15, 0.9)
	_focus_y = lerpf(_focus_y, target, 1.0 - exp(-6.0 * delta))
	tilt_mat.set_shader_parameter("focus_center", _focus_y)
