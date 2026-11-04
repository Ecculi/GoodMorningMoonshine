extends Node3D
## The playable character. Arrow keys / d-pad move, one action button:
## short press = punch / drink / eat, long press = throw the held item.

const PersonModel = preload("res://scripts/person_model.gd")
const Item = preload("res://scripts/item.gd")

const WALK_SPEED := 2.6
const RUN_SPEED := 6.4  # one block (~32 m) in about 5 s
const LONG_PRESS := 0.35
const DOUBLE_TAP := 0.3
const HOLD_TO_RUN := 1.0
const PICKUP_RADIUS := 0.6
const PUNCH_RANGE := 1.3

const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

var main
var model
var facing := 1
var hand_item = null
var running := false
## Throw direction on the ground plane (x along the street, y = depth).
var aim := Vector2.RIGHT

var _press_time := -1.0
var _last_tap_action := ""
var _last_tap_time := -10.0
var _hold_time := 0.0
var _last_dir := Vector2.ZERO
var _clock := 0.0
var _knock := Vector3.ZERO
var _sway := 0.0
## Ignore a press that was already down when the game (re)started.
var _block_action := false


func _ready() -> void:
	model = PersonModel.new(Color(0.27, 0.36, 0.62), Color(0.2, 0.2, 0.23),
		Color(0.96, 0.8, 0.68), Color(0.35, 0.22, 0.12))
	add_child(model)


func reset(pos: Vector3) -> void:
	position = pos
	facing = 1
	running = false
	_press_time = -1.0
	_block_action = true
	_knock = Vector3.ZERO
	if hand_item != null and is_instance_valid(hand_item):
		hand_item.queue_free()
	hand_item = null


func is_aiming() -> bool:
	return _press_time >= LONG_PRESS and hand_item != null


## 0..1 while the throw is being charged, otherwise -1.
func throw_charge() -> float:
	if _press_time < LONG_PRESS or hand_item == null:
		return -1.0
	return clampf((_press_time - LONG_PRESS) / 1.2, 0.0, 1.0)


func _process(delta: float) -> void:
	_clock += delta
	if GameState.over or GameState.modal != "":
		GameState.moving = false
		_press_time = -1.0
		model.animate(0.0, 0.0)
		return

	# Tripped over: lie on the ground for a moment.
	if _fall_t > 0.0:
		_fall_t -= delta
		GameState.moving = false
		if _fall_t <= 0.0:
			model.rotation.z = 0.0
			model.position.y = 0.0
		return

	var dir := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	# While a throw is being charged the arrows aim instead of moving.
	if is_aiming():
		if dir.length() > 0.2:
			aim = dir.normalized()
			if aim.x > 0.2:
				facing = 1
			elif aim.x < -0.2:
				facing = -1
		dir = Vector2.ZERO
	var moving := dir.length() > 0.2
	_update_run(dir, moving, delta)
	var speed := RUN_SPEED if running else WALK_SPEED
	# Without shoes walking is slower and running much harder.
	if GameState.is_lost("shoes"):
		speed *= 0.65 if running else 0.8

	var v := Vector3.ZERO
	if moving:
		var d := _apply_wrong_way(dir.normalized(), delta)
		v = Vector3(d.x, 0.0, d.y) * speed
		if d.x > 0.2:
			facing = 1
		elif d.x < -0.2:
			facing = -1

	# Heavy drinking makes the walk wobble.
	var drunk := clampf((GameState.promille - GameState.PROMILLE_DRUNK) / 1.5, 0.0, 1.0)
	if moving and drunk > 0.0:
		_sway += delta
		v.z += sin(_sway * 2.3) * 1.6 * drunk
		v.x += sin(_sway * 1.3) * 0.8 * drunk

	var before := position
	position += (v + _knock) * delta
	_knock = _knock.move_toward(Vector3.ZERO, 12.0 * delta)
	position = main.clamp_walkable(position)
	# A wrong way that runs into a wall or the curb would leave the
	# character silly-walking on the spot: drop it instead.
	if wrong_way != Vector2.ZERO and moving:
		var wanted := v.length() * delta
		if wanted > 0.0 and (position - before).length() < wanted * 0.3:
			wrong_way = Vector2.ZERO
			_wrong_cd = 1.0

	GameState.moving = moving
	GameState.running = running and moving
	model.rotation.y = 0.0 if facing > 0 else PI
	model.animate(1.0 if moving else 0.0, delta, speed / WALK_SPEED, silly_amount())

	_handle_action(delta)
	_check_pickups()
	_hunger_signs()
	_drunk_states(moving)
	for n in main.npcs:
		n.check_pickpocket(self)


# --- Drunk states ---------------------------------------------------------------

const HICCUP_PROMILLE := 1.5
const SING_PROMILLE := 2.2
const TRIP_PROMILLE := 2.8
const HUG_MIN := 2.0
const HUG_MAX := 2.5

var _hic_cd := 5.0
var _hic_jolt := 0.0
## > 0 right after a hiccup: pickpocketing gets noticed.
var hic_window := 0.0
var _sing_cd := 10.0
var _sing_t := 0.0
var _note_t := 0.0
var _fall_t := 0.0


func _drunk_states(moving: bool) -> void:
	var dt := GameState.world_dt
	var p := GameState.promille
	_hic_jolt = maxf(0.0, _hic_jolt - dt)
	hic_window = maxf(0.0, hic_window - dt)

	# Hiccups.
	if p > HICCUP_PROMILLE:
		_hic_cd -= dt
		if _hic_cd <= 0.0:
			_hic_cd = randf_range(4.0, 8.0)
			_hic_jolt = 0.15
			hic_window = 1.0
			main.popup(tr("HICCUP"), position + Vector3(0.3 * facing, 1.9, 0.3), Color(1, 1, 1))

	# Singing out loud now and then.
	if _sing_t > 0.0:
		_sing_t -= dt
		_note_t -= dt
		if _note_t <= 0.0:
			_note_t = 0.4
			main.popup_icon(main.note_texture(), position + Vector3(randf_range(-0.3, 0.3), 2.0, 0.3))
	elif p > SING_PROMILLE:
		_sing_cd -= dt
		if _sing_cd <= 0.0:
			_sing_cd = randf_range(8.0, 14.0)
			_sing_t = 2.0
			main.player_sings()

	# Tripping over when running very drunk.
	if running and moving and p > TRIP_PROMILLE:
		var per_sec := 0.2 + 0.4 * clampf((p - TRIP_PROMILLE) / 0.7, 0.0, 1.0)
		if randf() < per_sec * dt:
			_trip()

	# Love for everyone: hug the passers-by you bump into.
	if p >= HUG_MIN and p <= HUG_MAX:
		for n in main.npcs:
			if n.role == "civ" and n.state == n.S.WALK and not n.pickpocketed:
				if Vector2(n.position.x - position.x, n.position.z - position.z).length() < 0.8:
					n.hug(self)


func _trip() -> void:
	_fall_t = 1.2
	running = false
	model.rotation.z = -PI * 0.5
	model.position.y = 0.16
	GameState.busy_time = maxf(GameState.busy_time, 1.2)
	main.popup("*", position + Vector3(0.6 * facing, 0.6, 0.3), Color(1, 0.9, 0.4))
	GameState.damage(4.0)
	main.hud.flash_hurt()


## Very drunk: every now and then the character heads off in a wrong
## direction whatever arrow is pressed. Pressing the direction they are
## actually going puts them back on track, until it happens again.
const WRONG_WAY_PROMILLE := 2.5
const WRONG_WAY_RUN_MULT := 2.5
## Eight directions (arrows can steer diagonally).
const WRONG_WAY_DIRS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071), Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071)]
var wrong_way := Vector2.ZERO
var _wrong_cd := 3.0
## How long the current wrong way still lasts if the player does not
## correct it (it wears off by itself).
var _wrong_left := 0.0


func _apply_wrong_way(d: Vector2, delta: float) -> Vector2:
	var p := GameState.promille
	if p < WRONG_WAY_PROMILLE:
		wrong_way = Vector2.ZERO
		return d
	if wrong_way != Vector2.ZERO:
		if d.dot(wrong_way) > 0.65:
			# Corrected: the player steers the way the character was going.
			wrong_way = Vector2.ZERO
			var heavy := clampf((p - WRONG_WAY_PROMILLE) / 1.0, 0.0, 1.0)
			_wrong_cd = lerpf(6.0, 2.0, heavy) * randf_range(0.7, 1.3)
			return d
		# Keep pressing the arrow and it wears off by itself after a while.
		_wrong_left -= delta
		if _wrong_left <= 0.0:
			wrong_way = Vector2.ZERO
			var heavy2 := clampf((p - WRONG_WAY_PROMILLE) / 1.0, 0.0, 1.0)
			_wrong_cd = lerpf(6.0, 2.0, heavy2) * randf_range(0.7, 1.3)
			return d
		return wrong_way
	# Running drunk makes it happen much more often.
	_wrong_cd -= delta * (WRONG_WAY_RUN_MULT if running else 1.0)
	if _wrong_cd <= 0.0:
		# Any of the eight directions except the arrow's own and the exact
		# opposite.
		var options: Array = []
		for w in WRONG_WAY_DIRS:
			var dd: float = d.dot(w)
			if dd < 0.9 and dd > -0.9:
				options.append(w)
		wrong_way = options[randi() % options.size()]
		_wrong_left = randf_range(1.5, 3.0)
		return wrong_way
	return d


## No hunger meter: when hungry the stomach growls now and then and the
## character slumps a little.
var _growl_t := 0.0


## Very drunk: the absurd silly walk (strongest from about 3.2 per mille).
func silly_amount() -> float:
	return clampf((GameState.promille - 2.5) / 0.7, 0.0, 1.0)


func _hunger_signs() -> void:
	var hungry := GameState.hunger >= GameState.HUNGER_EMPTY_STOMACH
	# Hunger slumps forward; the silly walk leans back and bounces.
	model.rotation.z = (-0.12 if hungry else 0.0) + model.silly_lean
	model.position.y = model.silly_bounce + (0.15 if _hic_jolt > 0.0 else 0.0)
	# Hangover shakes.
	if GameState.promille < GameState.PROMILLE_HANGOVER:
		model.position.x = randf_range(-0.025, 0.025)
		model.position.z = randf_range(-0.025, 0.025)
	else:
		model.position.x = 0.0
		model.position.z = 0.0
	if not hungry:
		return
	_growl_t += GameState.world_dt
	if _growl_t > 4.0:
		_growl_t = 0.0
		main.popup_icon(main.stomach_texture(), position + Vector3(0.2 * facing, 1.3, 0.3))


func _update_run(dir: Vector2, moving: bool, delta: float) -> void:
	for a in MOVE_ACTIONS:
		if Input.is_action_just_pressed(a):
			if a == _last_tap_action and _clock - _last_tap_time < DOUBLE_TAP:
				running = true
			_last_tap_action = a
			_last_tap_time = _clock
	if not moving:
		running = false
		_hold_time = 0.0
		return
	if dir.round() == _last_dir.round():
		_hold_time += delta
	else:
		_hold_time = 0.0
	_last_dir = dir
	if _hold_time > HOLD_TO_RUN:
		running = true


func _handle_action(delta: float) -> void:
	if _block_action:
		if not Input.is_action_pressed("action"):
			_block_action = false
		return
	# Phone: up + action in either order, or the phone key (P / Tab).
	if Input.is_action_just_pressed("phone"):
		main.open_phone()
		_press_time = -1.0
		return
	if Input.is_action_just_pressed("action"):
		if Input.is_action_pressed("move_up"):
			main.open_phone()
			_press_time = -1.0
			return
		_press_time = 0.0
		aim = Vector2(facing, 0)
	if _press_time < 0.0:
		return
	if _press_time < LONG_PRESS and Input.is_action_just_pressed("move_up"):
		main.open_phone()
		_press_time = -1.0
		_block_action = true
		return
	_press_time += delta
	if Input.is_action_pressed("action"):
		return
	if _press_time >= LONG_PRESS and hand_item != null:
		_throw(_press_time)
	else:
		_short_action()
	_press_time = -1.0


func _short_action() -> void:
	if main.try_enter_door(position):
		return
	GameState.busy_time = maxf(GameState.busy_time, 0.35)
	var target = main.find_npc_in_front(position, facing, PUNCH_RANGE)
	if target == null and hand_item != null and main.nearest_npc_distance(position) > 2.5:
		if hand_item.kind == Item.Kind.BOTTLE:
			var amount := GameState.drink()
			main.popup("+" + GameState.format_promille(amount),
				position + Vector3(0, 2.1, 0), Color(1, 0.8, 0.3))
			_consume_hand_item()
			return
		if hand_item.kind == Item.Kind.FOOD:
			GameState.eat()
			main.popup("+", position + Vector3(0, 2.1, 0), Color(1, 0.35, 0.35))
			_consume_hand_item()
			return
	model.punch()
	if target == null:
		return
	var p := GameState.promille
	# Drunk: swings miss more often the drunker you are.
	var drunk := clampf((p - GameState.PROMILLE_DRUNK) / 1.5, 0.0, 1.0)
	if randf() < drunk * 0.35:
		main.popup("?", target.position + Vector3(0, 2.0, 0), Color(1, 1, 1))
		return
	var dmg := 1
	if p > GameState.PROMILLE_DRUNK:
		dmg = 2  # Dutch courage: harder punches
	elif p < GameState.PROMILLE_HANGOVER and randf() < 0.5:
		dmg = 0  # hangover: a feeble punch that does no harm
	target.take_hit(dmg, self)


func _consume_hand_item() -> void:
	main.items.erase(hand_item)
	hand_item.queue_free()
	hand_item = null


func _throw(t: float) -> void:
	var dist := clampf(2.0 + (t - LONG_PRESS) * 6.0, 2.0, 9.0)
	var it = hand_item
	hand_item = null
	var d3 := Vector3(aim.x, 0.0, aim.y)
	var start := global_position + d3 * 0.4 + Vector3(0, 1.1, 0.25)
	it.throw_from(start, d3, dist)
	model.punch()
	GameState.busy_time = maxf(GameState.busy_time, it.flight_time + 0.1)


func _check_pickups() -> void:
	for it in main.items.duplicate():
		if not is_instance_valid(it) or it == hand_item:
			continue
		var d := Vector2(it.global_position.x - position.x, it.global_position.z - position.z).length()
		if it.wait_far and d > PICKUP_RADIUS + 0.4:
			it.wait_far = false
		if it.can_pickup() and d < PICKUP_RADIUS:
			_pickup(it)


func _pickup(it) -> void:
	if it.kind == Item.Kind.COIN:
		GameState.money += it.value
		main.popup("+%d €" % it.value, it.global_position + Vector3(0, 1.0, 0), Color(1, 0.85, 0.3))
		main.remove_item(it)
		return
	# The hand holds one thing: touching a new item swaps it.
	if hand_item != null:
		var old = hand_item
		hand_item = null
		old.drop_at(Vector3(position.x, 0.0, position.z))
	it.hold(model.hand)
	hand_item = it


func take_hit(dmg: float, from_x: float) -> void:
	if GameState.over:
		return
	_knock = Vector3(signf(position.x - from_x) * 4.0, 0.0, 0.0)
	main.hud.flash_hurt()
	# The jacket softens blows.
	if GameState.is_lost("jacket"):
		dmg *= 1.3
	GameState.damage(dmg)
