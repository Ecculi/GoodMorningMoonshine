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
const LostItemNode = preload("res://scripts/lost_item_node.gd")
const ModalUI = preload("res://scripts/modal_ui.gd")
const DebugTools = preload("res://scripts/debug_tools.gd")

## Battery use per second while the phone is open, by page.
const PHONE_DRAIN := [1.2, 1.8, 3.5]
const KIOSK_OPTIONS := [
	{"kind": "bottle", "price": 3, "alcohol": true},
	{"kind": "food", "price": 2, "alcohol": false},
	{"kind": "charge", "price": 0, "alcohol": false},
]
const BAR_OPTIONS := [
	{"kind": "pint", "price": 5, "alcohol": true},
]
const TILT_SHIFT = preload("res://shaders/tilt_shift.gdshader")
const CLOUD_SHADOW = preload("res://shaders/cloud_shadow.gdshader")
## Cloud drift in map coordinates (metres per second of active time).
const WIND := Vector2(1.6, 0.7)

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
var sky_mat: ProceduralSkyMaterial
var cloud_mat: ShaderMaterial
var clouds: Node3D
var _cloud_offset := Vector2.ZERO
## Sun direction used for projecting cloud shadows; fixed when entering a
## block so the shadows only drift with the wind.
var _cloud_sun_set := false
var level: Node3D
var segment: Vector3i = CityMap.START
var npcs: Array = []
var items: Array = []
var lost_nodes: Array = []
var rng := RandomNumberGenerator.new()

## Items left on the ground in blocks visited today: key -> [[kind, pos, value], ...].
## Cleared every morning, so the content changes daily.
var _block_items := {}
var _lock_hits := 0
## Phone and shop state (GameState.modal says which is open).
var phone_page := 0
## > 0 while the phone shows the blinking empty battery before closing.
var phone_dead_t := 0.0
const PHONE_DEAD_TIME := 1.6
var shop_type := ""
var shop_sel := 0
var shop_flash := ""
var shop_flash_t := 0.0
var _glare := 0.0
var _scrambled := {}
var _friend_refused := false
var _focus_y := 0.58


func _ready() -> void:
	rng.randomize()
	_build_environment()
	_build_clouds()
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
	var modal_ui = ModalUI.new()
	modal_ui.main = self
	hud_layer.add_child(modal_ui)
	add_child(TouchControls.new())
	add_child(DebugTools.new())

	GameState.day_ended.connect(_on_day_ended)
	GameState.player_died.connect(_on_player_died)
	_new_game()


func _process(delta: float) -> void:
	_process_modal(delta)
	_check_transitions()
	var target_x := clampf(player.position.x, -10.0, 10.0)
	camera.position.x = lerpf(camera.position.x, target_x, 1.0 - exp(-4.0 * delta))
	_update_sun()
	_update_focus(delta)
	tilt_mat.set_shader_parameter("drunk",
		clampf((GameState.promille - GameState.PROMILLE_DRUNK) / 1.5, 0.0, 1.0))
	_check_lost_pickups()
	_update_signs()
	if hud.mode == "dead" and hud.card_time > 1.0 and Input.is_action_just_pressed("action"):
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
	# (Small margin: positions are 32-bit floats, so a clamped -7.4 can read as
	# slightly below -7.4.)
	if p.z < Z_MIN - 0.05 or p.z > Z_MAX + 0.05:
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
	_cloud_sun_set = false
	level = BlockBuilder.build(seg, GameState.home_x if seg == GameState.home_seg else INF, GameState.home_type)
	add_child(level)
	player.position = pos
	player.facing = facing
	camera.position.x = clampf(pos.x, -10.0, 10.0)
	_populate_block()


func _clear_block_content() -> void:
	for ln in lost_nodes:
		ln.queue_free()
	lost_nodes.clear()
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
	for id in GameState.placements:
		var pl: Array = GameState.placements[id]
		if pl[0] == segment:
			var ln = LostItemNode.new()
			ln.main = self
			ln.setup(id)
			add_child(ln)
			ln.position = pl[1]
			lost_nodes.append(ln)


## Walking over one of your own lost things puts it straight back in place.
func _check_lost_pickups() -> void:
	if GameState.over:
		return
	for ln in lost_nodes.duplicate():
		var d := Vector2(ln.position.x - player.position.x, ln.position.z - player.position.z).length()
		if d < 0.7:
			GameState.find_item(ln.id)
			popup("+", ln.position + Vector3(0, 1.2, 0), Color(0.5, 1.0, 0.5))
			lost_nodes.erase(ln)
			ln.queue_free()


## Street signs and shop signs.
## - Glasses lost: the text is blurry, sharp only right next to the sign.
## - Drunk enough: from far away the sign shows random letters; closer, the
##   right letters in the wrong order; right at the pole, the real name.
## - Both: both effects at once.
const SIGN_RANDOM_DIST := 8.0
const SIGN_SHUFFLE_DIST := 1.8
const SIGN_SHARP_DIST := 1.5
const SIGN_GHOSTS := [Vector3(0.05, 0.03, 0), Vector3(-0.05, -0.02, 0), Vector3(0.02, -0.05, 0),
	Vector3(-0.03, 0.05, 0), Vector3(0.06, -0.01, 0), Vector3(-0.06, 0.01, 0)]


func _update_signs() -> void:
	var blind := GameState.is_lost("glasses")
	var drunk := GameState.promille > GameState.PROMILLE_DRUNK
	for l in get_tree().get_nodes_in_group("street_sign"):
		var real: String = l.get_meta("real_text")
		var d := Vector2(l.global_position.x - player.position.x, l.global_position.z - player.position.z).length()
		var want := real
		if drunk:
			if d > SIGN_RANDOM_DIST:
				want = _random_letters(real)
			elif d > SIGN_SHUFFLE_DIST:
				want = _scramble(real)
		if l.text != want:
			l.text = want
		var blur := clampf((d - SIGN_SHARP_DIST) / 6.0, 0.0, 1.0) if blind else 0.0
		_set_sign_blur(l, blur)


## Blur a Label3D by showing faint offset copies instead of the sharp text.
func _set_sign_blur(l: Label3D, blur: float) -> void:
	var ghosts: Array = l.get_meta("ghosts", [])
	if blur <= 0.0:
		l.modulate.a = 1.0
		for g in ghosts:
			g.visible = false
		return
	if ghosts.is_empty():
		for off in SIGN_GHOSTS:
			var g := Label3D.new()
			g.font_size = l.font_size
			g.pixel_size = l.pixel_size
			g.outline_size = 0
			l.add_child(g)
			ghosts.append(g)
		l.set_meta("ghosts", ghosts)
	l.modulate.a = lerpf(1.0, 0.15, blur)
	for i in ghosts.size():
		var g: Label3D = ghosts[i]
		g.visible = true
		g.text = l.text
		g.position = SIGN_GHOSTS[i] * (0.4 + blur * 1.6)
		g.modulate = Color(1, 1, 1, 0.22 * blur)


func _scramble(text: String) -> String:
	var key := "s:" + text
	if _scrambled.has(key):
		return _scrambled[key]
	var r := RandomNumberGenerator.new()
	r.seed = hash(text)
	var chars := text.split("")
	for i in range(chars.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t := chars[i]
		chars[i] = chars[j]
		chars[j] = t
	var out := "".join(chars)
	_scrambled[key] = out
	return out


func _random_letters(text: String) -> String:
	var key := "r:" + text
	if _scrambled.has(key):
		return _scrambled[key]
	var r := RandomNumberGenerator.new()
	r.seed = hash(text) + 7
	var letters := "ABDEHIJKLMNOPRSTUVYÄÖ"
	var out := ""
	for i in text.length():
		var c := letters[r.randi() % letters.length()]
		out += c if i == 0 else c.to_lower()
	_scrambled[key] = out
	return out


# --- Phone and shops -----------------------------------------------------------

func open_phone() -> void:
	if GameState.over or GameState.modal != "":
		return
	if GameState.is_lost("phone"):
		# Thought bubble: the phone, crossed out.
		hud.think(["phone"])
		return
	GameState.modal = "phone"
	phone_page = 0
	phone_dead_t = PHONE_DEAD_TIME if GameState.battery <= 0.0 else 0.0


func shop_options() -> Array:
	return KIOSK_OPTIONS if shop_type == "kiosk" else BAR_OPTIONS


## Phone: left/right browse, down + action closes; the battery drains in
## real time (the world is frozen). Shop: left/right choose, action buys,
## down leaves.
func _process_modal(delta: float) -> void:
	shop_flash_t = maxf(0.0, shop_flash_t - delta)
	match GameState.modal:
		"phone":
			# Empty battery: show the blinking empty battery, then close.
			if phone_dead_t > 0.0:
				phone_dead_t -= delta
				if phone_dead_t <= 0.0:
					phone_dead_t = 0.0
					_close_modal()
				return
			if Input.is_action_just_pressed("move_left"):
				phone_page = (phone_page + 2) % 3
			elif Input.is_action_just_pressed("move_right"):
				phone_page = (phone_page + 1) % 3
			GameState.battery = maxf(0.0, GameState.battery - PHONE_DRAIN[phone_page] * delta)
			# Close: down + action in either order, or the phone key again.
			var close := (Input.is_action_just_pressed("action") and Input.is_action_pressed("move_down")) \
				or (Input.is_action_just_pressed("move_down") and Input.is_action_pressed("action")) \
				or Input.is_action_just_pressed("phone")
			if close:
				_close_modal()
			elif GameState.battery <= 0.0:
				phone_dead_t = PHONE_DEAD_TIME
		"shop":
			var opts := shop_options()
			if Input.is_action_just_pressed("move_left"):
				shop_sel = (shop_sel + opts.size() - 1) % opts.size()
			elif Input.is_action_just_pressed("move_right"):
				shop_sel = (shop_sel + 1) % opts.size()
			elif Input.is_action_just_pressed("move_down"):
				_close_modal()
			elif Input.is_action_just_pressed("action"):
				_buy(opts[shop_sel])


## The button press that closed the overlay must not also punch.
func _close_modal() -> void:
	GameState.modal = ""
	player._block_action = true


func _buy(o: Dictionary) -> void:
	var price: int = o["price"]
	if price > 0 and GameState.is_lost("wallet"):
		_shop_fail("wallet")
		return
	if o["alcohol"] and GameState.is_lost("idcard"):
		_shop_fail("idcard")
		return
	if GameState.money < price:
		_shop_fail("money")
		return
	GameState.money -= price
	match o["kind"]:
		"bottle":
			player._pickup(spawn_item(Item.Kind.BOTTLE, player.position))
		"food":
			player._pickup(spawn_item(Item.Kind.FOOD, player.position))
		"pint":
			GameState.drink(0.5)
		"charge":
			# Charging is a trade: time jumps ahead, alcohol goes down.
			GameState.battery = minf(100.0, GameState.battery + 15.0)
			GameState.clock_min += 30.0
			GameState.promille = maxf(0.05, GameState.promille - 0.12)
	shop_flash = ""


func _shop_fail(what: String) -> void:
	shop_flash = what
	shop_flash_t = 1.2


func _shop_at(pos: Vector3):
	if level == null or not level.has_meta("shops") or pos.z > -6.0:
		return null
	for sh in level.get_meta("shops"):
		if absf(pos.x - sh["x"]) < 0.9:
			return sh
	return null


## Shops are open or closed for the whole day (random per day and shop).
func _shop_open(sh: Dictionary) -> bool:
	var h := hash([GameState.day, segment, int(sh["x"] * 10.0), GameState.home_seg])
	return absi(h) % 10 < 8


func _try_shop(sh: Dictionary) -> bool:
	var door := Vector3(sh["x"], 2.2, -7.4)
	if not _shop_open(sh):
		popup("X", door, Color(0.9, 0.3, 0.3))
		return true
	if sh["type"] == "bar":
		# The bouncer: no shoes, no entry; too drunk is turned away, but a
		# borderline case can be fixed with a fiver.
		var p := GameState.promille
		var ok := not GameState.is_lost("shoes") and p <= 2.5
		if not ok and not GameState.is_lost("shoes") and p <= 3.0 and GameState.money >= 5:
			GameState.money -= 5
			popup("-5 €", door, Color(1, 0.85, 0.3))
			ok = true
		if not ok:
			popup("X", door + Vector3(1.0, 0, 0), Color(0.9, 0.3, 0.3))
			player.take_hit(3.0, sh["x"] + 2.0)
			return true
	shop_type = sh["type"]
	shop_sel = 0
	shop_flash = ""
	GameState.modal = "shop"
	return true


## Short action at a door: the home door ends the day, shop doors open the
## counter.
func try_enter_door(pos: Vector3) -> bool:
	if GameState.over:
		return false
	var sh = _shop_at(pos)
	if sh != null:
		return _try_shop(sh)
	if segment != GameState.home_seg:
		return false
	if absf(pos.x - GameState.home_x) > 0.9 or pos.z > -6.0:
		return false
	var door := Vector3(GameState.home_x, 2.2, -7.4)
	match GameState.home_type:
		"flat":
			GameState.go_home("stairs" if GameState.is_lost("keys") else "home")
		"basement":
			if GameState.is_lost("keys") and not GameState.lock_broken:
				# No keys: smash the padlock (three hits).
				player.model.punch()
				GameState.busy_time = maxf(GameState.busy_time, 0.35)
				_lock_hits += 1
				popup("*", door, Color(1, 0.9, 0.4))
				if _lock_hits >= 3:
					GameState.lock_broken = true
					popup("!", door + Vector3(0, 0.4, 0), Color(1, 0.4, 0.3))
				return true
			GameState.go_home("basement")
		"friend":
			# Ring the bell. A drink in hand always gets you in; otherwise the
			# friend may be asleep and not open (for the rest of the day).
			var hand = player.hand_item
			if hand != null and hand.kind == Item.Kind.BOTTLE:
				items.erase(hand)
				hand.queue_free()
				player.hand_item = null
				GameState.go_home("friend")
			elif not _friend_refused and rng.randf() < 0.5:
				GameState.go_home("friend")
			else:
				_friend_refused = true
				GameState.busy_time = maxf(GameState.busy_time, 0.35)
				popup("Zzz", door, Color(0.8, 0.85, 1.0))
	return true


## Where the day starts: one step out from the home door.
func _home_door_pos() -> Vector3:
	return Vector3(GameState.home_x, 0, -5.4)


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

## A new game starts at the home door, after checking the pockets.
func _new_game() -> void:
	GameState.new_game()
	_lock_hits = 0
	_friend_refused = false
	_block_items.clear()
	player.reset(Vector3.ZERO)
	_enter_block(GameState.home_seg, _home_door_pos(), 1)
	hud.show_pocket_check()


## From day 2 on the character wakes up somewhere other than home (they
## went out again during the night); further away every day.
func _new_day() -> void:
	_block_items.clear()
	_friend_refused = false
	_enter_block(GameState.wake_seg, GameState.wake_pos, 1 if rng.randf() < 0.5 else -1)
	hud.show_pocket_check()


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
	sky_mat = ProceduralSkyMaterial.new()
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
	var cloudy := GameState.weather == "cloudy"
	# Overcast: soft light, no sharp shadows.
	sun.shadow_enabled = not cloudy
	sun.light_energy = (0.25 if cloudy else 1.0) * smoothstep(0.0, 0.25, day_light)
	sun.light_color = Color(1.0, 0.85, 0.7).lerp(Color(1, 0.98, 0.94), smoothstep(0.0, 0.5, day_light))
	env.ambient_light_energy = (0.35 + 0.55 * smoothstep(0.0, 0.4, day_light)) * (1.45 if cloudy else 1.0)
	sky_mat.sky_top_color = Color(0.55, 0.58, 0.62) if cloudy else Color(0.2, 0.42, 0.8)
	sky_mat.sky_horizon_color = Color(0.72, 0.74, 0.76) if cloudy else Color(0.6, 0.72, 0.85)
	# Without sunglasses, facing the sun on a sunny day dazzles; a low sun
	# is the worst.
	var want_glare := 0.0
	if not cloudy and GameState.is_lost("sunglasses") and day_light > 0.1:
		var low := 1.0 - clampf(rad_to_deg(elev) / 45.0, 0.0, 1.0) * 0.5
		want_glare = clampf(player.facing * to_sun.x * 1.2 + maxf(0.0, -to_sun.z) * 0.5, 0.0, 1.0) * low * 0.8
	_glare = lerpf(_glare, want_glare, 0.05)
	tilt_mat.set_shader_parameter("glare", _glare)
	# Cloud shadows only on sunny days; they drift while time moves.
	clouds.visible = not cloudy and day_light > 0.15
	if clouds.visible:
		var a := deg_to_rad(CityMap.VIEW_AZIMUTH[segment.x])
		# Map wind (east, north) to screen axes (right = +x, forward = -z).
		var right := Vector2(cos(a), -sin(a))
		var fwd := Vector2(sin(a), cos(a))
		var w := Vector2(WIND.dot(right), -WIND.dot(fwd))
		_cloud_offset -= w * GameState.world_dt
		cloud_mat.set_shader_parameter("offset", _cloud_offset)
		if not _cloud_sun_set:
			cloud_mat.set_shader_parameter("to_sun", to_sun)
			_cloud_sun_set = true
	env.background_energy_multiplier = 0.15 + 0.85 * smoothstep(0.0, 0.4, day_light)


func _build_clouds() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.008
	noise.fractal_octaves = 2
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	cloud_mat = ShaderMaterial.new()
	cloud_mat.shader = CLOUD_SHADOW
	cloud_mat.set_shader_parameter("noise_tex", tex)
	clouds = Node3D.new()
	add_child(clouds)
	# Over the street and sidewalks...
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 80)
	ground.mesh = pm
	ground.material_override = cloud_mat
	ground.position = Vector3(0, 0.14, -14)
	clouds.add_child(ground)
	# ...and in front of the facades.
	var wall := MeshInstance3D.new()
	var wm := QuadMesh.new()
	wm.size = Vector2(120, 22)
	wall.mesh = wm
	wall.material_override = cloud_mat
	wall.position = Vector3(0, 11, -7.7)
	clouds.add_child(wall)


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
