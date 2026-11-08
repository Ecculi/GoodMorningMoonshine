extends Node3D
## Game world: shows one block of the Oulu city centre at a time.
## Walking past the end of a block continues to the next block of the same
## street; walking up or down a crossing street at an intersection turns 90°
## onto that street. See city_map.gd and block_builder.gd.

const Player = preload("res://scripts/player.gd")
const Npc = preload("res://scripts/npc.gd")
const Animal = preload("res://scripts/animal.gd")
const Vision = preload("res://scripts/vision.gd")
const Rider = preload("res://scripts/rider.gd")
const Glass = preload("res://scripts/glass.gd")
const Item = preload("res://scripts/item.gd")
const Hud = preload("res://scripts/hud.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const Leaves = preload("res://scripts/leaves.gd")
const CityMap = preload("res://scripts/city_map.gd")
const BlockBuilder = preload("res://scripts/block_builder.gd")
const LostItemNode = preload("res://scripts/lost_item_node.gd")
const ModalUI = preload("res://scripts/modal_ui.gd")
const DebugTools = preload("res://scripts/debug_tools.gd")
const Car = preload("res://scripts/car.gd")

## Battery use per second while the phone is open, by page.
## Battery per second of use, by page. Drains only while the phone is open.
const PHONE_DRAIN := [0.15, 0.225, 0.45]
const KIOSK_OPTIONS := [
	{"kind": "bottle", "price": 3, "alcohol": true},
	{"kind": "food", "price": 2, "alcohol": false},
	{"kind": "energy", "price": 3, "alcohol": false},
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
var segment: Vector3i = CityMap.start()
var npcs: Array = []
## Seagulls and dogs in the current block.
var animals: Array = []
## Debug tools (F1 + F12); the HUD draws police vision cones while on.
var debug_tools
## Cyclists and e-scooters on the sidewalks (from day 4).
var riders: Array = []
var _rider_timer := 5.0
## Punk gangs that already met the player (each offers a beer at most once).
var _punk_met := {}
var _next_gang := 0
var items: Array = []
var lost_nodes: Array = []
var cars: Array = []
var _car_timer := 3.0
var rng := RandomNumberGenerator.new()

## Items left on the ground in blocks visited today: key -> [[kind, pos, value], ...].
## Cleared every morning, so the content changes daily.
var _block_items := {}
## The block's wind (leaves.gd); on a storm day it pushes people and
## thrown things too.
var wind_field = null


## Storm wind at `pos` (zero on an ordinary day).
func wind_at(pos: Vector3) -> Vector3:
	if not GameState.storm or wind_field == null or not is_instance_valid(wind_field):
		return Vector3.ZERO
	return wind_field.wind_at(pos)


## Broken glass in this block, and in the blocks visited today
## (key -> [[position, colour], ...]).
var glass: Array = []
var _block_glass := {}
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


## 0..1: how far the player shades the eyes with a hand (dazzled).
func shade_amount() -> float:
	return smoothstep(0.18, 0.4, _glare)
var _scrambled := {}
var _friend_refused := false
var _focus_y := 0.58


func _ready() -> void:
	rng.randomize()
	_build_environment()
	_build_physics_ground()
	_build_clouds()
	_build_precipitation()
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
	debug_tools = DebugTools.new()
	add_child(debug_tools)

	GameState.day_ended.connect(_on_day_ended)
	GameState.achievement_unlocked.connect(func(id): hud.show_achievement(id))
	GameState.player_died.connect(_on_player_died)
	_new_game()


func _process(delta: float) -> void:
	_process_modal(delta)
	_update_trip(delta)
	_check_transitions()
	_update_followers()
	_update_traffic()
	var target_x := clampf(player.position.x, -10.0, 10.0)
	camera.position.x = lerpf(camera.position.x, target_x, 1.0 - exp(-4.0 * delta))
	_update_shake(delta)
	_update_sun()
	_update_focus(delta)
	tilt_mat.set_shader_parameter("double_vision", _towards_passout(2.3))
	_update_drunk_circle()
	_check_lost_pickups()
	_check_arrest()
	_update_signs()
	if hud.mode == "dead" and hud.card_time > 1.0 and Input.is_action_just_pressed("action"):
		_new_game()
		hud.hide_card()


# --- Moving around the map ------------------------------------------------------

## Keeps the player on walkable ground: the street band, plus the crossing
## streets at both ends where the map continues.
func clamp_walkable(p: Vector3) -> Vector3:
	var max_x := NEXT_BLOCK_X + 0.5 if CityMap.is_open(CityMap.next_along(segment, 1)) else EDGE_LIMIT_X
	var min_x := -NEXT_BLOCK_X - 0.5 if CityMap.is_open(CityMap.next_along(segment, -1)) else -EDGE_LIMIT_X
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
	# Walked out of the picture at the left or right: on to the next block
	# as soon as the character has fully disappeared from view.
	var off := _offscreen_side()
	if off != 0 and off == player.facing and p.z >= Z_MIN - 0.05 and p.z <= Z_MAX + 0.05 \
			and CityMap.is_open(CityMap.next_along(segment, off)):
		_go_to(CityMap.next_along(segment, off), Vector3(-off * (NEXT_BLOCK_X - 0.5), 0, p.z), off)
		# Start just outside the view on the other side, walking in.
		var edge := _view_edge_x(-off, p.z)
		var x := clampf(edge - off * 0.7, -(NEXT_BLOCK_X - 0.5), NEXT_BLOCK_X - 0.5)
		player.position.x = x
		return
	if p.x >= NEXT_BLOCK_X:
		_go_to(CityMap.next_along(segment, 1), Vector3(-NEXT_BLOCK_X + 0.5, 0, p.z), 1)
	elif p.x <= -NEXT_BLOCK_X:
		_go_to(CityMap.next_along(segment, -1), Vector3(NEXT_BLOCK_X - 0.5, 0, p.z), -1)
	elif p.z <= TURN_UP_Z:
		_turn(p.x > 0.0, true)
	elif p.z >= TURN_DOWN_Z:
		_turn(p.x > 0.0, false)


## 1 / -1 when the player is completely out of view on the right / left,
## otherwise 0.
func _offscreen_side() -> int:
	var side := 0
	for k in 4:
		var q: Vector3 = player.global_position + Vector3(0.45 if k % 2 == 0 else -0.45, 0.0 if k < 2 else 1.9, 0)
		if camera.is_position_behind(q):
			return 0
		var sx := camera.unproject_position(q).x
		var sd := 1 if sx > play_right else (-1 if sx < play_left else 0)
		if sd == 0 or (side != 0 and sd != side):
			return 0
		side = sd
	return side


## World x of the left (-1) or right (1) edge of the view at depth z and
## about waist height.
func _view_edge_x(side: int, z: float) -> float:
	var sy := camera.unproject_position(Vector3(camera.position.x, 0.9, z)).y
	var ex := play_left if side < 0 else play_right
	var o := camera.project_ray_origin(Vector2(ex, sy))
	var d := camera.project_ray_normal(Vector2(ex, sy))
	if absf(d.z) < 0.0001:
		return camera.position.x + side * 15.0
	var t := (z - o.z) / d.z
	return o.x + d.x * t


func _turn(at_right: bool, up: bool) -> void:
	var t := CityMap.turn(segment, at_right, up)
	var enter_right: bool = t["enter_right"]
	var x := CROSS_CENTER if enter_right else -CROSS_CENTER
	_go_to(t["seg"], Vector3(x, 0, STREET_Z), -1 if enter_right else 1)


## Extra head start (metres) the player gets on pursuers when changing
## street.
const FOLLOW_HEAD_START := 4.0


func _go_to(seg: Vector3i, pos: Vector3, facing: int) -> void:
	if not CityMap.is_open(seg):
		return
	# Pursuers (fighting passers-by, chasing police, guards) follow to the
	# next street, a little further behind than they were.
	var followers: Array = []
	for n in npcs:
		# (A bouncer never leaves the door's street.)
		if n.is_hostile() and not n.is_down() and n.role != "bouncer":
			var d := Vector2(n.position.x - player.position.x, n.position.z - player.position.z).length()
			if d < 16.0:
				followers.append([n.role, d, n.state, n.hp])
	_save_block_items()
	_enter_block(seg, pos, facing)
	# They arrive through the same spot, after the time it takes them to
	# cover their distance plus the head start.
	_pending_followers.clear()
	for f in followers:
		var spd: float = Npc.POLICE_SPEED if f[0] == "police" else Npc.CHASE_SPEED
		_pending_followers.append({"role": f[0], "state": f[2], "hp": f[3], "pos": pos, "dir": facing,
			"t": (f[1] + FOLLOW_HEAD_START) / spd})
	hud.fade_in()


var _pending_followers: Array = []


func _update_followers() -> void:
	var dt := GameState.world_dt
	if dt <= 0.0:
		return
	for f in _pending_followers.duplicate():
		f["t"] -= dt
		if f["t"] > 0.0:
			continue
		_pending_followers.erase(f)
		var n = _spawn_npc(false, f["role"])
		n.position = f["pos"]
		n.dir = f["dir"]
		n.hp = f["hp"]
		n.stationary = false
		n.model.sitting = false
		n.state = f["state"]
		n._mark.visible = true


func _enter_block(seg: Vector3i, pos: Vector3, facing: int) -> void:
	_clear_block_content()
	segment = seg
	if level != null:
		level.queue_free()
	_cloud_sun_set = false
	level = BlockBuilder.build(seg, GameState.home_x if seg == GameState.home_seg else INF, GameState.home_type)
	add_child(level)
	# Wind-blown leaves on the street.
	var leaves = Leaves.new()
	level.add_child(leaves)
	leaves.main = self
	leaves.setup(seg, GameState.weather)
	wind_field = leaves
	player.position = pos
	player.facing = facing
	camera.position.x = clampf(pos.x, -10.0, 10.0)
	_populate_block()


func _clear_block_content() -> void:
	for c in cars:
		c.queue_free()
	cars.clear()
	_car_timer = rng.randf_range(2.0, 8.0)
	for ln in lost_nodes:
		ln.queue_free()
	lost_nodes.clear()
	for n in npcs:
		n.queue_free()
	npcs.clear()
	for a in animals:
		a.queue_free()
	animals.clear()
	for rd in riders:
		rd.queue_free()
	riders.clear()
	for g in glass:
		g.queue_free()
	glass.clear()
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
			saved.append([it.kind, it.global_position, it.value, it.drink])
	_block_items[_key(segment)] = saved
	var shards := []
	for g in glass:
		shards.append([g.position, g.get_meta("color")])
	_block_glass[_key(segment)] = shards


func _populate_block() -> void:
	var key := _key(segment)
	for entry in _block_glass.get(key, []):
		spawn_glass(entry[0], entry[1])
	if _block_items.has(key):
		for entry in _block_items[key]:
			spawn_item(entry[0], entry[1], entry[2], entry[3])
	else:
		for i in rng.randi_range(2, 5):
			var r := rng.randf()
			var kind: int = Item.Kind.CAN
			if r < 0.03:
				kind = Item.Kind.COFFEE  # rare
			elif r < 0.06:
				kind = Item.Kind.ENERGY  # rare
			elif r < 0.30:
				kind = Item.Kind.BOTTLE
			elif r < 0.50:
				kind = Item.Kind.FOOD
			elif r < 0.75:
				kind = Item.Kind.COIN
			spawn_item(kind, Vector3(rng.randf_range(-15.0, 15.0), 0, _random_z()), rng.randi_range(1, 3))
	for i in rng.randi_range(2, 5):
		_spawn_npc(false)
	# Police patrol some blocks (more of them later in the game); guards
	# stand by shops.
	if rng.randf() < GameState.police_chance():
		_spawn_npc(false, "police")
		if GameState.day >= 4 and rng.randf() < 0.4:
			_spawn_npc(false, "police")
	if level.has_meta("shops"):
		for sh in level.get_meta("shops"):
			if rng.randf() < 0.35:
				var g = _spawn_npc(false, "guard")
				g.position = Vector3(sh["x"] - 1.2, 0, -6.9)
			if sh["type"] == "bar":
				# The bouncer stands next to the bar door, facing the street.
				var bo = _spawn_npc(false, "bouncer")
				bo.position = Vector3(sh["x"] + 1.0, 0, -7.3)
				bo.post = bo.position
	_spawn_street_folk()
	for id in GameState.placements:
		var pl: Array = GameState.placements[id]
		if pl[0] == segment and GameState.dog_items.has(id):
			# In a stray dog's mouth.
			var dg = _spawn_animal("dog", pl[1])
			dg.carry(id)
		elif pl[0] == segment:
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
		if ln.has_meta("flying"):
			continue
		# Someone else's shoes: only taken if the player's own are missing.
		if ln.has_meta("spare") and not GameState.is_lost("shoes"):
			continue
		var d := Vector2(ln.position.x - player.position.x, ln.position.z - player.position.z).length()
		if d < 0.7:
			GameState.find_item(ln.id)
			popup("+", ln.position + Vector3(0, 1.2, 0), Color(0.5, 1.0, 0.5))
			hud.show_found(ln.id)
			lost_nodes.erase(ln)
			ln.queue_free()


## Street signs and shop signs.
## - Glasses lost: the text is blurry, sharp only right next to the sign.
## - Drunk enough:
##   - further than 5 m: random letters
##   - within 5 m: the right letters, reshuffled on every step
##   - every sign has its own "sweet spot" near it (different for each
##     sign); the closer to that spot, the more letters sit in the right
##     place, and only right at the spot the real name shows
## - Both: both effects at once.
const SIGN_SHUFFLE_FAR := 5.0
## Sweet spot: how far from it letters start falling into place, and how
## close you must be to read the real name.
const SIGN_SPOT_RANGE := 3.0
const SIGN_SPOT_EXACT := 0.6
const SIGN_SHARP_DIST := 1.5
## Walking this far counts as one step (the letters reshuffle).
const SIGN_STEP_LEN := 0.6
const SIGN_GHOSTS := [Vector3(0.05, 0.03, 0), Vector3(-0.05, -0.02, 0), Vector3(0.02, -0.05, 0),
	Vector3(-0.03, 0.05, 0), Vector3(0.06, -0.01, 0), Vector3(-0.06, 0.01, 0)]

var _sign_step := 0
var _sign_walk := 0.0
var _sign_last := Vector3.ZERO


func _update_signs() -> void:
	# Count steps.
	var moved := Vector2(player.position.x - _sign_last.x, player.position.z - _sign_last.z).length()
	if moved < 2.0:  # ignore jumps when the view changes
		_sign_walk += moved
	_sign_last = player.position
	if _sign_walk >= SIGN_STEP_LEN:
		_sign_walk = 0.0
		_sign_step += 1

	var blind := GameState.is_lost("glasses")
	var drunk := GameState.promille > GameState.PROMILLE_DRUNK
	for l in get_tree().get_nodes_in_group("street_sign"):
		var real: String = l.get_meta("real_text")
		var d := Vector2(l.global_position.x - player.position.x, l.global_position.z - player.position.z).length()
		var want := real
		if drunk:
			if d > SIGN_SHUFFLE_FAR:
				want = _random_letters(real)
			else:
				var spot := _sign_spot(l)
				var ds := Vector2(spot.x - player.position.x, spot.z - player.position.z).length()
				if ds > SIGN_SPOT_EXACT:
					var keep := clampf(1.0 - (ds - SIGN_SPOT_EXACT) / SIGN_SPOT_RANGE, 0.0, 0.85)
					want = _scramble(real, _sign_step, keep)
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


## Each sign's sweet spot: a fixed random point near the sign on the
## walkable street (seeded by the sign, so it stays put).
func _sign_spot(l: Label3D) -> Vector3:
	if l.has_meta("spot"):
		return l.get_meta("spot")
	var r := RandomNumberGenerator.new()
	r.seed = hash([l.get_meta("real_text"), int(l.global_position.x * 10.0), segment])
	var spot := Vector3(l.global_position.x + r.randf_range(-2.5, 2.5), 0.0, r.randf_range(-7.2, -2.0))
	spot = clamp_walkable(spot)
	l.set_meta("spot", spot)
	return spot


## The right letters in a new random order for every step. `keep` (0..1)
## is the share of letters that stay in their right place.
func _scramble(text: String, step: int, keep: float) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(text) + step * 7919
	var chars := text.split("")
	var free: Array = []
	for i in chars.size():
		if r.randf() >= keep:
			free.append(i)
	var letters: Array = []
	for i in free:
		letters.append(chars[i])
	# Shuffle the free letters so none of them (if possible) stays put.
	for i in range(letters.size() - 1, 0, -1):
		var j := r.randi_range(0, i - 1)
		var t = letters[i]
		letters[i] = letters[j]
		letters[j] = t
	for k in free.size():
		chars[free[k]] = letters[k]
	return "".join(chars)


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
			# Close with the phone button again.
			var close := Input.is_action_just_pressed("phone")
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
		"energy":
			player._pickup(spawn_item(Item.Kind.ENERGY, player.position))
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
		# Soiled trousers after a night on the street: not let in at all.
		var ok := not GameState.is_lost("shoes") and p <= 1.8 and not GameState.soiled
		if not ok and not GameState.is_lost("shoes") and not GameState.soiled and p <= 2.3 and GameState.money >= 5:
			GameState.money -= 5
			popup("-5 €", door, Color(1, 0.85, 0.3))
			ok = true
		if not ok:
			popup("X", door + Vector3(1.0, 0, 0), Color(0.9, 0.3, 0.3))
			player.take_hit(3.0, sh["x"] + 2.0, "bouncer")
			return true
	shop_type = sh["type"]
	shop_sel = 0
	shop_flash = ""
	GameState.modal = "shop"
	return true


# --- Bins -------------------------------------------------------------------

## Bins searched today: "block key:index" -> true. Cleared every morning.
var _searched_bins := {}


## Short action next to a bin: rummage through it. Half of the bins hide a
## bottle (beer, spirits or something mysterious). Each bin can be searched
## once a day; the contents are fixed for the day (seeded by day + place).
## Unsearched bin near `pos` for the hint: {"x": bin x, "reach": true
## when the action button would search it now}, or {} if none within
## `near` metres. Searched bins give no hint.
func bin_hint(pos: Vector3, near := 4.0) -> Dictionary:
	if level == null or GameState.over:
		return {}
	var bins: Array = level.get_meta("bins", [])
	var best := {}
	var best_d := INF
	for i in bins.size():
		var bx: float = bins[i]
		if _searched_bins.has("%s:%d" % [_key(segment), i]):
			continue
		var d := Vector2(pos.x - bx, pos.z + 7.5).length()
		if d < near and d < best_d:
			best_d = d
			best = {"x": bx, "reach": absf(pos.x - bx) <= 1.0 and pos.z <= -6.4}
	return best


func try_search_bin(pos: Vector3) -> bool:
	if level == null or GameState.over:
		return false
	var bins: Array = level.get_meta("bins", [])
	for i in bins.size():
		var bx: float = bins[i]
		if absf(pos.x - bx) > 1.0 or pos.z > -6.4:
			continue
		var top := Vector3(bx, 1.4, -7.5)
		player.model.punch()
		GameState.busy_time = maxf(GameState.busy_time, 0.6)
		var key := "%s:%d" % [_key(segment), i]
		if _searched_bins.has(key):
			popup("?", top, Color(0.8, 0.8, 0.8))
			return true
		_searched_bins[key] = true
		var r := RandomNumberGenerator.new()
		r.seed = hash("bin|%d|%s|%s|%d" % [GameState.day, GameState.home_seg, segment, i])
		r.randi()  # warm up: similar seeds give similar first numbers
		if r.randf() < 0.7:
			var roll := r.randf()
			var drink := Item.Drink.BEER if roll < 0.5 else (Item.Drink.SPIRITS if roll < 0.85 else Item.Drink.MYSTERY)
			player._pickup(spawn_item(Item.Kind.BOTTLE, player.position, 1, drink))
			popup("!", top, Color(1, 0.85, 0.3))
		elif r.randf() < 0.15:
			# Rare: pills, taken on the spot (see GameState.FOCUS_TIME).
			GameState.focus_t = GameState.FOCUS_TIME
			popup("!", top, Color(0.75, 0.85, 1.0))
		else:
			popup("-", top, Color(0.8, 0.8, 0.8))
		return true
	return false


## Short action at a door: the home door ends the day, shop doors open the
## counter.
func try_enter_door(pos: Vector3) -> bool:
	if GameState.over:
		return false
	var sh = _shop_at(pos)
	if sh != null:
		return _try_shop(sh)
	if segment == CityMap.police_station() and absf(pos.x - CityMap.police_door_x()) < 0.9 and pos.z < -6.0:
		_police_desk()
		return true
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
	_searched_bins.clear()
	_lock_hits = 0
	_friend_refused = false
	_block_items.clear()
	_block_glass.clear()
	player.reset(Vector3.ZERO)
	_enter_block(GameState.home_seg, _home_door_pos(), 1)
	hud.show_pocket_check()
	hud.show_city(CityMap.city_name())


## From day 2 on the character wakes up somewhere other than home (they
## went out again during the night); further away every day.
func _new_day() -> void:
	_pending_followers.clear()
	_block_items.clear()
	_block_glass.clear()
	_searched_bins.clear()
	_friend_refused = false
	arrest = 0.0
	player.wake_up()
	_enter_block(GameState.wake_seg, GameState.wake_pos, 1 if rng.randf() < 0.5 else -1)
	hud.show_pocket_check()
	if GameState.sleep_place == "jail":
		_cellmate()


## Police station desk: confiscated things are handed back with an ID card.
func _police_desk() -> void:
	var door := Vector3(CityMap.police_door_x(), 2.2, -7.4)
	if GameState.confiscated < 0:
		popup("?", door, Color(0.8, 0.9, 1.0))
		return
	if GameState.is_lost("idcard"):
		hud.think(["idcard"])
		return
	var it = spawn_item(GameState.confiscated, player.position)
	player._pickup(it)
	GameState.confiscated = -1


func _on_day_ended(cause: String) -> void:
	hud.show_card("day", tr("DAY_N") % (GameState.day + 1), tr(cause))
	await get_tree().create_timer(2.2).timeout
	GameState.new_day()
	_new_day()
	hud.hide_card()


## How many headlines and captions there are per cause (keys HL_<CAUSE>_n
## and CAP_<CAUSE>_n in the translations).
const HEADLINES := {"SOBER": [8, 3], "FIGHT": [9, 3], "CAR": [9, 6], "DOG": [6, 3], "BOUNCER": [5, 2],
	"FALL": [6, 2], "COLD": [6, 2], "HUNGER": [4, 2], "HANGOVER": [6, 2], "EXHAUST": [4, 2],
	"BIKE": [3, 2], "GLASS": [3, 2]}


## Captions that fit any death (CAP_ANY_n), used now and then.
const CAPTIONS_ANY := 1


## Death: the character collapses, a moment later a "reader's photo" is
## taken from another angle, and the paper runs the story with a headline
## and caption that fit what happened.
func _on_player_died(cause: String) -> void:
	var fam := "SOBER" if cause == "HEADLINE_SOBER" else GameState.last_hurt.to_upper()
	if not HEADLINES.has(fam):
		fam = "FIGHT"
	var n: Array = HEADLINES[fam]
	var hl_key := "HL_%s_%d" % [fam, rng.randi_range(1, n[0])]
	GameState.saw_headline(hl_key)
	var title := tr(hl_key)
	var caption := tr("CAP_%s_%d" % [fam, rng.randi_range(1, n[1])])
	# Now and then a caption that fits any death.
	if rng.randf() < 0.2:
		caption = tr("CAP_ANY_%d" % rng.randi_range(1, CAPTIONS_ANY))
	player.collapse_dead()
	await get_tree().create_timer(1.4).timeout
	var photo: ImageTexture = await _take_death_photo()
	hud.set_death_photo(photo, caption)
	hud.show_card("dead", title, tr("SCORE") % GameState.score())


## A news photo of the scene from a different angle than the game camera
## (street level, from above, or over the shoulder of whoever did it),
## turned into a grainy sepia newspaper print.
func _take_death_photo() -> ImageTexture:
	var body: Vector3 = player.body_position()
	var sv := SubViewport.new()
	sv.size = Vector2i(480, 330)
	sv.world_3d = get_viewport().world_3d
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var cam := Camera3D.new()
	cam.fov = 55.0
	sv.add_child(cam)
	cam.current = true
	var look := body + Vector3(0, 0.25, 0)
	var culprit = null
	for nb in npcs:
		if nb.is_hostile() and not nb.is_down() and nb.position.distance_to(body) < 6.0:
			culprit = nb
	var pick := rng.randi() % 3
	if pick == 2 and culprit != null:
		# Over the shoulder of the one who did it.
		var away: Vector3 = culprit.position - body
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3(1, 0, 0)
		cam.position = culprit.position + away * 0.7 + Vector3(0, 1.75, 0.35)
	elif pick == 1:
		# From above, as if from a window.
		cam.position = body + Vector3(rng.randf_range(-0.6, 0.6), 4.2, 1.2)
	else:
		# Street level, a bit to the side, slightly tilted.
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		cam.position = body + Vector3(side * 2.2, 0.55, 2.0)
	cam.look_at(look, Vector3.UP)
	if pick == 0:
		cam.rotate_object_local(Vector3.FORWARD, rng.randf_range(-0.15, 0.15))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	sv.queue_free()
	_newsprint(img)
	return ImageTexture.create_from_image(img)


## Newspaper look: sepia-tinted grey, more contrast, grain, dark corners.
func _newsprint(img: Image) -> void:
	img.convert(Image.FORMAT_RGB8)
	var w := img.get_width()
	var h := img.get_height()
	var r := RandomNumberGenerator.new()
	r.seed = rng.randi()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var g := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			g = clampf((g - 0.5) * 1.35 + 0.5, 0.0, 1.0)
			var dx := (float(x) / w - 0.5) * 2.0
			var dy := (float(y) / h - 0.5) * 2.0
			g *= 1.0 - 0.35 * clampf(dx * dx + dy * dy - 0.4, 0.0, 1.0)
			g = clampf(g + r.randf_range(-0.06, 0.06), 0.0, 1.0)
			img.set_pixel(x, y, Color(g * 1.0, g * 0.93, g * 0.8))


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


func spawn_item(kind: int, pos: Vector3, value := 1, drink := 0):
	var it = Item.new()
	it.main = self
	it.setup(kind, value, drink)
	add_child(it)
	# On the ground: on top of the sidewalk where there is one.
	it.global_position = Vector3(pos.x, Item.ground_y(pos) if pos.y <= 0.01 else pos.y, pos.z)
	items.append(it)
	return it


## A bottle smashed here: shards on the ground (stay for the day).
func spawn_glass(pos: Vector3, col: Color) -> void:
	var g = Glass.new()
	g.main = self
	g.set_meta("color", col)
	g.setup(rng, col)
	add_child(g)
	g.position = Vector3(pos.x, Item.ground_y(pos), clampf(pos.z, -7.5, 5.6))
	glass.append(g)


## Shards under `pos`, or null. `extra` widens the check (a car's tyres).
func glass_at(pos: Vector3, extra := 0.0):
	for g in glass:
		if g.covers(pos, extra):
			return g
	return null


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
	var role: String = n.role
	n.queue_free()
	# Guards, beggars and drunks stay put; whoever walks off is replaced
	# by an ordinary passer-by (punks only come as a gang).
	_spawn_npc(true, role if role == "police" else "civ")


## Screen shake strength in metres; dies away quickly.
var _shake := 0.0


## A short jolt of the camera (a punch landing, a hit taken).
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _update_shake(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = move_toward(_shake, 0.0, delta * 0.9)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.6


func popup(text: String, pos: Vector3, color: Color, size := 1.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.006 * size
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


## Floating picture instead of text (e.g. the growling stomach).
func popup_icon(tex: Texture2D, pos: Vector3) -> void:
	var sp := Sprite3D.new()
	sp.texture = tex
	sp.pixel_size = 0.016
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.no_depth_test = true
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	add_child(sp)
	sp.global_position = pos
	var tw := create_tween()
	tw.tween_property(sp, "position:y", sp.position.y + 1.0, 1.1)
	tw.parallel().tween_property(sp, "modulate:a", 0.0, 1.1)
	tw.tween_callback(sp.queue_free)


var _stomach_tex: ImageTexture
var _note_tex: ImageTexture
var _heart_tex: ImageTexture


## Singing drunk: passers-by close by may get angry, police may notice.
func player_sings() -> void:
	for n in npcs:
		if n.is_down():
			continue
		var d := Vector2(n.position.x - player.position.x, n.position.z - player.position.z).length()
		if not n.is_lawman() and not n.is_trader() and d < 4.0 and n.state == n.S.WALK and rng.randf() < 0.3:
			n.provoke()
		elif n.role == "police" and d < 10.0 and rng.randf() < 0.5:
			n.notice()


func note_texture() -> ImageTexture:
	if _note_tex != null:
		return _note_tex
	var n := 48
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var col := Color(0.15, 0.15, 0.2)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var head := pow((p.x - 16.0) / 9.0, 2) + pow((p.y - 36.0) / 6.5, 2) < 1.0
			var stem := p.x > 22.0 and p.x < 26.0 and p.y > 6.0 and p.y < 36.0
			var flag := p.x >= 24.0 and p.x < 24.0 + (p.y - 6.0) * 0.9 and p.y > 6.0 and p.y < 18.0
			if head or stem or flag:
				img.set_pixel(x, y, col)
			elif (pow((p.x - 16.0) / 11.0, 2) + pow((p.y - 36.0) / 8.5, 2) < 1.0) or (p.x > 20.0 and p.x < 28.0 and p.y > 4.0 and p.y < 37.0):
				img.set_pixel(x, y, Color(1, 1, 1, 0.9))
	_note_tex = ImageTexture.create_from_image(img)
	return _note_tex


var _strain_heart_tex: ImageTexture
var _breath_tex: ImageTexture


## A small white puff of breath.
func breath_texture() -> ImageTexture:
	if _breath_tex != null:
		return _breath_tex
	var n := 32
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := minf(p.distance_to(Vector2(12, 18)) / 8.0, minf(p.distance_to(Vector2(20, 14)) / 9.0, p.distance_to(Vector2(22, 21)) / 6.0))
			if d < 1.0:
				img.set_pixel(x, y, Color(1, 1, 1, 0.85 * (1.0 - d * 0.5)))
	_breath_tex = ImageTexture.create_from_image(img)
	return _breath_tex


## Light pink heart with a dark outline: "this used up temporary health"
## (same colour as the temporary part in the HUD heart).
func strain_heart_texture() -> ImageTexture:
	if _strain_heart_tex != null:
		return _strain_heart_tex
	var n := 48
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		var hp := Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)))
		outer.append(Vector2(24, 24) + hp * 1.35)
		inner.append(Vector2(24, 24) + hp * 1.15)
	for y in n:
		for x in n:
			var pt := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(pt, inner):
				img.set_pixel(x, y, Color(1.0, 0.65, 0.72))
			elif Geometry2D.is_point_in_polygon(pt, outer):
				img.set_pixel(x, y, Color(0.45, 0.1, 0.18))
	_strain_heart_tex = ImageTexture.create_from_image(img)
	return _strain_heart_tex


func heart_texture() -> ImageTexture:
	if _heart_tex != null:
		return _heart_tex
	var n := 48
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		pts.append(Vector2(24, 24) + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * 1.3)
	for y in n:
		for x in n:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				img.set_pixel(x, y, Color(1.0, 0.3, 0.45))
	_heart_tex = ImageTexture.create_from_image(img)
	return _heart_tex


## A pink stomach with growl lines, drawn once into a texture.
func stomach_texture() -> ImageTexture:
	if _stomach_tex != null:
		return _stomach_tex
	var n := 64
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var pink := Color(0.95, 0.5, 0.55)
	var dark := Color(0.35, 0.1, 0.12)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			# Bean-shaped stomach: a big ellipse with a bite taken out on the
			# upper left, plus the gullet going up.
			var body := pow((p.x - 34.0) / 20.0, 2) + pow((p.y - 36.0) / 16.0, 2)
			var bite := pow((p.x - 20.0) / 10.0, 2) + pow((p.y - 26.0) / 9.0, 2)
			var gullet := absf(p.x - 22.0) < 4.0 and p.y > 6.0 and p.y < 26.0
			var inside := (body < 1.0 and bite > 1.0) or gullet
			var edge := (body < 1.18 and bite > 0.8) or (absf(p.x - 22.0) < 6.0 and p.y > 4.0 and p.y < 27.0)
			if inside:
				img.set_pixel(x, y, pink)
			elif edge:
				img.set_pixel(x, y, dark)
	# Growl lines: little zigzags inside.
	for k in 3:
		var y0 := 30 + k * 7
		for x in range(28, 46):
			var yy := y0 + (1 if (x / 3) % 2 == 0 else -1)
			img.set_pixel(x, yy, dark)
	_stomach_tex = ImageTexture.create_from_image(img)
	return _stomach_tex


## Extra street characters: a beggar by a wall, a drunk, a punk gang,
## seagulls and a loose dog, each only in some blocks.
func _spawn_street_folk() -> void:
	# Without a phone there are more beggars around to ask.
	if rng.randf() < (0.6 if GameState.is_lost("phone") else 0.3):
		var bx: float = BlockBuilder.clear_of_doors(level, rng, -13.0, 13.0)
		if not is_nan(bx):
			var b = _spawn_npc(false, "beggar")
			b.position = Vector3(bx, 0, -7.25)
	if rng.randf() < 0.25:
		var d = _spawn_npc(false, "drunk")
		d.position.z = rng.randf_range(-7.0, -5.8) if rng.randf() < 0.5 else rng.randf_range(3.3, 4.8)
	if GameState.day >= 2 and rng.randf() < 0.2:
		_spawn_punks()
	# From day 4 a can collector beats you to the bins.
	if GameState.day >= 4 and rng.randf() < 0.4:
		_spawn_npc(false, "collector")
	# New things keep turning up as the days go by: gulls from day 2,
	# dogs (helpers or enemies) from day 3.
	var gulls := rng.randi_range(1, 3) if GameState.day >= 2 and rng.randf() < 0.55 else 0
	for i in gulls:
		var z := rng.randf_range(-7.4, -5.6) if rng.randf() < 0.5 else rng.randf_range(3.0, 5.2)
		_spawn_animal("gull", Vector3(rng.randf_range(-14.0, 14.0), 0, z))
	if GameState.day >= 3 and rng.randf() < 0.3:
		var z := rng.randf_range(-7.0, -5.6) if rng.randf() < 0.5 else rng.randf_range(3.2, 5.0)
		_spawn_animal("dog", Vector3(rng.randf_range(-14.0, 14.0), 0, z))


func _spawn_punks() -> void:
	var n := rng.randi_range(2, 3)
	var d := 1 if rng.randf() < 0.5 else -1
	var x := rng.randf_range(-12.0, 12.0)
	if absf(x - player.position.x) < 5.0:
		x = clampf(x + 10.0 * signf(x - player.position.x + 0.01), -14.0, 14.0)
	var z := rng.randf_range(-7.0, -5.8) if rng.randf() < 0.5 else rng.randf_range(3.2, 4.8)
	var gang: Array = []
	_next_gang += 1
	var spd := rng.randf_range(1.1, 1.4)
	for i in n:
		var p = _spawn_npc(false, "punk")
		p.position = Vector3(x - d * 0.9 * i, 0, z + (0.35 if i % 2 == 1 else 0.0))
		p.dir = d
		p.speed = spd
		p.gang_id = _next_gang
		gang.append(p)
	for p in gang:
		p.gang = gang


## A punk passing close by: the first time a gang meets the player it may
## offer a can of beer (into an empty hand, else at the feet).
func punk_meet(p) -> void:
	if p.gang_id < 0 or _punk_met.has(p.gang_id):
		return
	var d := Vector2(p.position.x - player.position.x, p.position.z - player.position.z).length()
	if d > 1.8:
		return
	_punk_met[p.gang_id] = true
	if rng.randf() < 0.45:
		var it = spawn_item(Item.Kind.BOTTLE, player.position, 1, Item.Drink.BEER)
		if player.hand_item == null:
			player._pickup(it)
		popup("!", p.position + Vector3(0, 2.3, 0), Color(0.6, 1.0, 0.6))
		popup_icon(heart_texture(), p.position + Vector3(0, 2.6, 0.3))


## Beggar paid: a tip about where one of the lost things is (like the
## cellmate), or a shrug when nothing is lost.
func beggar_tip(pos: Vector3) -> void:
	GameState.unlock("BEGGAR_PAY")
	var candidates: Array = []
	for id in GameState.placements:
		candidates.append(id)
	if candidates.is_empty():
		popup("?", pos + Vector3(0, 1.6, 0), Color(0.9, 0.9, 0.9))
		return
	var pick: String = candidates[rng.randi() % candidates.size()]
	var seg: Vector3i = GameState.placements[pick][0]
	hud.think([pick])
	popup(CityMap.street_name(seg), player.position + Vector3(0, 3.2, 0), Color(0.8, 0.9, 1.0))


func _spawn_animal(kind: String, pos: Vector3):
	var a = Animal.new()
	a.main = self
	a.setup(kind, rng, pos)
	add_child(a)
	animals.append(a)
	return a


## A gull was trodden on: the other gulls come over and bomb the player
## for a while. If there are hardly any, a couple fly in from the side.
func gull_trampled(victim) -> void:
	GameState.unlock("GULL_STEP")
	var others: Array = []
	for a in animals:
		if a != victim and a.kind == "gull":
			others.append(a)
	while others.size() < 2:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var g = _spawn_animal("gull", Vector3(side * 24.0, 0, rng.randf_range(-6.0, 4.0)))
		g.position.y = 4.0
		others.append(g)
	for i in others.size():
		others[i].start_bombing(1.0 + i * 0.8)


## Hit by a car: the shoes fly off in a high arc and land a few metres
## away; they are lost until picked up again.
func shoes_fly_off(from: Vector3, dir: int) -> void:
	if GameState.is_lost("shoes"):
		return
	var land: Vector3 = clamp_walkable(from + Vector3(dir * rng.randf_range(3.0, 7.0), 0, rng.randf_range(-2.0, 2.0)))
	land.y = 0.0
	GameState.lose_here("shoes", segment, land)
	hud.add_today("shoes")
	_fling_shoes(from, land, false)


## Someone else hit by a car loses their shoes the same way. A player
## without shoes can take them (they fit).
func npc_shoes_fly_off(from: Vector3, dir: int) -> void:
	var land: Vector3 = clamp_walkable(from + Vector3(dir * rng.randf_range(3.0, 7.0), 0, rng.randf_range(-2.0, 2.0)))
	land.y = 0.0
	_fling_shoes(from, land, true)


func _fling_shoes(from: Vector3, land: Vector3, spare: bool) -> void:
	var ln = LostItemNode.new()
	ln.main = self
	ln.setup("shoes")
	add_child(ln)
	lost_nodes.append(ln)
	ln.set_meta("flying", true)
	if spare:
		ln.set_meta("spare", true)
	var start := from + Vector3(0, 0.3, 0)
	ln.position = start
	var height := rng.randf_range(3.5, 5.5)
	var spin := Vector3(rng.randf_range(8, 14), rng.randf_range(-6, 6), rng.randf_range(8, 14))
	var fly := func(t: float) -> void:
		if not is_instance_valid(ln):
			return
		ln.position = start.lerp(land, t) + Vector3(0, sin(PI * t) * height, 0)
		ln.rotation = spin * t * (1.0 - t * 0.3)
	var landed := func() -> void:
		if is_instance_valid(ln):
			ln.rotation = Vector3(0, ln.rotation.y, 0)
			ln.remove_meta("flying")
	var tw := create_tween()
	tw.tween_method(fly, 0.0, 1.0, 1.4)
	tw.tween_callback(landed)


## Can collector's next target: the nearest unsearched bin or bottle/can
## lying in the street within 14 m ({} if none).
func collector_target(pos: Vector3) -> Dictionary:
	var best := {}
	var best_d := 14.0
	if level != null:
		var bins: Array = level.get_meta("bins", [])
		for i in bins.size():
			if _searched_bins.has("%s:%d" % [_key(segment), i]):
				continue
			var bp := Vector3(bins[i], 0, -7.0)
			var d := Vector2(bp.x - pos.x, bp.z - pos.z).length()
			if d < best_d:
				best_d = d
				best = {"type": "bin", "i": i, "pos": bp}
	for it in items:
		if not is_instance_valid(it) or it == player.hand_item or not it.can_pickup():
			continue
		if it.kind != Item.Kind.CAN and it.kind != Item.Kind.BOTTLE:
			continue
		var ip: Vector3 = it.global_position
		var d := Vector2(ip.x - pos.x, ip.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = {"type": "item", "item": it, "pos": Vector3(ip.x, 0, ip.z)}
	return best


## The collector got to a bin first: it's empty for the player now.
func collector_take_bin(i: int) -> void:
	var key := "%s:%d" % [_key(segment), i]
	if _searched_bins.has(key):
		return
	_searched_bins[key] = true
	var bins: Array = level.get_meta("bins", [])
	if i < bins.size():
		popup("kolin", Vector3(bins[i], 1.4, -7.5), Color(0.85, 0.85, 0.9))


func remove_rider(rd) -> void:
	riders.erase(rd)
	rd.queue_free()


func remove_animal(a) -> void:
	animals.erase(a)
	a.queue_free()


## After a punk's pills: things that aren't there pop up around the
## player now and then (pink elephants, giant mushrooms, eyes, spirals).
var _vision_cd := 1.0


func _update_trip(delta: float) -> void:
	var k := GameState.trip_amount()
	if k <= 0.0 or level == null or GameState.over or GameState.modal != "":
		return
	_vision_cd -= delta * k
	if _vision_cd > 0.0:
		return
	_vision_cd = rng.randf_range(1.2, 3.0)
	var v = Vision.new()
	var vk: String = ["elephant", "mushroom", "eye", "spiral"][rng.randi() % 4]
	v.setup(vk, rng)
	GameState.saw_vision(vk)
	# Added to the block so it goes when the street changes.
	level.add_child(v)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	v.position = Vector3(player.position.x + side * rng.randf_range(2.0, 7.0),
		rng.randf_range(0.0, 1.2), clampf(player.position.z + rng.randf_range(-3.0, 1.0), -7.5, 5.0))


## A beggar or street drunk within `r` metres, ready to trade.
func trader_near(pos: Vector3, r: float):
	for n in npcs:
		if n.is_trader() and Vector2(n.position.x - pos.x, n.position.z - pos.z).length() < r:
			return n
	return null


## An animal right in front of the player (for a punch / swat).
func animal_in_front(pos: Vector3, facing: int, reach: float):
	for a in animals:
		var dx: float = (a.position.x - pos.x) * facing
		if dx >= -0.2 and dx <= reach and absf(a.position.z - pos.z) < 0.6 and a.position.y < 2.0:
			return a
	return null


## An animal near `pos` (a thrown thing hitting it).
func animal_at(pos: Vector3, r: float):
	for a in animals:
		if Vector2(a.position.x - pos.x, a.position.z - pos.z).length() < r and absf(a.position.y - pos.y) < 1.2:
			return a
	return null


## Food lying on the street within `r` metres (for dogs).
func food_on_ground_near(pos: Vector3, r: float):
	for it in items:
		if is_instance_valid(it) and it.can_be_eaten():
			if Vector2(it.global_position.x - pos.x, it.global_position.z - pos.z).length() < r:
				return it
	return null


## A dog let go of a lost thing: it lies on the ground there now.
func dog_dropped(id: String, pos: Vector3) -> void:
	GameState.dog_items.erase(id)
	if not GameState.placements.has(id):
		return
	var at := clamp_walkable(pos)
	at.y = 0.0
	GameState.placements[id][1] = at
	var ln = LostItemNode.new()
	ln.main = self
	ln.setup(id)
	add_child(ln)
	ln.position = at
	lost_nodes.append(ln)
	popup("!", at + Vector3(0, 1.4, 0), Color(1, 0.85, 0.3))


## The lost thing in this block nearest to `pos` (a dog can sniff it out).
func nearest_lost_node(pos: Vector3):
	var best = null
	var best_d := INF
	for ln in lost_nodes:
		var d := Vector2(ln.position.x - pos.x, ln.position.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = ln
	return best


func _spawn_npc(at_edge: bool, role := "civ"):
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
	n.setup(rng, x, z, d, role)
	add_child(n)
	npcs.append(n)
	return n


# --- Traffic ----------------------------------------------------------------------

## Cars come now and then from either end of the block. No cars on the
## pedestrian street (Rotuaari).
func _update_traffic() -> void:
	var dt := GameState.world_dt
	if dt <= 0.0 or GameState.over:
		return
	# From day 4: cyclists and e-scooters tear along the sidewalks (also on
	# the pedestrian street).
	if GameState.day >= 4:
		_rider_timer -= dt
		if _rider_timer <= 0.0:
			_rider_timer = rng.randf_range(7.0, 16.0)
			var rd = Rider.new()
			rd.main = self
			var rdir := 1 if rng.randf() < 0.5 else -1
			if not end_open(-rdir):
				rdir = -rdir
			rd.setup(rng, rdir)
			add_child(rd)
			riders.append(rd)
	if _is_pedestrian_street():
		return
	_car_timer -= dt
	if _car_timer <= 0.0:
		_car_timer = rng.randf_range(6.0, 16.0)
		var d := 1 if rng.randf() < 0.5 else -1
		# Cars only come in from an open end, and turn off before a shut
		# one (the end of the map or roadworks).
		if not end_open(-d):
			d = -d
		var turn := shut_end_turn(d)
		if not end_open(-d) or turn == 2:
			return
		var c = Car.new()
		c.main = self
		c.setup(rng, d, -Car.EDGE_X * d + d * 0.5)
		if turn != 0:
			c.turn_at = d * CROSS_CENTER
			c.turn_z = turn
		add_child(c)
		cars.append(c)


## Can you go on past the left (-1) / right (1) end of this block?
func end_open(side: int) -> bool:
	return CityMap.is_open(CityMap.next_along(segment, side))


## Something heading towards `side`: 0 = the way on is open; -1 / 1 =
## shut, turn up / down the side street there; 2 = no way out at all.
func shut_end_turn(side: int) -> int:
	if end_open(side):
		return 0
	if CityMap.can_turn(segment, side > 0, true):
		return -1
	if CityMap.can_turn(segment, side > 0, false):
		return 1
	return 2


func _is_pedestrian_street() -> bool:
	return CityMap.is_pedestrian(segment)


## A driver gets out of `car` angry and starts a fight.
func spawn_driver(car, pos: Vector3):
	var n = _spawn_npc(false)
	n.position = pos
	n.car_ref = car
	n.state = n.S.FIGHT
	n._mark.visible = true
	popup("!", pos + Vector3(0, 2.3, 0), Color(1, 0.3, 0.2))
	return n


## Keeps a person out of the cars' footprints (cars are solid).
func push_out_of_cars(pos: Vector3) -> Vector3:
	for c in cars:
		var hx: float = Car.HALF_LEN + 0.25
		var hz: float = Car.HALF_WIDTH + 0.25
		var dx: float = pos.x - c.position.x
		var dz: float = pos.z - c.position.z
		if absf(dx) >= hx or absf(dz) >= hz:
			continue
		if hz - absf(dz) < hx - absf(dx):
			pos.z = c.position.z + (1.0 if dz >= 0.0 else -1.0) * hz
		else:
			pos.x = c.position.x + (1.0 if dx >= 0.0 else -1.0) * hx
	return pos


func remove_car(c) -> void:
	cars.erase(c)
	c.queue_free()


func obstacles() -> Array:
	return level.get_meta("obstacles", []) if level != null else []


## The zebra crossings are at both ends of the block, across this street.
func crosswalk_xs() -> Array:
	return [-(BLOCK_HALF + 1.6), BLOCK_HALF + 1.6]


func someone_on_crosswalk(cw_x: float) -> bool:
	var people: Array = [player]
	for n in npcs:
		if not n.is_down():
			people.append(n)
	for pp in people:
		if absf(pp.position.x - cw_x) < 1.4 and pp.position.z > -5.0 and pp.position.z < 2.5:
			return true
	return false


# --- Police -----------------------------------------------------------------------

## How long police must hold on to the player (seconds of world time).
const ARREST_TIME := 1.6
## Barefoot the player sneaks: police and guards notice only close by.
const SNEAK_NOTICE_DIST := 7.0
## 0..1: how close the police are to arresting the player.
var arrest := 0.0


## A crime happened (the player hit someone or an animal, or a
## pickpocketing victim shouted). Police see it only if the player is in
## their vision cone (a shout they hear); guards in the block react to
## crimes against people. A shout can also bring a police officer running
## from the street end.
func report_crime(pos: Vector3, alarm: bool, animal := false) -> void:
	var noticed := false
	var reach := SNEAK_NOTICE_DIST if GameState.is_lost("shoes") else INF
	# Drunk and loud: noticed from further away even when sneaking.
	if GameState.promille > GameState.PROMILLE_DRUNK:
		reach *= 2.0
	var sight := police_sight()
	for n in npcs:
		if not n.is_lawman() or n.is_down():
			continue
		var d := Vector2(n.position.x - player.position.x, n.position.z - player.position.z).length()
		var saw: bool
		if n.role == "police":
			saw = n.sees(player.position, sight) or (alarm and d < reach)
		else:
			saw = not animal and d < reach
		if saw:
			n.notice()
			noticed = true
	if alarm and not noticed and rng.randf() < 0.6:
		var cop = _spawn_npc(true, "police")
		cop.position.x = Npc.EDGE_X * (-1.0 if pos.x < 0.0 else 1.0)
		cop.position.z = clampf(pos.z, Z_MIN, Z_MAX)
		cop.notice()


## How far the police see (the length of the vision cone): short when the
## player sneaks barefoot, longer when drunk and loud.
func police_sight() -> float:
	var r: float = Npc.VISION_RANGE
	if GameState.is_lost("shoes"):
		r = SNEAK_NOTICE_DIST
	if GameState.promille > GameState.PROMILLE_DRUNK:
		r *= 2.0 if GameState.is_lost("shoes") else 1.25
	return r


## Police next to the player fill the arrest meter; once full, it's the
## cell for the night. Getting away lets it drain.
func _check_arrest() -> void:
	var dt := GameState.world_dt
	if GameState.over or dt <= 0.0:
		return
	var holding := false
	for n in npcs:
		if n.role == "police" and n.state == Npc.S.CHASE:
			if Vector2(n.position.x - player.position.x, n.position.z - player.position.z).length() < 0.9:
				holding = true
	if holding:
		arrest = minf(1.0, arrest + dt / ARREST_TIME)
	else:
		arrest = maxf(0.0, arrest - dt * 0.5)
	if arrest >= 1.0:
		arrest = 0.0
		_get_arrested()


func _get_arrested() -> void:
	# The police take what is in the hand.
	var hand = player.hand_item
	if hand != null:
		GameState.confiscated = hand.kind
		items.erase(hand)
		hand.queue_free()
		player.hand_item = null
	GameState.go_jail()


## Morning in the cell: the cellmate either gives a tip about a lost thing
## or steals some money.
func _cellmate() -> void:
	var candidates: Array = []
	for id in GameState.placements:
		candidates.append(id)
	if not candidates.is_empty() and rng.randf() < 0.5:
		var id: String = candidates[rng.randi() % candidates.size()]
		var seg: Vector3i = GameState.placements[id][0]
		hud.think([id])
		popup(CityMap.street_name(seg), player.position + Vector3(0, 3.2, 0), Color(0.8, 0.9, 1.0))
	elif GameState.money > 0:
		var taken := maxi(1, GameState.money / 2)
		GameState.money -= taken
		popup("-%d €" % taken, player.position + Vector3(0, 2.4, 0), Color(1, 0.5, 0.4))


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
	var rel := deg_to_rad(sun_az - CityMap.view_azimuth(segment.x))
	# Screen: forward (camera look) = -Z, right = +X.
	var to_sun := Vector3(cos(elev) * sin(rel), sin(elev), -cos(elev) * cos(rel))
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	var weather := GameState.weather
	var cloudy := weather != "sunny"
	# Overcast (cloudy, rain, snow): soft light, no sharp shadows.
	sun.shadow_enabled = not cloudy
	var sun_e: float = {"sunny": 1.0, "cloudy": 0.25, "rain": 0.15, "snow": 0.3}[weather]
	sun.light_energy = sun_e * smoothstep(0.0, 0.25, day_light)
	sun.light_color = Color(1.0, 0.85, 0.7).lerp(Color(1, 0.98, 0.94), smoothstep(0.0, 0.5, day_light))
	env.ambient_light_energy = (0.35 + 0.55 * smoothstep(0.0, 0.4, day_light)) * (1.45 if cloudy else 1.0)
	sky_mat.sky_top_color = {"sunny": Color(0.2, 0.42, 0.8), "cloudy": Color(0.55, 0.58, 0.62),
		"rain": Color(0.38, 0.4, 0.44), "snow": Color(0.7, 0.72, 0.76)}[weather]
	sky_mat.sky_horizon_color = {"sunny": Color(0.6, 0.72, 0.85), "cloudy": Color(0.72, 0.74, 0.76),
		"rain": Color(0.55, 0.57, 0.6), "snow": Color(0.86, 0.87, 0.9)}[weather]
	_update_precipitation(weather)
	# Without sunglasses, facing the sun on a sunny day dazzles; a low sun
	# is the worst.
	var want_glare := 0.0
	if weather == "sunny" and GameState.is_lost("sunglasses") and day_light > 0.1:
		var low := 1.0 - clampf(rad_to_deg(elev) / 45.0, 0.0, 1.0) * 0.5
		want_glare = clampf(player.facing * to_sun.x * 1.2 + maxf(0.0, -to_sun.z) * 0.5, 0.0, 1.0) * low * 0.8
	_glare = lerpf(_glare, want_glare, 0.05)
	# The hand shading the eyes takes the worst of it off.
	tilt_mat.set_shader_parameter("glare", _glare * (1.0 - 0.3 * shade_amount()))
	# Cloud shadows only on sunny days; they drift while time moves.
	clouds.visible = not cloudy and day_light > 0.15
	if clouds.visible:
		var a := deg_to_rad(CityMap.view_azimuth(segment.x))
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


## Invisible ground and facade for the rag dolls to land on and bounce off.
func _build_physics_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	# Street, facade, and the two raised sidewalks (a kerb higher) so thrown
	# things and rag dolls rest on top of them.
	for spec in [[Vector3(0, -0.45, -10), Vector3(400, 1.0, 120)], [Vector3(0, 10, -8.6), Vector3(400, 20, 1.0)],
			[Vector3(0, -0.38, -6.8), Vector3(400, 1.0, 3.6)], [Vector3(0, -0.38, 4.15), Vector3(400, 1.0, 3.3)]]:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = spec[1]
		cs.shape = sh
		cs.position = spec[0]
		body.add_child(cs)


# --- Rain and snow -------------------------------------------------------------

var rain: CPUParticles3D
var snow: CPUParticles3D
var snow_cover: Node3D


func _build_precipitation() -> void:
	rain = _particles(Color(0.75, 0.8, 0.9, 0.7), Vector3(0.015, 0.45, 0.015), 900, Vector3(0, -18, 0), 1.2)
	snow = _particles(Color(1, 1, 1, 0.95), Vector3(0.12, 0.12, 0.12), 1400, Vector3(0, -1.6, 0), 9.0)
	snow.initial_velocity_min = 0.3
	snow.initial_velocity_max = 0.9
	snow.direction = Vector3(1, 0, 0.3)
	snow.spread = 180.0
	# A thin white layer over the street and sidewalks on snowy days.
	snow_cover = Node3D.new()
	add_child(snow_cover)
	for spec in [[Vector3(0, 0.135, -6.5), Vector3(120, 0.005, 3.0), 0.75], [Vector3(0, 0.135, 4.15), Vector3(120, 0.005, 3.3), 0.75],
			[Vector3(0, 0.012, -1.25), Vector3(120, 0.005, 7.5), 0.45]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec[1]
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.95, 0.96, 1.0, spec[2])
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		mi.position = spec[0]
		snow_cover.add_child(mi)


func _particles(col: Color, size: Vector3, amount: int, gravity: Vector3, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = m
	p.mesh = mesh
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(24, 0.5, 14)
	p.gravity = gravity
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.position = Vector3(0, 12, -2)
	p.emitting = false
	p.visible = false
	add_child(p)
	return p


## Rain and snow fall only while time moves (frozen mid-air otherwise), and
## follow the camera along the street.
func _update_precipitation(weather: String) -> void:
	var raining := weather == "rain"
	var snowing := weather == "snow"
	for pair in [[rain, raining], [snow, snowing]]:
		var p: CPUParticles3D = pair[0]
		p.visible = pair[1]
		p.emitting = pair[1]
		p.speed_scale = 1.0 if GameState.world_dt > 0.0 else 0.0
		p.position.x = camera.position.x
	# Storm: the rain lashes sideways with the wind.
	var wx := wind_at(Vector3(camera.position.x, 2.0, -1.0)).x
	rain.gravity = Vector3(wx * 3.0, -18.0, 0.0)
	rain.particle_flag_align_y = GameState.storm
	snow_cover.visible = snowing
	snow_cover.position.x = camera.position.x
	env.fog_enabled = raining or snowing
	env.fog_light_color = Color(0.6, 0.62, 0.66) if raining else Color(0.9, 0.92, 0.95)
	env.fog_density = 0.012 if raining else 0.006


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


## The view is designed for 16:9: 36 degrees high. On narrower screens
## (4:3, phones) the width of the street seen is kept instead, so nothing
## is cut off at the sides (more shows above and below); on wider screens
## (21:9) more shows at the sides.
const CAMERA_FOV := 36.0
const DESIGN_ASPECT := 16.0 / 9.0
## Wider screens zoom in (so the character doesn't shrink), but never so
## far that the sidewalks drop out of view; past MAX_ASPECT black bars
## close in the sides.
const MIN_FOV := 26.0
const MAX_ASPECT := 2.6
## Left and right edge of the playing area on screen (inside the bars).
var play_left := 0.0
var play_right := 1280.0


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.position = Vector3(0, 10.5, 17.0)
	add_child(camera)
	camera.look_at(Vector3(0, 0.6, -1.5))
	camera.current = true
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


func _fit_camera() -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.y <= 0.0:
		return
	var aspect := vs.x / vs.y
	play_left = 0.0
	play_right = vs.x
	if aspect >= DESIGN_ASPECT:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = clampf(CAMERA_FOV * pow(DESIGN_ASPECT / aspect, 0.6), MIN_FOV, CAMERA_FOV)
		if aspect > MAX_ASPECT:
			var bar := (vs.x - vs.y * MAX_ASPECT) * 0.5
			play_left = bar
			play_right = vs.x - bar
	else:
		# Same horizontal view as 16:9 at 36 degrees high.
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(CAMERA_FOV * 0.5)) * DESIGN_ASPECT))


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


## Drunk: everything gets blurrier (a little inside a circle around the
## player, more outside it), and the circle shrinks quickly from the whole
## screen (2.0 per mille) to a radius of 1.5 m (3.0 per mille and up);
## above 3.0 the blur outside gets much stronger.
const DRUNK_CIRCLE_MAX := 14.0
const DRUNK_CIRCLE_MIN := 1.5
const BLUR_START := 1.0


## 0 at `start` per mille, 1 at today's passing-out limit: the effects keep
## getting worse right up to passing out.
func _towards_passout(start: float) -> float:
	return clampf((GameState.promille - start) / maxf(GameState.pass_out_promille - start, 0.1), 0.0, 1.0)


const DRUNK_CIRCLE_END := 0.8
var _blink_t := 0.0
var _blink_cd := 8.0
var _blink_len := 0.9


func _update_drunk_circle() -> void:
	# Blur starts mildly at 1.0 per mille and grows until passing out.
	tilt_mat.set_shader_parameter("drunk", _towards_passout(BLUR_START))
	tilt_mat.set_shader_parameter("heavy", _towards_passout(2.3))
	# The edges of the view darken from 0.8 per mille on.
	tilt_mat.set_shader_parameter("vignette", _towards_passout(0.8))
	_update_eyelids(get_process_delta_time())
	var vs := get_viewport().get_visible_rect().size
	var c: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	if camera.is_position_behind(c):
		return
	var shrink := pow(clampf((GameState.promille - BLUR_START) / 1.3, 0.0, 1.0), 0.6)
	var r_m := lerpf(DRUNK_CIRCLE_MAX, DRUNK_CIRCLE_MIN, shrink)
	# ...and keeps shrinking from 2.3 per mille until passing out.
	r_m = lerpf(r_m, DRUNK_CIRCLE_END, _towards_passout(2.3))
	var cp := camera.unproject_position(c)
	var ep := camera.unproject_position(c + Vector3(r_m, 0, 0))
	tilt_mat.set_shader_parameter("circle_center", cp / vs)
	tilt_mat.set_shader_parameter("circle_radius", (ep - cp).length() / vs.y)
	tilt_mat.set_shader_parameter("aspect", vs.x / vs.y)


## Drunk eyelids: from 2.0 per mille slow heavy blinks (more often the
## drunker), and near passing out the lids hang half shut.
func _update_eyelids(dt: float) -> void:
	var k := _towards_passout(2.0)
	var droop := 0.6 * smoothstep(0.6, 1.0, k)
	var blink := 0.0
	if k > 0.0:
		if _blink_t > 0.0:
			# Close (0.3 s), stay nearly shut (longer the drunker: dozing
			# off), open (0.3 s).
			_blink_t -= dt
			var gone := _blink_len - _blink_t
			var shut := lerpf(0.6, 0.95, k)
			if gone < 0.3:
				blink = shut * gone / 0.3
			elif _blink_t < 0.3:
				blink = shut * maxf(_blink_t, 0.0) / 0.3
			else:
				blink = shut
		else:
			_blink_cd -= dt
			if _blink_cd <= 0.0:
				_blink_len = lerpf(0.9, 3.0, k)
				_blink_t = _blink_len
				# Half as often as before.
				_blink_cd = lerpf(14.0, 3.6, k) * randf_range(0.7, 1.3)
	if GameState.over:
		blink = 0.0
		droop = 0.0
	# Dozing off on the street: the lids close over everything.
	var doze := GameState.doze_lids()
	tilt_mat.set_shader_parameter("lids", clampf(maxf(maxf(droop, blink), doze), 0.0, 1.0))


## The sharp tilt-shift band follows the player vertically on screen.
func _update_focus(delta: float) -> void:
	var p: Vector3 = player.global_position + Vector3(0, 0.9, 0)
	if camera.is_position_behind(p):
		return
	var h := get_viewport().get_visible_rect().size.y
	var target := clampf(camera.unproject_position(p).y / h, 0.15, 0.9)
	_focus_y = lerpf(_focus_y, target, 1.0 - exp(-6.0 * delta))
	tilt_mat.set_shader_parameter("focus_center", _focus_y)
