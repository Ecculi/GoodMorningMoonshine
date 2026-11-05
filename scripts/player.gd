extends Node3D
## The playable character. Arrow keys / d-pad move, one action button:
## short press = punch / drink / eat, long press = throw the held item
## (or, with an empty hand, a charged punch).

const PersonModel = preload("res://scripts/person_model.gd")
const Ragdoll = preload("res://scripts/ragdoll.gd")
const Item = preload("res://scripts/item.gd")

const WALK_SPEED := 2.6
const RUN_SPEED := 6.4  # one block (~32 m) in about 5 s
const LONG_PRESS := 0.35
const DOUBLE_TAP := 0.3
const HOLD_TO_RUN := 1.0
const PICKUP_RADIUS := 0.6
const PUNCH_RANGE := 1.3
## Holding the button with an empty hand bends the arm at the elbow and
## pulls it back: the longer the charge, the further the hit knocks and
## the more temporary health it costs; a full charge also does one more
## damage.
const PUNCH_CHARGE_TIME := 1.0
const CHARGED_STRAIN_MIN := 4.0
const CHARGED_STRAIN_MAX := 12.0
## Exhausted (heart all light pink): punches only this often and runs
## only this long at a time.
const EXHAUSTED_PUNCH_COOLDOWN := 2.0
const EXHAUSTED_RUN_TIME := 0.8

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
## Direction the body turns towards (radians; 0 = facing right).
var _yaw_target := 0.0
var _punch_cooldown := 0.0
var _exhausted_run := EXHAUSTED_RUN_TIME
## World time the heart has been all pink without resting.
var _exhaust_t := 0.0


func _ready() -> void:
	model = PersonModel.new(Color(0.27, 0.36, 0.62), Color(0.2, 0.2, 0.23),
		Color(0.96, 0.8, 0.68), Color(0.35, 0.22, 0.12))
	add_child(model)


func reset(pos: Vector3) -> void:
	position = pos
	facing = 1
	_yaw_target = 0.0
	running = false
	_press_time = -1.0
	_block_action = true
	_punch_cooldown = 0.0
	_exhausted_run = EXHAUSTED_RUN_TIME
	_exhaust_t = 0.0
	GameState.charging = false
	model.set_windup(-1.0)
	_knock = Vector3.ZERO
	if hand_item != null and is_instance_valid(hand_item):
		hand_item.queue_free()
	hand_item = null
	_ride_car = null
	_fall_t = 0.0
	_sleep_after_fall = false
	if _ragdoll != null:
		_ragdoll.queue_free()
		_ragdoll = null
	model.visible = true
	model.rotation.z = 0.0
	model.position.y = 0.0
	_rise_t = 0.0
	car_grace = 0.0


## Morning: clear any fall, rag doll or knockout left over from the night
## (e.g. fell asleep on the ground). Keeps what is in the hand.
func wake_up() -> void:
	running = false
	_press_time = -1.0
	_block_action = true
	_knock = Vector3.ZERO
	_ride_car = null
	_fall_t = 0.0
	_rise_t = 0.0
	_sleep_after_fall = false
	if _ragdoll != null:
		_ragdoll.queue_free()
		_ragdoll = null
	model.visible = true
	model.rotation.z = 0.0
	model.position.y = 0.0
	model.set_windup(-1.0)
	GameState.charging = false


func is_aiming() -> bool:
	return _press_time >= LONG_PRESS and hand_item != null


## 0..1 while the throw is being charged, otherwise -1.
func throw_charge() -> float:
	if _press_time < LONG_PRESS or hand_item == null:
		return -1.0
	return clampf((_press_time - LONG_PRESS) / 1.2, 0.0, 1.0)


## 0..1 while an empty-handed punch is being charged, otherwise -1.
func punch_charge() -> float:
	if _press_time < LONG_PRESS or hand_item != null:
		return -1.0
	return clampf((_press_time - LONG_PRESS) / PUNCH_CHARGE_TIME, 0.0, 1.0)


func _process(delta: float) -> void:
	_clock += delta
	_punch_cooldown = maxf(0.0, _punch_cooldown - delta)
	hand_hint_t = maxf(0.0, hand_hint_t - delta)
	# _handle_action sets these again while the button is held.
	GameState.charging = false
	model.set_windup(-1.0)
	_update_rest(delta)
	if GameState.over or GameState.modal != "":
		GameState.moving = false
		_press_time = -1.0
		model.animate(0.0, 0.0)
		return

	# Hit by a car: riding on the bonnet, then flying onto the street.
	if _ride_car != null:
		_ride_on_car(delta)
		return
	# Fallen over or knocked out: the rag doll does the falling; then get up
	# where it ended.
	# Getting back up: wait until standing.
	if _rise_t > 0.0:
		_rise_t -= delta
		GameState.moving = false
		return
	if _fall_t > 0.0:
		_fall_t -= delta
		GameState.moving = false
		if _ragdoll != null:
			var t: Vector3 = _ragdoll.torso_position()
			position = main.clamp_walkable(Vector3(t.x, 0.0, t.z))
		if _fall_t <= 0.0:
			if _sleep_after_fall:
				_sleep_after_fall = false
				GameState.fall_asleep("SLEEP_FELL")
			else:
				_get_up()
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
	_limit_exhausted_run(moving, delta)
	var speed := RUN_SPEED if running else WALK_SPEED
	# Button held (charging): the player slows down with the world,
	# unless the pills are working.
	var ts := _time_scale()
	speed *= ts
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

	# Snow: slippery. The character slides on after letting go (longer the
	# drunker) and turns lazily; sharp turns can end on the backside.
	if GameState.weather == "snow":
		if moving:
			_check_snow_slip(Vector2(v.x, v.z), speed)
		var slide_time := 0.3 + 0.5 * maxf(GameState.promille, 0.0)
		_slide_v = _slide_v.lerp(v, 1.0 - exp(-delta * 3.0 / slide_time))
		v = _slide_v
		if not moving and _slide_v.length() > 0.3:
			# Still sliding: time keeps running.
			GameState.busy_time = maxf(GameState.busy_time, 0.05)
	else:
		_slide_v = v
	var sliding := _slide_v.length() > 0.3 and not moving

	var before := position
	position += (v + _knock) * delta
	_knock = _knock.move_toward(Vector3.ZERO, 12.0 * delta)
	position = main.clamp_walkable(position)
	if moving or sliding:
		_check_stumbles(before)
	_collide_cars(before)
	# A wrong way that runs into a wall or the curb would leave the
	# character silly-walking on the spot: drop it instead.
	if wrong_way != Vector2.ZERO and moving:
		var wanted := v.length() * delta
		if wanted > 0.0 and (position - before).length() < wanted * 0.3:
			wrong_way = Vector2.ZERO
			_wrong_cd = 1.0

	GameState.moving = moving
	GameState.running = running and moving
	# Turn smoothly towards where the character walks (also up, down and
	# diagonally); while aiming a throw, towards the aim.
	var look := Vector2.ZERO
	if is_aiming():
		look = aim
	elif moving or sliding:
		look = Vector2(v.x, v.z)
	if look.length() > 0.1:
		_yaw_target = atan2(-look.y, look.x)
	model.rotation.y = lerp_angle(model.rotation.y, _yaw_target, 1.0 - exp(-14.0 * delta))
	model.animate(1.0 if moving else 0.0, delta * ts, speed / ts / WALK_SPEED, silly_amount())
	model.set_windup(punch_charge())

	_handle_action(delta)
	_check_pickups()
	_hunger_signs()
	_drunk_states(moving)
	for n in main.npcs:
		n.check_pickpocket(self)


# --- Drunk states ---------------------------------------------------------------

const HICCUP_PROMILLE := 0.8
const SING_PROMILLE := 1.5
const TRIP_PROMILLE := 2.1
const HUG_MIN := 1.3
const HUG_MAX := 1.8

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
	car_grace = maxf(0.0, car_grace - dt)
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


	# Love for everyone: hug the passers-by you bump into.
	if p >= HUG_MIN and p <= HUG_MAX:
		for n in main.npcs:
			if n.role == "civ" and n.state == n.S.WALK and not n.pickpocketed:
				if Vector2(n.position.x - position.x, n.position.z - position.z).length() < 0.8:
					n.hug(self)


# --- Hit by a car -------------------------------------------------------------------

const KNOCKOUT_TIME := 4.0
## Just got up: cars can't hit you for this long.
const CAR_GRACE := 1.5
var car_grace := 0.0
const BLOCK_HALF_X := 16.0
var _ride_car = null
var _ragdoll = null


## Thrown onto the bonnet: ride along until the car brakes.
func start_bonnet_ride(car) -> void:
	_ride_car = car
	running = false
	_press_time = -1.0
	model.rotation.z = PI * 0.5
	GameState.damage(15.0)
	main.hud.flash_hurt()


func _ride_on_car(_delta: float) -> void:
	GameState.busy_time = maxf(GameState.busy_time, 0.5)
	GameState.moving = false
	if not is_instance_valid(_ride_car):
		_launch(facing)
		return
	position = Vector3(_ride_car.position.x + _ride_car.dir * 0.9, 0.0, _ride_car.position.z)
	model.position.y = 1.05
	# The car has braked hard: off you go, onto the street.
	if _ride_car.braking and _ride_car.speed < 1.5:
		var d: int = _ride_car.dir
		_ride_car = null
		_launch(d)


## Thrown off the bonnet: the rag doll flies onto the street.
func _launch(d: int) -> void:
	_ride_car = null
	model.rotation.z = 0.0
	_knock_out(25.0, Vector3(d * randf_range(6.0, 8.0), randf_range(3.0, 4.5), randf_range(-0.8, 0.8)))


## Run over: straight under the car, which doesn't even slow down.
func run_over(car_dir: int) -> void:
	running = false
	_press_time = -1.0
	_knock_out(55.0, Vector3(car_dir * 3.0, 0.5, randf_range(-1.0, 1.0)))


func _knock_out(dmg: float, push: Vector3) -> void:
	_go_ragdoll(push, KNOCKOUT_TIME)
	GameState.damage(dmg)
	main.hud.flash_hurt()
	main.hud.blackout(1.6)


func _go_ragdoll(push: Vector3, time: float) -> void:
	_fall_t = time
	running = false
	_press_time = -1.0
	GameState.busy_time = maxf(GameState.busy_time, time)
	if _ragdoll != null:
		_ragdoll.queue_free()
	model.position.y = 0.0
	_ragdoll = Ragdoll.new()
	add_child(_ragdoll)
	_ragdoll.build(model, push)
	model.visible = false


const RISE_TIME := 0.7
var _rise_t := 0.0


func _get_up() -> void:
	car_grace = CAR_GRACE
	model.visible = true
	if _ragdoll != null:
		# Rise from the pose the rag doll ended in.
		var pose: Dictionary = _ragdoll.lying_pose(facing, model.scale.x)
		position = main.clamp_walkable(pose["feet"])
		model.rotation.y = 0.0 if facing > 0 else PI
		_yaw_target = model.rotation.y
		model.rise_from(pose["angle"], RISE_TIME)
		_rise_t = RISE_TIME
		GameState.busy_time = maxf(GameState.busy_time, RISE_TIME)
		_ragdoll.queue_free()
		_ragdoll = null
	else:
		model.rotation.z = 0.0
		model.position.y = 0.0


func is_helpless() -> bool:
	return _ride_car != null or _fall_t > 0.0 or _rise_t > 0.0


## Falling only happens on a change of surface (stepping over the curb
## between the road and the sidewalk) or when walking into something
## (tree, lamp post, bench, bin, sign pole). Drunk, running or snow make
## it likelier; sober on dry ground you just bump and stop.
const CURB_Z := [-5.0, 2.5]


## `low`/`high`: chance at 2.0 and at 3.5 per mille.
func _stumble_chance(low: float, high: float) -> float:
	var p := GameState.promille
	var c := 0.0
	if p > GameState.PROMILLE_DRUNK:
		c += lerpf(low, high, clampf((p - GameState.PROMILLE_DRUNK) / 1.5, 0.0, 1.0))
	if GameState.weather == "snow":
		c += 0.05 * (2.0 if GameState.is_lost("shoes") else 1.0)
	if running:
		c *= 1.5
	return clampf(c, 0.0, 0.9)


## Running over the curb can always trip, more likely the drunker you are.
## Walking stays fairly safe (only risky when very drunk).
const CURB_RUN_BASE := 0.03
const CURB_RUN_PER_PROMILLE := 0.06


func _curb_chance() -> float:
	var c := _stumble_chance(0.02, 0.15)
	if running:
		c += CURB_RUN_BASE + CURB_RUN_PER_PROMILLE * maxf(GameState.promille, 0.0)
	return clampf(c, 0.0, 0.9)


func _check_stumbles(before: Vector3) -> void:
	# Over the curb (only where there is a sidewalk, not in the crossings).
	if absf(position.x) < BLOCK_HALF_X:
		for cz in CURB_Z:
			if (before.z - cz) * (position.z - cz) < 0.0:
				if randf() < _curb_chance():
					_trip()
					return
	# Into an obstacle: blocked; maybe down.
	for o in main.obstacles():
		var d := Vector2(position.x - o[0], position.z - o[1])
		var min_d: float = o[2] + 0.25
		if d.length() < min_d:
			var out := d.normalized() if d.length() > 0.001 else Vector2(-facing, 0)
			position.x = o[0] + out.x * min_d
			position.z = o[1] + out.y * min_d
			if Vector2(before.x - o[0], before.z - o[1]).length() >= min_d - 0.01:
				if randf() < _stumble_chance(0.08, 0.35):
					_trip()
			return


## Cars are solid: no walking through them. Walking into a side can make
## the driver stop and get out.
func _collide_cars(before: Vector3) -> void:
	for c in main.cars:
		var hx: float = main.Car.HALF_LEN + 0.25
		var hz: float = main.Car.HALF_WIDTH + 0.25
		var dx: float = position.x - c.position.x
		var dz: float = position.z - c.position.z
		if absf(dx) >= hx or absf(dz) >= hz:
			continue
		var pen_x := hx - absf(dx)
		var pen_z := hz - absf(dz)
		if pen_z < pen_x:
			position.z = c.position.z + (1.0 if dz >= 0.0 else -1.0) * hz
			var was_out := absf(before.z - c.position.z) >= hz - 0.02
			if was_out:
				c.side_bump(self)
		else:
			position.x = c.position.x + (1.0 if dx >= 0.0 else -1.0) * hx


var _slide_v := Vector3.ZERO
var _slip_dir := Vector2.ZERO
const SNOW_SLIP_PROMILLE := 1.1


## Snow above 1.1 per mille: a sharp change of direction can land the
## character on their backside. Walking straight on almost never does;
## the chance grows with the turn angle and is highest for an about-turn.
func _check_snow_slip(want: Vector2, speed: float) -> void:
	if want.length() < 0.1:
		return
	var nd := want.normalized()
	if _slip_dir == Vector2.ZERO:
		_slip_dir = nd
		return
	var angle := rad_to_deg(_slip_dir.angle_to(nd))
	if absf(angle) < 30.0:
		_slip_dir = _slip_dir.lerp(nd, 0.2).normalized()
		return
	_slip_dir = nd
	var p := GameState.promille
	if p < SNOW_SLIP_PROMILLE:
		return
	var turn := pow(absf(angle) / 180.0, 2.0)  # about-turn = 1
	var drunk := clampf((p - SNOW_SLIP_PROMILLE) / 1.5, 0.0, 1.0)
	var chance := turn * lerpf(0.08, 0.4, drunk)
	if running:
		chance *= 1.4
	if GameState.is_lost("shoes"):
		chance *= 1.5
	if randf() < clampf(chance, 0.0, 0.85):
		_slip_on_backside()


## Tired (eyes closing) or drunk eyelids drooping: a fall can end in
## falling asleep right there on the ground.
const FALL_ASLEEP_CHANCE := 0.5
const DROWSY_TIRED := 40.0
const DROWSY_PROMILLE := 2.0
var _sleep_after_fall := false


func _is_drowsy() -> bool:
	return GameState.tired >= DROWSY_TIRED or GameState.promille >= DROWSY_PROMILLE


## Called after a trip or slip: maybe stay down and sleep.
func _maybe_fall_asleep() -> void:
	if _is_drowsy() and randf() < FALL_ASLEEP_CHANCE:
		_sleep_after_fall = true
		main.popup("Zzz", position + Vector3(0.2 * facing, 1.2, 0.3), Color(0.8, 0.85, 1.0))


func _slip_on_backside() -> void:
	main.popup("*", position + Vector3(0, 0.8, 0.3), Color(0.85, 0.9, 1.0))
	# Feet fly forward, body falls back.
	var back := Vector3(_slide_v.x, 0, _slide_v.z).normalized() if _slide_v.length() > 0.1 else Vector3(facing, 0, 0)
	_go_ragdoll(-back * 1.5 + Vector3(0, 1.0, 0), 1.6)
	_slide_v = Vector3.ZERO
	GameState.damage(3.0)
	main.hud.flash_hurt()
	_maybe_fall_asleep()


func _trip() -> void:
	main.popup("*", position + Vector3(0.6 * facing, 0.6, 0.3), Color(1, 0.9, 0.4))
	_go_ragdoll(Vector3(facing * 4.0, 1.5, randf_range(-0.5, 0.5)), 1.6)
	GameState.damage(4.0)
	main.hud.flash_hurt()
	_maybe_fall_asleep()


## Very drunk: every now and then the character heads off in a wrong
## direction whatever arrow is pressed. Pressing the direction they are
## actually going puts them back on track, until it happens again.
const WRONG_WAY_PROMILLE := 1.8
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
var _cold_puff_t := 0.0
var _hang_jerk := 0.0
var _hang_jerk_cd := 2.0
var _zzz_t := 0.0


## Very drunk: the absurd silly walk. It grows gradually with the per
## mille: starts at 1.8 and is at its strongest from about 2.5.
const SILLY_START := 1.8
const SILLY_FULL := 2.5


func silly_amount() -> float:
	return clampf((GameState.promille - SILLY_START) / (SILLY_FULL - SILLY_START), 0.0, 1.0)


## Exhausted: heavy breathing, visible even when standing still (real
## time, not world time): the chest heaves and little breath puffs rise.
var _breath_t := 0.0


func _heavy_breathing() -> void:
	var s: float = 1.0
	if GameState.exhausted:
		var dt := get_process_delta_time()
		_breath_t += dt
		var heave := sin(_breath_t * 7.0)
		model.scale = Vector3(s * (1.0 + 0.02 * heave), s * (1.0 + 0.035 * heave), s * (1.0 + 0.02 * heave))
		model.rotation.z += 0.08 + 0.05 * heave
		if fmod(_breath_t, 0.9) < dt:
			main.popup_icon(main.breath_texture(), position + Vector3(0.35 * facing, 1.75, 0.3))
	elif model.scale != Vector3.ONE:
		model.scale = Vector3.ONE


func _hunger_signs() -> void:
	var hungry := GameState.hunger >= GameState.HUNGER_EMPTY_STOMACH
	# Hunger slumps forward; the silly walk leans back and bounces.
	model.rotation.z = (-0.12 if hungry else 0.0) + model.silly_lean
	model.position.y = model.silly_bounce + (0.15 if _hic_jolt > 0.0 else 0.0)
	# Cold and hangover shake differently:
	# - cold: fast fine shivering, arms hugging the body, bluish face and
	#   breath puffs;
	# - hangover: slower, uneven trembling of the whole body with a jerk
	#   now and then, pale greenish face. How bad depends on yesterday's
	#   peak per mille.
	var shake := 0.0
	var rt := Time.get_ticks_msec() / 1000.0
	var cold_k := clampf((GameState.cold - GameState.COLD_SHIVER) / 50.0, 0.0, 1.0)
	if GameState.cold < GameState.COLD_SHIVER:
		cold_k = 0.0
	model.cold_hug = move_toward(model.cold_hug, 1.0 if cold_k > 0.0 else 0.0, get_process_delta_time() * 3.0)
	if cold_k > 0.0:
		shake = 0.012 + 0.02 * cold_k
		_cold_puff_t += GameState.world_dt
		if _cold_puff_t > 2.2:
			_cold_puff_t = 0.0
			main.popup_icon(main.breath_texture(), position + Vector3(0.3 * facing, 1.72, 0.3))
	var hang := GameState.hangover_shake()
	if hang > 0.0:
		# Uneven tremor (two mixed frequencies) and occasional jerks.
		var tremor := (sin(rt * 8.3) * 0.6 + sin(rt * 13.1 + 1.7) * 0.4) * 0.045 * hang
		_hang_jerk_cd -= get_process_delta_time()
		if _hang_jerk_cd <= 0.0:
			_hang_jerk_cd = randf_range(1.5, 4.0) / maxf(hang, 0.3)
			_hang_jerk = 0.12 * hang
		_hang_jerk = move_toward(_hang_jerk, 0.0, get_process_delta_time() * 0.6)
		model.rotation.z += tremor + _hang_jerk * sin(rt * 40.0)
	if cold_k > 0.0:
		model.set_face_tint(Color(0.65, 0.78, 1.0), 0.45 * cold_k)
	elif hang > 0.0:
		model.set_face_tint(Color(0.78, 0.86, 0.62), 0.5 * hang)
	else:
		model.set_face_tint(Color.WHITE, 0.0)
	if GameState.jitter_t > 0.0:
		shake = maxf(shake, 0.03)
	# Tired: eyes close, the body slumps, Zzz now and then.
	var t := GameState.tired
	model.set_eyes((t - 40.0) / 60.0)
	model.rotation.z -= 0.18 * clampf((t - 60.0) / 40.0, 0.0, 1.0)
	if t > 70.0:
		_zzz_t += GameState.world_dt
		if _zzz_t > 5.0:
			_zzz_t = 0.0
			main.popup("Zzz", position + Vector3(0.2 * facing, 2.2, 0.3), Color(0.8, 0.85, 1.0))
	if shake > 0.0:
		model.position.x = randf_range(-shake, shake)
		model.position.z = randf_range(-shake, shake)
	else:
		model.position.x = 0.0
		model.position.z = 0.0
	_heavy_breathing()
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
	# Phone: its own button (P / Tab, gamepad Y, phone button on screen).
	if Input.is_action_just_pressed("phone"):
		main.open_phone()
		_press_time = -1.0
		return
	if Input.is_action_just_pressed("action"):
		_press_time = 0.0
		aim = Vector2(facing, 0)
	if _press_time < 0.0:
		return
	# Real time: the charge fills at the same pace even though the
	# world runs at half speed meanwhile.
	_press_time += delta
	if Input.is_action_pressed("action"):
		GameState.charging = true
		return
	if _press_time >= LONG_PRESS and hand_item != null:
		_throw(_press_time)
	elif _press_time >= LONG_PRESS:
		GameState.busy_time = maxf(GameState.busy_time, 0.35)
		_punch(main.find_npc_in_front(position, facing, PUNCH_RANGE), punch_charge(), true)
	else:
		_short_action()
	_press_time = -1.0


## Exhausted: only a few steps of running, then back to walking.
func _limit_exhausted_run(moving: bool, delta: float) -> void:
	if not GameState.exhausted:
		_exhausted_run = EXHAUSTED_RUN_TIME
		return
	if running and moving:
		_exhausted_run -= delta
		if _exhausted_run <= 0.0:
			running = false
			_hold_time = -10.0  # holding the direction does not restart the run
	elif not moving:
		_exhausted_run = minf(EXHAUSTED_RUN_TIME, _exhausted_run + delta * 0.25)


func _short_action() -> void:
	if main.try_enter_door(position):
		return
	if hand_item == null or main.nearest_npc_distance(position) > 2.5:
		if main.try_search_bin(position):
			return
	GameState.busy_time = maxf(GameState.busy_time, 0.35)
	var target = main.find_npc_in_front(position, facing, PUNCH_RANGE)
	if target == null and hand_item != null and main.nearest_npc_distance(position) > 2.5:
		if hand_item.kind == Item.Kind.BOTTLE:
			var amount := GameState.drink(Item.DRINK_PROMILLE[hand_item.drink])
			GameState.warm_up(Item.DRINK_WARMTH[hand_item.drink])
			main.popup("+" + GameState.format_promille(amount),
				position + Vector3(0, 2.1, 0), Color(1, 0.8, 0.3))
			_consume_hand_item()
			return
		if hand_item.kind == Item.Kind.COFFEE or hand_item.kind == Item.Kind.ENERGY:
			var coffee: bool = hand_item.kind == Item.Kind.COFFEE
			GameState.caffeinate(GameState.COFFEE_AWAKE if coffee else GameState.ENERGY_AWAKE)
			main.popup("!", position + Vector3(0, 2.1, 0), Color(0.6, 1.0, 0.4))
			_consume_hand_item()
			return
		if hand_item.kind == Item.Kind.FOOD:
			GameState.eat()
			main.popup("+", position + Vector3(0, 2.1, 0), Color(1, 0.35, 0.35))
			_consume_hand_item()
			return
	_punch(target, 0.0)


## charge 0..1: a fully charged punch hits one harder and knocks further.
## Speed of the player's own movement and animation: half while the
## action button is held, like the rest of the world (the pills keep the
## player at full speed).
func _time_scale() -> float:
	if _press_time >= 0.0 and GameState.focus_t <= 0.0:
		return GameState.CHARGE_TIME_SCALE
	return 1.0


## charged: a long-press punch with `charge` 0..1 (otherwise a quick one).
func _punch(target, charge: float, charged := false) -> void:
	# Exhausted: the arm only obeys every couple of seconds.
	if GameState.exhausted:
		main.hud.show_head_heart()
		if _punch_cooldown > 0.0:
			return
		_punch_cooldown = EXHAUSTED_PUNCH_COOLDOWN
	model.punch(charged)
	# Fighting warms you up.
	GameState.warm_up(GameState.COLD_PUNCH_WARM)
	if charged:
		GameState.add_strain(lerpf(CHARGED_STRAIN_MIN, CHARGED_STRAIN_MAX, charge))
		main.hud.show_head_heart()
		_last_punch = _clock
		_rest_t = 0.0
	else:
		_punch_strain()
	if target == null:
		return
	var p := GameState.promille
	# Drunk: swings miss more often the drunker you are.
	var drunk := clampf((p - GameState.PROMILLE_DRUNK) / 1.5, 0.0, 1.0)
	# Too much caffeine: jittery hands miss half the time.
	var miss := drunk * 0.35 + (0.5 if GameState.jitter_t > 0.0 else 0.0)
	if randf() < miss:
		main.popup("?", target.position + Vector3(0, 2.0, 0), Color(1, 1, 1))
		return
	var dmg := 1
	if p > GameState.PROMILLE_DRUNK:
		dmg = 2  # Dutch courage: harder punches
	elif p < GameState.PROMILLE_HANGOVER and randf() < 0.5:
		dmg = 0  # hangover: a feeble punch that does no harm
	if dmg > 0 and charge >= 1.0:
		dmg += 1
	target.take_hit(dmg, self, 1.0 + charge)


## Fighting system: one punch is free, but punching again right away
## (within SPAM_WINDOW) uses up health temporarily. Running uses it up
## too. It comes back slowly once you have neither punched nor run for
## REST_DELAY seconds.
const SPAM_WINDOW := 0.7
const SPAM_COST := 7.0
## Temporary health used per second of running: a full heart lasts
## about 20 s (four blocks) of running.
const RUN_STRAIN := 5.0
const REST_DELAY := 5.0
const STRAIN_RECOVERY := 4.0
var _last_punch := -10.0
var _rest_t := 0.0


func _punch_strain() -> void:
	if _clock - _last_punch < SPAM_WINDOW:
		GameState.add_strain(SPAM_COST)
		# Show a heart above the head that drains (red -> light pink).
		main.hud.show_head_heart()
	_last_punch = _clock
	_rest_t = 0.0


## Recovery happens only while time moves (walking), never by just standing.
## Exhausted, the heart may stay all pink only for a while (10 s at full
## health, 1 s near empty); after that health drops until resting starts
## and the red begins to come back.
func _update_rest(_delta: float) -> void:
	var dt := GameState.world_dt
	_rest_t += dt
	if GameState.running:
		GameState.add_strain(RUN_STRAIN * dt)
		_rest_t = 0.0
	if GameState.exhausted and _rest_t <= REST_DELAY:
		_exhaust_t += dt
		if _exhaust_t > GameState.exhaust_grace():
			GameState.damage(GameState.EXHAUST_DAMAGE * dt)
	else:
		_exhaust_t = 0.0
	if _rest_t > REST_DELAY:
		GameState.recover_strain(STRAIN_RECOVERY * dt)


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
	hand_hint_t = HAND_HINT_TIME


## After picking something up, a hint above the head tells what the
## action button does with it (short press / hold).
const HAND_HINT_TIME := 5.0
var hand_hint_t := 0.0


## Translation key for what a short press does now with the held item.
func hand_short_action_key() -> String:
	if hand_item == null:
		return "ACT_PUNCH"
	if main.find_npc_in_front(position, facing, PUNCH_RANGE) != null or main.nearest_npc_distance(position) <= 2.5:
		return "ACT_PUNCH"
	match hand_item.kind:
		Item.Kind.BOTTLE, Item.Kind.COFFEE, Item.Kind.ENERGY:
			return "ACT_DRINK"
		Item.Kind.FOOD:
			return "ACT_EAT"
	return "ACT_PUNCH"


func take_hit(dmg: float, from_x: float) -> void:
	if GameState.over:
		return
	_knock = Vector3(signf(position.x - from_x) * 4.0, 0.0, 0.0)
	main.hud.flash_hurt()
	# The jacket softens blows.
	if GameState.is_lost("jacket"):
		dmg *= 1.3
	GameState.damage(dmg)
