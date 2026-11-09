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
var _run_by_stick := false
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
	model.set_soiled(false)
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
	_car_survive = ""
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
	model.set_soiled(GameState.soiled)
	running = false
	_press_time = -1.0
	_block_action = true
	_knock = Vector3.ZERO
	_ride_car = null
	_fall_t = 0.0
	_rise_t = 0.0
	_sleep_after_fall = false
	_car_survive = ""
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
	_snow_slip_cd = maxf(0.0, _snow_slip_cd - GameState.world_dt)
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

	# Dozing off: stand swaying while the eyes close, then collapse onto
	# the street (the day ends a moment later).
	if GameState.doze_t >= 0.0:
		_press_time = -1.0
		model.set_eyes(1.0)
		if GameState.doze_t < GameState.DOZE_FALL:
			model.rotation.z = sin(_clock * 3.0) * 0.06 * (GameState.doze_t / GameState.DOZE_FALL)
			model.animate(0.0, delta)
		else:
			_go_ragdoll(Vector3(facing * 0.6, 0.2, randf_range(-0.3, 0.3)), 30.0)
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
	if GameState.slippery():
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

	# Storm: the wind shoves the character along (harder when drunk, and
	# a bit even when standing still in a strong gust).
	var wind: Vector3 = main.wind_at(position + Vector3(0, 1.0, 0))
	if wind != Vector3.ZERO and not is_helpless():
		var shove := WIND_PUSH * (1.0 + drunk * 0.8)
		var still := 1.0 if moving else clampf((absf(wind.x) - 8.0) / 6.0, 0.0, 1.0)
		if still > 0.0:
			v += Vector3(wind.x, 0.0, wind.z * 0.5) * shove * still
			if not moving:
				GameState.busy_time = maxf(GameState.busy_time, 0.05)
		# Leaning into the wind.
		_wind_lean = lerpf(_wind_lean, clampf(wind.x * 0.012 * float(facing), -0.15, 0.15), 1.0 - exp(-4.0 * delta))
	else:
		_wind_lean = lerpf(_wind_lean, 0.0, 1.0 - exp(-4.0 * delta))

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
	# The charge before animate(), or the arm would always be drawn as if
	# not charging (the windup is cleared at the start of every frame).
	model.set_windup(punch_charge())
	model.animate(1.0 if moving else 0.0, delta * ts, speed / ts / WALK_SPEED, silly_amount())
	model.shade_eyes = move_toward(model.shade_eyes, main.shade_amount(), delta * 3.0)
	model.set_shoes(not GameState.is_lost("shoes"))

	_handle_action(delta)
	_check_pickups()
	_check_glass(delta)
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
	_car_flings(car.dir)
	_ride_car = car
	_car_survive = "BONNET_SURVIVE"
	running = false
	_press_time = -1.0
	model.rotation.z = PI * 0.5
	GameState.damage(15.0, "car")
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
## Hit by a car: whatever is in the hand flies up high in an arc, and
## now and then the shoes fly off too.
func _car_flings(car_dir: int) -> void:
	if hand_item != null and is_instance_valid(hand_item):
		var it = hand_item
		hand_item = null
		var start: Vector3 = model.hand.global_position
		it.launch(start, Vector3(car_dir * randf_range(2.0, 4.5), randf_range(7.5, 11.0), randf_range(-1.2, 1.2)))
	if randf() < 0.35:
		main.shoes_fly_off(position, car_dir)


## Hit by the front of a car: no bonnet ride, the impact throws the
## character straight away as a rag doll in the car's direction.
func hit_by_car_front(car_dir: int, car_speed: float) -> void:
	_car_flings(car_dir)
	running = false
	_press_time = -1.0
	var push := Vector3(car_dir * (2.5 + car_speed * 0.55), 1.8 + car_speed * 0.12, randf_range(-0.8, 0.8))
	_knock_out(40.0, push)


## Knocked over by a cyclist or an e-scooter on the sidewalk.
func hit_by_rider(dir: int, spd: float) -> void:
	running = false
	_press_time = -1.0
	GameState.fell_down()
	_go_ragdoll(Vector3(dir * spd * 0.45, 1.6, randf_range(-0.6, 0.6)), 1.6)
	GameState.damage(6.0, "bike")
	main.hud.flash_hurt()
	_maybe_fall_asleep()


## Walked into the street sweeper: knocked over.
func hit_by_sweeper(dir: int) -> void:
	running = false
	_press_time = -1.0
	GameState.fell_down()
	_go_ragdoll(Vector3(dir * 2.5, 1.4, randf_range(-0.6, 0.6)), 1.4)
	GameState.damage(10.0, "car")
	main.hud.flash_hurt()
	main.popup("!", position + Vector3(0, 2.2, 0), Color(1, 0.6, 0.2))


func run_over(car_dir: int) -> void:
	_car_flings(car_dir)
	_car_survive = "RUN_OVER_SURVIVE"
	running = false
	_press_time = -1.0
	_knock_out(55.0, Vector3(car_dir * 3.0, 0.5, randf_range(-1.0, 1.0)))


## Thrown out by a bouncer (scruff of the neck and the seat of the pants):
## flies out onto the street and lands in a heap.
func thrown_out(from_x: float, dmg: float) -> void:
	if GameState.over or _fall_t > 0.0:
		return
	running = false
	GameState.unlock("THROWN_OUT")
	var side := signf(position.x - from_x) if position.x != from_x else float(facing)
	_go_ragdoll(Vector3(side * 2.0, 2.5, 4.5), 1.8)
	GameState.damage(dmg, "bouncer")
	main.hud.flash_hurt()


## Death: fall down where standing (unless already lying as a rag doll).
func collapse_dead() -> void:
	if _ragdoll == null:
		_go_ragdoll(Vector3(facing * 0.8, 0.3, randf_range(-0.4, 0.4)), 99.0)


## Where the body is (the rag doll's torso while lying down).
func body_position() -> Vector3:
	if _ragdoll != null:
		return _ragdoll.torso_position()
	return position + Vector3(0, 0.8, 0)


## Bumped into in passing (a pickpocket): a little stagger.
func bumped(from_x: float) -> void:
	_knock = Vector3(signf(position.x - from_x) * 1.5, 0.0, 0.0)


## Choked out by a bouncer: down and out cold in place for a long moment,
## an hour passes, and health is at most half after it.
const CHOKE_OUT_TIME := 6.0
const CHOKE_OUT_MINUTES := 60.0


func choked_out() -> void:
	GameState.fell_down()
	_go_ragdoll(Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.3, 0.3)), CHOKE_OUT_TIME)
	main.hud.blackout(CHOKE_OUT_TIME * 0.7)
	main.hud.flash_hurt()
	GameState.last_hurt = "bouncer"
	GameState.health = minf(GameState.health, 50.0)
	GameState.clock_min += CHOKE_OUT_MINUTES
	main.popup("Zzz", position + Vector3(0, 1.2, 0), Color(0.8, 0.8, 1.0))


func _knock_out(dmg: float, push: Vector3) -> void:
	_go_ragdoll(push, KNOCKOUT_TIME)
	GameState.damage(dmg, "car")
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
	# Back on your feet after a car: you survived it.
	if _car_survive != "":
		GameState.unlock(_car_survive)
		_car_survive = ""
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
	if GameState.slippery():
		c += 0.02 * (2.0 if GameState.is_lost("shoes") else 1.0)
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


## True while pushing against an obstacle (see _check_stumbles).
var _obstacle_contact := false


func _check_stumbles(before: Vector3) -> void:
	# Over the curb (only where there is a sidewalk, not in the crossings).
	if absf(position.x) < BLOCK_HALF_X:
		for cz in CURB_Z:
			if (before.z - cz) * (position.z - cz) < 0.0:
				if randf() < _curb_chance():
					_trip()
					return
	# Into an obstacle: blocked; maybe down. The chance is rolled once per
	# bump, not again every frame while pushing against it (e.g. standing
	# at a bin to search it).
	for o in main.obstacles():
		var d := Vector2(position.x - o[0], position.z - o[1])
		var min_d: float = o[2] + 0.25
		if d.length() < min_d:
			var out := d.normalized() if d.length() > 0.001 else Vector2(-facing, 0)
			position.x = o[0] + out.x * min_d
			position.z = o[1] + out.y * min_d
			if not _obstacle_contact:
				_obstacle_contact = true
				if randf() < _stumble_chance(0.08, 0.35):
					_trip()
			return
	_obstacle_contact = false


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
const SNOW_SLIP_PROMILLE := 1.5
## Only sharp turns can slip, and at most one roll per this many seconds.
const SNOW_SLIP_MIN_ANGLE := 75.0
const SNOW_SLIP_COOLDOWN := 2.0
var _snow_slip_cd := 0.0


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
	if p < SNOW_SLIP_PROMILLE or absf(angle) < SNOW_SLIP_MIN_ANGLE or _snow_slip_cd > 0.0:
		return
	_snow_slip_cd = SNOW_SLIP_COOLDOWN
	var turn := pow(absf(angle) / 180.0, 2.0)  # about-turn = 1
	var drunk := clampf((p - SNOW_SLIP_PROMILLE) / 1.5, 0.0, 1.0)
	var chance := turn * lerpf(0.04, 0.2, drunk)
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


## Set when hit by a car in a way that earns an achievement if survived.
var _car_survive := ""


func _slip_on_backside() -> void:
	GameState.fell_down()
	main.popup("*", position + Vector3(0, 0.8, 0.3), Color(0.85, 0.9, 1.0))
	# Feet fly forward, body falls back.
	var back := Vector3(_slide_v.x, 0, _slide_v.z).normalized() if _slide_v.length() > 0.1 else Vector3(facing, 0, 0)
	_go_ragdoll(-back * 1.5 + Vector3(0, 1.0, 0), 1.6)
	_slide_v = Vector3.ZERO
	GameState.damage(3.0, "fall")
	main.hud.flash_hurt()
	_maybe_fall_asleep()


func _trip() -> void:
	GameState.fell_down()
	main.popup("*", position + Vector3(0.6 * facing, 0.6, 0.3), Color(1, 0.9, 0.4))
	_go_ragdoll(Vector3(facing * 4.0, 1.5, randf_range(-0.5, 0.5)), 1.6)
	GameState.damage(4.0, "fall")
	main.hud.flash_hurt()
	_maybe_fall_asleep()


## Very drunk: every now and then the character heads off in a wrong
## direction whatever arrow is pressed. Pressing the direction they are
## actually going puts them back on track, until it happens again.
## Starts later and gently: under 3 per mille rarely and only a slight
## veer (45 degrees); towards passing out often and wildly.
const WRONG_WAY_PROMILLE := 2.3
const WRONG_WAY_WILD := 3.0
const WRONG_WAY_RUN_MULT := 1.8
## Eight directions (arrows can steer diagonally).
const WRONG_WAY_DIRS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071), Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071)]
var wrong_way := Vector2.ZERO
var _wrong_cd := 3.0
## How long the current wrong way still lasts if the player does not
## correct it (it wears off by itself).
var _wrong_left := 0.0


## Seconds until the next wrong way: about 14 s at 2.3 per mille, 3 s
## near 3.5.
func _wrong_wait(p: float) -> float:
	var heavy := clampf((p - WRONG_WAY_PROMILLE) / 1.2, 0.0, 1.0)
	return lerpf(14.0, 3.0, heavy) * randf_range(0.7, 1.3)


func _apply_wrong_way(d: Vector2, delta: float) -> Vector2:
	var p := GameState.promille
	if p < WRONG_WAY_PROMILLE:
		wrong_way = Vector2.ZERO
		return d
	if wrong_way != Vector2.ZERO:
		if d.dot(wrong_way) > 0.65:
			# Corrected: the player steers the way the character was going.
			wrong_way = Vector2.ZERO
			_wrong_cd = _wrong_wait(p)
			return d
		# Keep pressing the arrow and it wears off by itself after a while.
		_wrong_left -= delta
		if _wrong_left <= 0.0:
			wrong_way = Vector2.ZERO
			_wrong_cd = _wrong_wait(p)
			return d
		return wrong_way
	# Running drunk makes it happen much more often.
	_wrong_cd -= delta * (WRONG_WAY_RUN_MULT if running else 1.0)
	if _wrong_cd <= 0.0:
		# Any of the eight directions except the arrow's own and the exact
		# opposite.
		# Under 3 per mille only a slight veer (45 degrees off), later also
		# sideways or more.
		var wild := p >= WRONG_WAY_WILD
		var options: Array = []
		for w in WRONG_WAY_DIRS:
			var dd: float = d.dot(w)
			if dd < 0.9 and dd > (-0.9 if wild else 0.5):
				options.append(w)
		if options.is_empty():
			_wrong_cd = _wrong_wait(p)
			return d
		wrong_way = options[randi() % options.size()]
		_wrong_left = randf_range(1.5, 3.0) if wild else randf_range(0.6, 1.3)
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


## Barefoot and not running: sneaking. Quiet: the police and guards
## notice only from close by, pickpocketing works better and a punch from
## behind hits even harder.
func is_sneaking() -> bool:
	return GameState.is_lost("shoes") and not running and not is_helpless()


func _hunger_signs() -> void:
	var hungry := GameState.hunger >= GameState.HUNGER_EMPTY_STOMACH
	# Sneaking: crouched forward, hands up (see PersonModel.crouch).
	model.crouch = move_toward(model.crouch, 1.0 if is_sneaking() else 0.0, get_process_delta_time() * 4.0)
	# Hunger slumps forward; the silly walk leans back and bounces.
	model.rotation.z = (-0.12 if hungry else 0.0) - 0.22 * model.crouch + model.silly_lean + _wind_lean
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
	if cold_k > 0.0 or GameState.frost:
		if cold_k > 0.0:
			shake = 0.012 + 0.02 * cold_k
		_cold_puff_t += GameState.world_dt
		# Hard frost: the breath steams all the time.
		if _cold_puff_t > (1.4 if GameState.frost else 2.2):
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
		_run_by_stick = false
		return
	# Holding an arrow just walks. Running: a double tap on an arrow, or
	# the touch stick pushed out to its edge, or Shift (gamepad RB) held
	# (exhausted, only the short burst is left).
	var hold_run := GameState.stick_run or Input.is_action_pressed("run")
	if hold_run and (not GameState.exhausted or _exhausted_run > 0.0):
		running = true
		_run_by_stick = true
	elif _run_by_stick:
		running = false
		_run_by_stick = false


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
	# Next to a beggar or a street drunk the button trades (a charged punch
	# still hits them).
	var trader = main.trader_near(position, 1.6)
	if trader != null and trader.offer_trade(self):
		return
	if target == null and hand_item != null and main.nearest_npc_distance(position) > 2.5:
		if hand_item.kind == Item.Kind.BOTTLE:
			# The amount is not shown: it sinks in slowly, and you never
			# quite know how drunk you are going to get.
			GameState.drink(Item.DRINK_PROMILLE[hand_item.drink])
			GameState.warm_up(Item.DRINK_WARMTH[hand_item.drink])
			main.popup("glug", position + Vector3(0, 2.1, 0), Color(1, 0.8, 0.3))
			_consume_hand_item()
			return
		if hand_item.kind == Item.Kind.COFFEE or hand_item.kind == Item.Kind.ENERGY:
			var coffee: bool = hand_item.kind == Item.Kind.COFFEE
			GameState.caffeinate(GameState.COFFEE_AWAKE if coffee else GameState.ENERGY_AWAKE)
			if coffee:
				GameState.warm_up(GameState.COFFEE_WARMTH)  # hot coffee
			main.popup("!", position + Vector3(0, 2.1, 0), Color(0.6, 1.0, 0.4))
			_consume_hand_item()
			return
		if hand_item.kind == Item.Kind.FOOD:
			GameState.eat()
			main.popup("+", position + Vector3(0, 2.1, 0), Color(1, 0.35, 0.35))
			_consume_hand_item()
			return
		if hand_item.kind == Item.Kind.PILLS:
			GameState.take_pills()
			main.popup("?!", position + Vector3(0, 2.1, 0), Color(1.0, 0.45, 0.85))
			_consume_hand_item()
			return
		if hand_item.kind == Item.Kind.BAG and _use_from_bag():
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
		# Swat a seagull or a dog in front.
		var an = main.animal_in_front(position, facing, PUNCH_RANGE + 0.3)
		if an != null:
			an.swat()
		return
	var p := GameState.promille
	# Drunk: swings miss more often the drunker you are.
	var drunk := clampf((p - GameState.PROMILLE_DRUNK) / 1.5, 0.0, 1.0)
	# Too much caffeine: jittery hands miss half the time.
	var miss := drunk * 0.35 + (0.5 if GameState.jitter_t > 0.0 else 0.0)
	# From behind: the target doesn't see it coming (see npc.is_back_turned).
	var surprise: bool = target.has_method("is_back_turned") and target.is_back_turned(position)
	if surprise:
		miss *= 0.0 if is_sneaking() else 0.5  # a still target is easier to hit
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
	var full := charged and charge >= 1.0
	# Counter: the opponent just swung and missed (see npc.is_open).
	var counter: bool = target.has_method("is_open") and target.is_open()
	# Combo: the third hit in a row, each within COMBO_WINDOW of the last,
	# lands extra hard and knocks them flying.
	_combo = _combo + 1 if _clock - _combo_last < COMBO_WINDOW else 1
	_combo_last = _clock
	var knock := 1.0 + charge
	if _combo >= 3:
		_combo = 0
		dmg = maxi(dmg, 1) + 1
		knock += 1.5
		main.popup("×3", target.position + Vector3(0, 2.4, 0), Color(1, 0.75, 0.25), 1.6)
	if surprise:
		# Double damage (even a hangover punch lands), triple when sneaking
		# up barefoot, and a fully charged one knocks out at once.
		dmg = maxi(dmg, 1) * (3 if is_sneaking() else 2)
		main.popup("!", target.position + Vector3(0, 2.4, 0), Color(1, 0.35, 0.2), 2.2)
		main.popup("*", target.position + Vector3(0, 1.4, 0), Color(1, 0.95, 0.5), 1.8)
	elif counter:
		dmg = maxi(dmg, 1) * 2
		main.popup("!", target.position + Vector3(0, 2.4, 0), Color(1, 0.85, 0.3), 1.8)
	# Weight: a tiny freeze and a camera jolt, bigger for harder blows.
	if dmg > 0:
		GameState.hit_stop(0.04 + 0.025 * mini(dmg, 4))
		main.shake(0.04 + 0.03 * mini(dmg, 4))
	target.take_hit(dmg, self, knock, surprise, full)
	GameState.silly_moment.emit()
	if charged and charge >= 1.0 and target.is_down() and target.times_hit == 1:
		GameState.unlock("ONE_PUNCH")


## Fighting system: one punch is free, but punching again right away
## (within SPAM_WINDOW) uses up health temporarily. Running uses it up
## too. It comes back slowly once you have neither punched nor run for
## REST_DELAY seconds.
const SPAM_WINDOW := 0.7
## Hits in a row count as a combo if each comes within this many seconds
## of the last (slower than spamming, so a steady rhythm pays off).
const COMBO_WINDOW := 1.2
var _combo := 0
var _combo_last := -10.0
const SPAM_COST := 7.0
## Temporary health used per second of running: a full heart lasts
## about 33 s (six to seven blocks) of running.
const RUN_STRAIN := 3.0
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
			GameState.damage(GameState.EXHAUST_DAMAGE * dt, "exhaust")
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
	# A lost thing up a tree (or on an awning) that way: aim up at it.
	var high = main.high_lost_target(start, d3, dist)
	it.throw_from(start, d3, dist, high.top() if high != null else Vector3.INF)
	model.punch()
	# Keep time running a little past the landing so it can bounce and roll.
	GameState.busy_time = maxf(GameState.busy_time, it.flight_time + 0.7)


## Storm: how much of the wind speed (m/s) pushes the character.
const WIND_PUSH := 0.11
var _wind_lean := 0.0


## Barefoot on broken glass: ouch (now and then while standing on it).
const GLASS_DAMAGE := 4.0
var _glass_cd := 0.0


func _check_glass(delta: float) -> void:
	_glass_cd = maxf(0.0, _glass_cd - delta)
	if _glass_cd > 0.0 or not GameState.is_lost("shoes") or is_helpless() or GameState.world_dt <= 0.0:
		return
	if main.glass_at(position) == null:
		return
	_glass_cd = 1.2
	GameState.damage(GLASS_DAMAGE, "glass")
	main.hud.flash_hurt()
	main.popup("Ai!", position + Vector3(0, 2.1, 0), Color(1, 0.45, 0.4))


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
	# A bag in the hand: things go into the bag (the bag stays in the hand).
	if hand_item != null and hand_item.kind == Item.Kind.BAG and it.kind != Item.Kind.BAG:
		_bag_add(it)
		return
	# Picking up a bag: whatever was in the hand goes into it.
	if it.kind == Item.Kind.BAG and hand_item != null and hand_item.kind != Item.Kind.BAG:
		var old = hand_item
		it.contents.append([old.kind, old.value, old.drink])
		it.update_bag_look()
		_consume_hand_item()
	# The hand holds one thing: touching a new item swaps it.
	if hand_item != null:
		var old = hand_item
		hand_item = null
		old.drop_at(Vector3(position.x, 0.0, position.z))
	it.hold(model.hand)
	hand_item = it
	hand_hint_t = HAND_HINT_TIME


func _bag_add(it) -> void:
	var bag = hand_item
	bag.contents.append([it.kind, it.value, it.drink])
	main.remove_item(it)
	bag.update_bag_look()
	main.popup("+", position + Vector3(0, 1.6, 0), Color(0.9, 0.95, 1.0), 0.8)
	if bag.contents.size() > Item.BAG_MAX:
		tear_bag()


## The bag tears (too full, or in a fight): everything spills on the street.
func tear_bag() -> void:
	if hand_item == null or hand_item.kind != Item.Kind.BAG:
		return
	var bag = hand_item
	var from: Vector3 = model.hand.global_position
	for e in bag.contents:
		var spilt = main.spawn_item(e[0], from, e[1], e[2])
		spilt.launch(from, Vector3(randf_range(-2.0, 2.0), randf_range(1.0, 2.5), randf_range(-1.2, 1.2)))
	bag.contents.clear()
	_consume_hand_item()
	main.popup("rits!", position + Vector3(0, 2.2, 0), Color(0.9, 0.95, 1.0))
	GameState.busy_time = maxf(GameState.busy_time, 1.0)


## Short press with a bag: use the last thing in it that can be drunk or
## eaten (like holding it). False when there is nothing like that.
func _use_from_bag() -> bool:
	var bag = hand_item
	for i in range(bag.contents.size() - 1, -1, -1):
		var e: Array = bag.contents[i]
		var top := position + Vector3(0, 2.1, 0)
		match e[0]:
			Item.Kind.BOTTLE:
				GameState.drink(Item.DRINK_PROMILLE[e[2]])
				GameState.warm_up(Item.DRINK_WARMTH[e[2]])
				main.popup("glug", top, Color(1, 0.8, 0.3))
			Item.Kind.COFFEE, Item.Kind.ENERGY:
				var coffee: bool = e[0] == Item.Kind.COFFEE
				GameState.caffeinate(GameState.COFFEE_AWAKE if coffee else GameState.ENERGY_AWAKE)
				if coffee:
					GameState.warm_up(GameState.COFFEE_WARMTH)
				main.popup("!", top, Color(0.6, 1.0, 0.4))
			Item.Kind.FOOD:
				GameState.eat()
				main.popup("+", top, Color(1, 0.35, 0.35))
			Item.Kind.PILLS:
				GameState.take_pills()
				main.popup("?!", top, Color(1.0, 0.45, 0.85))
			_:
				continue
		bag.contents.remove_at(i)
		bag.update_bag_look()
		return true
	return false


## Chance that a blow tears a bag that has something in it.
const BAG_TEAR_CHANCE := 0.4


## After picking something up, a hint above the head tells what the
## action button does with it (short press / hold).
const HAND_HINT_TIME := 5.0
var hand_hint_t := 0.0


## What a short press does now with the held item (an icon id for the hint).
func hand_short_action_key() -> String:
	if hand_item == null:
		return "ACT_PUNCH"
	if main.find_npc_in_front(position, facing, PUNCH_RANGE) != null or main.nearest_npc_distance(position) <= 2.5:
		return "ACT_PUNCH"
	match hand_item.kind:
		Item.Kind.BOTTLE, Item.Kind.COFFEE, Item.Kind.ENERGY:
			return "ACT_DRINK"
		Item.Kind.FOOD, Item.Kind.PILLS:
			return "ACT_EAT"
		Item.Kind.BAG:
			for i in range(hand_item.contents.size() - 1, -1, -1):
				match hand_item.contents[i][0]:
					Item.Kind.BOTTLE, Item.Kind.COFFEE, Item.Kind.ENERGY:
						return "ACT_DRINK"
					Item.Kind.FOOD, Item.Kind.PILLS:
						return "ACT_EAT"
	return "ACT_PUNCH"


func take_hit(dmg: float, from_x: float, source := "fight") -> void:
	if GameState.over:
		return
	_knock = Vector3(signf(position.x - from_x) * 4.0, 0.0, 0.0)
	main.hud.flash_hurt()
	# A bag with things in it may tear in a fight.
	if hand_item != null and hand_item.kind == Item.Kind.BAG and not hand_item.contents.is_empty() \
			and randf() < BAG_TEAR_CHANCE:
		tear_bag()
	_combo = 0
	# The jacket softens blows.
	if GameState.is_lost("jacket"):
		dmg *= 1.3
	GameState.damage(dmg, source)
