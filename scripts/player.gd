extends Node3D
## The playable character. Arrow keys / d-pad move, one action button:
## short press = punch / drink / eat, long press = throw the held item.

const PersonModel = preload("res://scripts/person_model.gd")
const Item = preload("res://scripts/item.gd")

const WALK_SPEED := 2.6
const RUN_SPEED := 6.4  # one block (~32 m) in about 5 s
const X_LIMIT := 21.0
const Z_MIN := -7.4
const Z_MAX := 5.2
const LONG_PRESS := 0.35
const DOUBLE_TAP := 0.3
const HOLD_TO_RUN := 1.0
const PICKUP_RADIUS := 0.6
const PUNCH_RANGE := 1.3
## Holding the button with an empty hand pulls the arm back for a
## stronger punch.
const PUNCH_CHARGE_TIME := 1.2
## Out of breath: punches only this often, runs only this long at a time.
const WINDED_PUNCH_COOLDOWN := 2.0
const WINDED_RUN_TIME := 0.8
## Tripping over a curb (street <-> sidewalk). Never on flat ground.
## Running: chance grows with per mille. Walking is fairly safe and only
## risky when very drunk.
const TRIP_RUN_BASE := 0.04
const TRIP_RUN_PER_PROMILLE := 0.11
const TRIP_RUN_MAX := 0.6
const TRIP_WALK_FROM := 2.0  # per mille where walking starts to be risky
const TRIP_WALK_PER_PROMILLE := 0.04
const FALL_TIME := 1.4
const FALL_DAMAGE := 4.0

const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

var main
var model
var facing := 1
var hand_item = null
var running := false

var _press_time := -1.0
var _last_tap_action := ""
var _last_tap_time := -10.0
var _hold_time := 0.0
var _last_dir := Vector2.ZERO
var _clock := 0.0
var _knock := Vector3.ZERO
var _sway := 0.0
var _punch_cooldown := 0.0
var _winded_run := WINDED_RUN_TIME
var _fall_time := 0.0
var _on_sidewalk := false


func _ready() -> void:
	model = PersonModel.new(Color(0.27, 0.36, 0.62), Color(0.2, 0.2, 0.23),
		Color(0.96, 0.8, 0.68), Color(0.35, 0.22, 0.12))
	add_child(model)


func reset(pos: Vector3) -> void:
	position = pos
	facing = 1
	running = false
	_press_time = -1.0
	_punch_cooldown = 0.0
	_winded_run = WINDED_RUN_TIME
	_fall_time = 0.0
	model.stand_up()
	_on_sidewalk = main.is_sidewalk(position)
	_knock = Vector3.ZERO
	if hand_item != null and is_instance_valid(hand_item):
		hand_item.queue_free()
	hand_item = null


## 0..1 while a throw or punch is being charged, otherwise -1.
func throw_charge() -> float:
	if _press_time < LONG_PRESS:
		return -1.0
	if hand_item == null:
		return punch_charge()
	return clampf((_press_time - LONG_PRESS) / 1.2, 0.0, 1.0)


## 0..1 while an empty-handed punch is being charged, otherwise -1.
func punch_charge() -> float:
	if _press_time < LONG_PRESS or hand_item != null:
		return -1.0
	return clampf((_press_time - LONG_PRESS) / PUNCH_CHARGE_TIME, 0.0, 1.0)


func _process(delta: float) -> void:
	_clock += delta
	if GameState.over:
		GameState.moving = false
		GameState.charging = false
		_press_time = -1.0
		return
	_punch_cooldown = maxf(0.0, _punch_cooldown - delta)
	if _fall_time > 0.0:
		_lie_on_ground(delta)
		return

	var dir := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	var moving := dir.length() > 0.2
	_update_run(dir, moving, delta)
	_limit_winded_run(moving, delta)
	var speed := RUN_SPEED if running else WALK_SPEED

	var v := Vector3.ZERO
	if moving:
		var d := dir.normalized()
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

	position += (v + _knock) * delta
	_knock = _knock.move_toward(Vector3.ZERO, 12.0 * delta)
	position.x = clampf(position.x, -X_LIMIT, X_LIMIT)
	position.z = clampf(position.z, Z_MIN, Z_MAX)
	var sidewalk: bool = main.is_sidewalk(position)
	if sidewalk != _on_sidewalk and moving:
		_maybe_trip()
	_on_sidewalk = sidewalk
	if _fall_time > 0.0:
		return

	GameState.moving = moving
	GameState.running = running and moving
	model.rotation.y = 0.0 if facing > 0 else PI
	model.animate(1.0 if moving else 0.0, delta, speed / WALK_SPEED)
	model.set_windup(punch_charge())

	_handle_action(delta)
	_check_pickups()
	for n in main.npcs:
		n.check_pickpocket(self)


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


## Called when the character crosses a curb.
func _maybe_trip() -> void:
	var p := GameState.promille
	var chance := 0.0
	if running:
		chance = minf(TRIP_RUN_MAX, TRIP_RUN_BASE + TRIP_RUN_PER_PROMILLE * p)
	else:
		chance = maxf(0.0, p - TRIP_WALK_FROM) * TRIP_WALK_PER_PROMILLE
	if main.rng.randf() < chance:
		_fall()


func _fall() -> void:
	_fall_time = FALL_TIME
	running = false
	_hold_time = 0.0
	_press_time = -1.0
	GameState.moving = false
	GameState.running = false
	GameState.charging = false
	model.set_windup(-1.0)
	model.lie_down()
	# Whatever was in the hand drops on the ground.
	if hand_item != null:
		var it = hand_item
		hand_item = null
		it.drop_at(Vector3(position.x + 0.5 * facing, 0.0, position.z))
	main.hud.flash_hurt()
	GameState.damage(FALL_DAMAGE)


## Lying on the ground after a fall; time runs while getting up.
func _lie_on_ground(delta: float) -> void:
	GameState.moving = false
	GameState.running = false
	GameState.charging = false
	GameState.busy_time = maxf(GameState.busy_time, 0.1)
	_press_time = -1.0
	_fall_time -= delta
	if _fall_time <= 0.0:
		_fall_time = 0.0
		model.stand_up()


## Out of breath: only a few steps of running, then back to walking.
func _limit_winded_run(moving: bool, delta: float) -> void:
	if not GameState.winded:
		_winded_run = WINDED_RUN_TIME
		return
	if running and moving:
		_winded_run -= delta
		if _winded_run <= 0.0:
			running = false
			_hold_time = -10.0  # holding the direction does not restart the run
	elif not moving:
		_winded_run = minf(WINDED_RUN_TIME, _winded_run + delta * 0.25)


func _handle_action(delta: float) -> void:
	if Input.is_action_just_pressed("action"):
		_press_time = 0.0
	if _press_time < 0.0:
		GameState.charging = false
		return
	# Real time: the charge fills at the same pace even though the
	# world runs at half speed meanwhile.
	_press_time += delta
	GameState.charging = true
	if Input.is_action_pressed("action"):
		return
	GameState.charging = false
	if _press_time >= LONG_PRESS and hand_item != null:
		_throw(_press_time)
	elif _press_time >= LONG_PRESS:
		_punch(punch_charge())
	else:
		_short_action()
	_press_time = -1.0


func _short_action() -> void:
	GameState.busy_time = maxf(GameState.busy_time, 0.35)
	var target = main.find_npc_in_front(position, facing, PUNCH_RANGE)
	if target == null and hand_item != null and main.nearest_npc_distance(position) > 2.5:
		if hand_item.kind == Item.Kind.BOTTLE:
			GameState.drink()
			main.popup("+" + GameState.format_promille(GameState.DRINK_AMOUNT),
				position + Vector3(0, 2.1, 0), Color(1, 0.8, 0.3))
			_consume_hand_item()
			return
		if hand_item.kind == Item.Kind.FOOD:
			GameState.eat()
			main.popup("+", position + Vector3(0, 2.1, 0), Color(1, 0.35, 0.35))
			_consume_hand_item()
			return
	_punch(0.0)


## charge 0..1: a fully charged punch hits twice as hard and knocks further.
func _punch(charge: float) -> void:
	GameState.busy_time = maxf(GameState.busy_time, 0.35)
	# Out of breath, the arm only obeys every couple of seconds.
	if GameState.winded and _punch_cooldown > 0.0:
		return
	GameState.exert(GameState.STAMINA_PUNCH + GameState.STAMINA_PUNCH_CHARGED * charge)
	if GameState.winded:
		_punch_cooldown = WINDED_PUNCH_COOLDOWN
	model.punch()
	var target = main.find_npc_in_front(position, facing, PUNCH_RANGE)
	if target != null:
		target.take_hit(1 + int(round(charge)), self, 1.0 + charge)


func _consume_hand_item() -> void:
	main.items.erase(hand_item)
	hand_item.queue_free()
	hand_item = null


func _throw(t: float) -> void:
	var dist := clampf(2.0 + (t - LONG_PRESS) * 6.0, 2.0, 9.0)
	var it = hand_item
	hand_item = null
	var start := global_position + Vector3(0.4 * facing, 1.1, 0.25)
	it.throw_from(start, facing, dist)
	model.punch()
	GameState.exert(GameState.STAMINA_THROW)
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
	GameState.damage(dmg)
