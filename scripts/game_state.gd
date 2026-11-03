extends Node
## Global game state: the character's condition, the clock and the
## "time only moves when the player does something" rule.

const CityMap = preload("res://scripts/city_map.gd")
const LostItems = preload("res://scripts/lost_items.gd")

signal day_ended(cause: String)
signal player_died(cause: String)

const DAY_START_MIN := 7 * 60
const DAY_END_MIN := 24 * 60
## Seconds of continuous activity that make up one game day.
const DAY_ACTIVE_SECONDS := 180.0

const PROMILLE_START := 0.8
const PROMILLE_HANGOVER := 0.5
const PROMILLE_DRUNK := 2.0
const PROMILLE_PASS_OUT := 3.5
const PROMILLE_MAX_SHOWN := 4.0
## Per mille lost per second of activity (running burns faster).
const PROMILLE_DECAY := 0.0135
const RUN_DECAY_MULT := 1.6
const DRINK_AMOUNT := 0.4
const FOOD_HEALTH := 12.0

## Sleep always burns at least this much alcohol...
const SLEEP_MIN_DROP := 0.6
## ...but the day never starts below this, or it would be over at once.
const MORNING_MIN_PROMILLE := 0.25

## Hunger 0..100 (no meter: the stomach growls and the character looks
## hungry). Grows with activity and overnight.
const HUNGER_RATE := 0.25
const HUNGER_SLEEP := 25.0
const HUNGER_HURTS := 70.0
const HUNGER_EMPTY_STOMACH := 60.0
const FOOD_HUNGER := 40.0

var day := 1
var promille := PROMILLE_START
var health := 100.0
var money := 0
var hunger := 20.0
var clock_min := float(DAY_START_MIN)

## Set by the player every frame.
var moving := false
var running := false
## Actions (punching, throwing) keep the world running for a moment.
var busy_time := 0.0
## True while the world advances this frame.
var active := false
## Delta time for everything that lives in the game world (0 when frozen).
var world_dt := 0.0
## True during death and day-change screens.
var over := false

## Home for this game: block and the door's x position in it.
var home_seg := CityMap.START
var home_x := 0.0
## "flat" (apartment), "basement" (storage room, padlock) or "friend" (sofa).
var home_type := "flat"
## The basement padlock has been smashed open (stays broken for the game).
var lock_broken := false
## Ids of belongings that are lost (see lost_items.gd).
var lost: Array = []
## Where each lost item lies today: id -> [segment, position].
var placements := {}
## Where the character slept: "home", "stairs" or "street".
var sleep_place := "home"
var bonus := 0
## Where the character wakes up (from day 2 on: never at home).
var wake_seg := CityMap.START
var wake_pos := Vector3.ZERO
## Today's weather: "sunny" or "cloudy" (rain and snow come later).
var weather := "sunny"

## Phone: battery 0..100 (always low), today's hints.
var battery := 20.0
## Messages: [{"icon": lost item id or "", "street": String}]
var phone_msgs: Array = []
## Yesterday's photo: {"id": item id, "seg": Vector3i, "street": String} or {}.
var phone_photo := {}
## Open full-screen thing that freezes the world: "", "phone" or "shop".
var modal := ""
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_setup_input()
	TranslationServer.set_locale("fi")


func _process(delta: float) -> void:
	if over:
		world_dt = 0.0
		active = false
		return
	if modal != "":
		world_dt = 0.0
		active = false
		return
	busy_time = maxf(0.0, busy_time - delta)
	active = moving or busy_time > 0.0
	world_dt = delta if active else 0.0
	if not active:
		return

	var mult := RUN_DECAY_MULT if running else 1.0
	promille = maxf(0.0, promille - PROMILLE_DECAY * world_dt * mult)
	clock_min += float(DAY_END_MIN - DAY_START_MIN) / DAY_ACTIVE_SECONDS * world_dt
	if promille < PROMILLE_HANGOVER:
		health -= 1.5 * world_dt
	hunger = minf(100.0, hunger + HUNGER_RATE * world_dt * mult)
	if hunger >= HUNGER_HURTS:
		health -= 1.0 * world_dt

	if promille <= 0.0:
		_die("HEADLINE_SOBER")
	elif health <= 0.0:
		_die("HEADLINE_BEATEN")
	elif promille > PROMILLE_PASS_OUT:
		sleep_place = "street"
		_end_day("SLEEP_PASSOUT")
	elif clock_min >= DAY_END_MIN:
		sleep_place = "street"
		_end_day("SLEEP_NIGHT")


## Returns how much the per mille went up: more on an empty stomach.
func drink(amount := DRINK_AMOUNT) -> float:
	if hunger >= HUNGER_EMPTY_STOMACH:
		amount *= 1.4
	promille += amount
	return amount


func eat() -> void:
	health = minf(100.0, health + FOOD_HEALTH)
	hunger = maxf(0.0, hunger - FOOD_HUNGER)


func damage(amount: float) -> void:
	health -= amount
	if health <= 0.0 and not over:
		_die("HEADLINE_BEATEN")


func score() -> int:
	var total := 0
	for d in range(1, day):
		total += d * 1000
	var owned := LostItems.IDS.size() - lost.size()
	return total + money * 100 + owned * 100 + bonus


func is_lost(id: String) -> bool:
	return lost.has(id)


func find_item(id: String) -> void:
	lost.erase(id)
	placements.erase(id)


## Entering the home door ends the day. Without keys the character sleeps
## in the stairwell outside the door.
## `place`: "home", "stairs", "basement" or "friend".
func go_home(place: String) -> void:
	if lost.is_empty():
		bonus += 500
	sleep_place = place
	var causes := {"home": "SLEEP_HOME", "stairs": "SLEEP_STAIRS", "basement": "SLEEP_BASEMENT", "friend": "SLEEP_FRIEND"}
	_end_day(causes[place])


## Search radius in grid units around home; grows every day.
func search_radius() -> float:
	return 1.0 + float(day)


func new_game() -> void:
	day = 1
	promille = PROMILLE_START
	health = 100.0
	money = 0
	hunger = 20.0
	clock_min = DAY_START_MIN
	busy_time = 0.0
	bonus = 0
	sleep_place = "home"
	home_seg = CityMap.random_segment(rng)
	while CityMap.far_side_is_sea(home_seg):
		home_seg = CityMap.random_segment(rng)
	home_x = rng.randf_range(-11.0, 11.0)
	home_type = ["flat", "basement", "friend"][rng.randi() % 3]
	lock_broken = false
	lost.clear()
	_roll_weather()
	_lose_items()
	_place_lost_items()
	_make_phone_hints()
	modal = ""
	over = false


## A short or bad sleep leaves more alcohol in the blood and heals less.
func new_day() -> void:
	var at_sleep := promille
	day += 1
	match sleep_place:
		"home":
			promille = clampf(0.4 + maxf(at_sleep - 1.5, 0.0) * 0.3, 0.3, 1.5)
			health = minf(100.0, health + 60.0)
		"friend":
			promille = clampf(0.45 + maxf(at_sleep - 1.4, 0.0) * 0.35, 0.3, 1.6)
			health = minf(100.0, health + 55.0)
		"basement":
			# Cold room: worse sleep.
			promille = clampf(0.5 + maxf(at_sleep - 1.2, 0.0) * 0.4, 0.3, 1.8)
			health = minf(100.0, health + 45.0)
		"stairs":
			promille = clampf(0.5 + maxf(at_sleep - 1.2, 0.0) * 0.4, 0.3, 1.8)
			health = minf(100.0, health + 40.0)
		_:
			promille = clampf(0.5 + maxf(at_sleep - 1.0, 0.0) * 0.5, 0.3, 2.0)
			health = minf(100.0, health + 35.0)
	# Sleeping always burns alcohol and makes you hungry.
	promille = maxf(minf(promille, at_sleep - SLEEP_MIN_DROP), MORNING_MIN_PROMILLE)
	var cold_night := sleep_place == "street" or sleep_place == "basement" or sleep_place == "stairs"
	hunger = minf(100.0, hunger + HUNGER_SLEEP + (8.0 if cold_night else 0.0))
	clock_min = DAY_START_MIN
	busy_time = 0.0
	_roll_weather()
	_choose_wake_place()
	_lose_items()
	_place_lost_items()
	_make_phone_hints()
	modal = ""
	over = false


## The player sleeps somewhere other than the street.
func slept_at_home() -> bool:
	return sleep_place != "street"


## The character went out again during the night, so from day 2 on the
## morning starts somewhere else, further from home every day.
func _choose_wake_place() -> void:
	var max_d := 1.0 + float(day)
	var min_d := minf(maxf(1.5, max_d * 0.5), max_d)
	var home_c := _seg_center(home_seg)
	var best := home_seg
	for attempt in 400:
		var cand := CityMap.random_segment(rng)
		var c := _seg_center(cand)
		var d := absf(c.x - home_c.x) + absf(c.y - home_c.y)
		if cand != home_seg and d >= min_d and d <= max_d:
			best = cand
			break
	wake_seg = best
	var z := rng.randf_range(-7.0, -5.6) if rng.randf() < 0.5 else rng.randf_range(3.2, 5.0)
	wake_pos = Vector3(rng.randf_range(-12.0, 12.0), 0.0, z)


## Every day has its own weather.
func _roll_weather() -> void:
	weather = "sunny" if rng.randf() < 0.6 else "cloudy"


## Every night new things get lost; earlier lost ones stay lost.
func _lose_items() -> void:
	var count := rng.randi_range(1, 2) if day == 1 else 1 + (1 if day >= 4 and rng.randf() < 0.5 else 0)
	var pool: Array = []
	for id in LostItems.IDS:
		if not lost.has(id):
			pool.append(id)
	pool.shuffle()
	for i in mini(count, pool.size()):
		lost.append(pool[i])


## Lost items lie in blocks near home; the area grows day by day.
## They are placed anew every morning.
func _place_lost_items() -> void:
	placements.clear()
	var radius := search_radius()
	var home_c := _seg_center(home_seg)
	for id in lost:
		var seg := home_seg
		for attempt in 300:
			var cand := CityMap.random_segment(rng)
			var d := absf(_seg_center(cand).x - home_c.x) + absf(_seg_center(cand).y - home_c.y)
			if d <= radius and cand != home_seg:
				seg = cand
				break
		var z := rng.randf_range(-7.0, -5.6) if rng.randf() < 0.5 else rng.randf_range(3.2, 5.0)
		placements[id] = [seg, Vector3(rng.randf_range(-14.0, 14.0), 0.0, z)]


## Each morning the phone has a little battery and maybe some hints about
## where things were yesterday (messages and a photo). Not every day.
func _make_phone_hints() -> void:
	battery = rng.randf_range(8.0, 25.0)
	phone_msgs.clear()
	phone_photo = {}
	var candidates: Array = []
	for id in lost:
		if id != "phone":
			candidates.append(id)
	if rng.randf() < 0.8:
		for id in candidates:
			if rng.randf() < 0.6:
				phone_msgs.append({"icon": id, "street": _hint_street(placements[id][0])})
		for i in rng.randi_range(0, 2):
			phone_msgs.append({"icon": "", "street": _hint_street(CityMap.random_segment(rng))})
		phone_msgs.shuffle()
	if not candidates.is_empty() and rng.randf() < 0.6:
		var id: String = candidates[rng.randi() % candidates.size()]
		var seg: Vector3i = placements[id][0]
		phone_photo = {"id": id, "seg": seg, "street": _hint_street(seg)}


func _hint_street(seg: Vector3i) -> String:
	if rng.randf() < 0.6:
		return CityMap.street_name(seg)
	return CityMap.cross_name(seg, rng.randf() < 0.5)


func _seg_center(seg: Vector3i) -> Vector2:
	if seg.x == 0:
		return Vector2(seg.z + 0.5, seg.y)
	return Vector2(seg.y, seg.z + 0.5)


func format_promille(p: float) -> String:
	var s := "%.1f ‰" % p
	if TranslationServer.get_locale().begins_with("fi"):
		s = s.replace(".", ",")
	return s


func _die(cause: String) -> void:
	over = true
	player_died.emit(cause)


func _end_day(cause: String) -> void:
	over = true
	day_ended.emit(cause)


func _setup_input() -> void:
	_add_action("move_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT])
	_add_action("move_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT])
	_add_action("move_up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP])
	_add_action("move_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN])
	_add_action("action", [KEY_SPACE, KEY_Z, KEY_ENTER], [JOY_BUTTON_A])
	# Shortcut for keyboards and gamepads (on touch screens: up + action).
	_add_action("phone", [KEY_P, KEY_TAB], [JOY_BUTTON_Y])
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)


func _add_action(action: String, keys: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)


func _add_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
