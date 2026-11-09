extends Node
## Global game state: the character's condition, the clock and the
## "time only moves when the player does something" rule.

const CityMap = preload("res://scripts/city_map.gd")
const LostItems = preload("res://scripts/lost_items.gd")

signal day_ended(cause: String)
signal player_died(cause: String)
signal achievement_unlocked(id: String)
## The player did something silly in public (fought, fell, drank): an
## influencer nearby may start filming.
signal silly_moment
## A video of the player went viral today: the police recognise them more
## easily (they notice from further away) for the rest of the day.
var viral := false
## How much further the police and guards notice a viral player.
const VIRAL_SIGHT := 1.6

const DAY_START_MIN := 7 * 60
const DAY_END_MIN := 24 * 60
## Seconds of continuous activity that make up one game day.
const DAY_ACTIVE_SECONDS := 180.0

const PROMILLE_START := 0.8
const PROMILLE_HANGOVER := 0.5
const PROMILLE_DRUNK := 1.3
## Passing out happens somewhere between these; a new limit every day.
const PASS_OUT_MIN := 3.2
const PASS_OUT_MAX := 4.0
const PROMILLE_MAX_SHOWN := 4.0
## Per mille lost per second of activity (running burns faster).
const PROMILLE_DECAY := 0.0135
const RUN_DECAY_MULT := 1.6
const DRINK_AMOUNT := 0.4
## A drink is not in the blood at once: each one is absorbed over
## ABSORB_TIME seconds of game time (fast at first, then slowing). Every
## drink runs its own timer, so several in a row make the per mille climb
## faster, and you never quite know how high it will still go.
const ABSORB_TIME := 20.0
## Drinks still being absorbed: [amount, seconds since drinking].
var _doses: Array = []
## Hangover: health drains below PROMILLE_HANGOVER, faster the soberer
## (per second, at the hangover limit and at zero).
const HANGOVER_DRAIN_MIN := 0.8
const HANGOVER_DRAIN_MAX := 4.0
## Nicely drunk (between these): health slowly mends by itself while
## moving; soberer or drunker, it doesn't.
const MEND_FROM := 1.0
const MEND_TO := 2.5
const MEND_RATE := 0.4
## Highest per mille today and yesterday: yesterday's peak sets how bad
## the hangover shakes are. The first morning follows a big night.
var today_max := PROMILLE_START
var yesterday_max := 2.2
## Health per 1.0 per mille drunk (beer about +4, spirits +9).
const DRINK_HEALTH := 15.0
## Share of damage that being drunk numbs away at the passing-out limit
## (grows evenly from 0.5 per mille; about a quarter at 2.0).
const DRUNK_NUMB := 0.6
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

const COLD_WEATHER := {"sunny": -0.3, "cloudy": 0.1, "rain": 0.4, "snow": 0.8}
const COLD_SHIVER := 50.0
const COLD_HUNGRY := 50.0
const COLD_HURTS := 80.0
const COLD_INDOOR_WARM := 4.0
## Ways to warm up when cold: running (per second), each punch thrown,
## and a strong drink (see Item.DRINK_WARMTH).
const COLD_RUN_WARM := 1.5
const COLD_PUNCH_WARM := 3.0

const TIRED_RATE := 0.5
const COFFEE_AWAKE := 35.0
## Hot coffee warms a little too.
const COFFEE_WARMTH := 12.0
const ENERGY_AWAKE := 45.0
const CAFFEINE_LIMIT := 1.5
const JITTER_TIME := 20.0

var day := 1
var promille := PROMILLE_START
var health := 100.0
var money := 0
var hunger := 20.0
## Temporary health loss from punching too fast (light pink in the heart).
## Comes back while walking calmly; never kills: when it uses up all the
## health the player is exhausted and can't punch until it has all
## come back.
var strain := 0.0
## Set by the player while the action button is held down: standing
## still, time then runs at half speed.
var charging := false
## Set by the touch stick: pushed out to the edge = run.
var stick_run := false
const CHARGE_TIME_SCALE := 0.5
## Pills found in a bin: for a while, while charging only the rest of the
## world slows down and the player keeps full speed.
const FOCUS_TIME := 90.0
var focus_t := 0.0
## Cold 0..100 (no meter: the character shivers). Depends on the weather and
## missing clothes; warms up indoors and on sunny days.
var cold := 20.0
## Tiredness 0..100 (no meter: the eyes close and the character slumps).
## Full = falls asleep on the spot. Grows faster in the dark.
var tired := 0.0
## Today's passing-out limit (random between PASS_OUT_MIN and PASS_OUT_MAX).
var pass_out_promille := 3.5
## Caffeine in the blood; too much at once makes the character jittery.
var caffeine := 0.0
var jitter_t := 0.0
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
## Seconds the world stays frozen after a landed punch ("hit stop").
var hit_stop_t := 0.0


## A tiny freeze when a punch lands, so it feels like it connects.
func hit_stop(t: float) -> void:
	hit_stop_t = maxf(hit_stop_t, t)
## True during death and day-change screens.
var over := false

## Home for this game: block and the door's x position in it.
var home_seg := CityMap.start()
var home_x := 0.0
## "flat" (apartment), "basement" (storage room, padlock) or "friend" (sofa).
var home_type := "flat"
## The basement padlock has been smashed open (stays broken for the game).
var lock_broken := false
## Ids of belongings that are lost (see lost_items.gd).
var lost: Array = []
## Where each lost item lies today: id -> [segment, position].
var placements := {}
## Lost things a stray dog is carrying about in its mouth today (ids).
var dog_items: Array = []
## From this day (when the dogs arrive) a lost thing may be in a dog's
## mouth, with this chance each (never the phone).
const DOG_ITEM_FROM_DAY := 3
const DOG_ITEM_CHANCE := 0.25
## Lost things someone (a passer-by) has picked up and carries about in
## their hand today (ids). From CARRIED_FROM_DAY, with this chance each
## (never the phone). Buy it back, swap a bottle for it, pickpocket it or
## knock them out.
var carried_items: Array = []
const CARRIED_FROM_DAY := 4
const CARRIED_CHANCE := 0.25
## Lost things stuck up high today (ids): in a tree top or on a shop
## awning in their block. Knock them down with a thrown thing. From
## HIGH_FROM_DAY, with this chance each (never the phone).
var high_items: Array = []
const HIGH_FROM_DAY := 5
const HIGH_CHANCE := 0.2
## Where the character slept: "home", "stairs" or "street".
var sleep_place := "home"
## Wet and soiled trousers after a night on the street (brown at the back,
## yellow at the front). Washed after a night at home or a friend's.
var soiled := false
var bonus := 0
## Item kind taken by the police (-1 = nothing); get it back at the police
## station with an ID card.
var confiscated := -1
## Where the character wakes up (from day 2 on: never at home).
var wake_seg := CityMap.start()
var wake_pos := Vector3.ZERO
## Today's weather: "sunny", "cloudy", "rain" or "snow".
var weather := "sunny"
## Storm day: hard wind pushes the character, bends throws and blows
## leaves and litter about (always cloudy or rainy).
var storm := false
## Hard frost special day: clear and bitterly cold. The cold grows much
## faster than on a snowy day, the streets are slippery like in snow and
## the breath steams all the time. Warming up (running, fighting, a strong
## drink, going indoors) matters.
var frost := false
const FROST_FROM_DAY := 2
const FROST_CHANCE := 0.12
const FROST_COLD := 1.6
## How often and from which day storms come depends on the city
## (CityMap.storm_chance / storm_from_day): Oulu now and then, Raahe
## nearly every day.

## Phone: battery 0..100 (always low), today's hints.
var battery := 20.0
## Messages: [{"icon": lost item id or "", "street": String}]
var phone_msgs: Array = []
## Yesterday's photo: {"id": item id, "seg": Vector3i, "street": String} or {}.
var phone_photo := {}
## Map hints: [{"id": item id, "seg": Vector3i}]. The map highlights the
## block (street between two crossings) where the thing lies; where in the
## block and on which side is left to find.
var phone_map_hints: Array = []
## Every lost thing gets its block on the map (an unmarked one looked
## like a bug). Lower this to hide some.
const MAP_HINT_CHANCE := 1.0
## Open full-screen thing that freezes the world: "", "phone" or "shop".
var modal := ""
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_setup_input()
	TranslationServer.set_locale("fi")
	_load_achievements()
	_load_scores()


func _process(delta: float) -> void:
	if over:
		world_dt = 0.0
		active = false
		return
	if modal == "shop":
		# Warming up inside costs time like anything else: the clock runs,
		# alcohol drops and hunger grows (but the street outside waits).
		world_dt = 0.0
		active = false
		_tick_body(delta, false)
		cold = maxf(0.0, cold - COLD_INDOOR_WARM * delta)
		return
	if modal != "":
		world_dt = 0.0
		active = false
		return
	# Dozing off on the street: the eyes close, the character collapses,
	# and only then the day ends. The world keeps going meanwhile.
	if doze_t >= 0.0:
		doze_t += delta
		active = true
		world_dt = delta
		moving = false
		running = false
		if doze_t >= DOZE_TIME:
			doze_t = -1.0
			_end_day(_doze_cause)
		return
	busy_time = maxf(0.0, busy_time - delta)
	# Holding the action button (charging a punch or a throw) slows the
	# whole world to half speed, moving or not.
	active = moving or busy_time > 0.0 or charging
	if charging:
		world_dt = delta * CHARGE_TIME_SCALE
	elif active:
		world_dt = delta
	else:
		world_dt = 0.0
	if hit_stop_t > 0.0:
		hit_stop_t -= delta
		world_dt = 0.0
		return
	if not active:
		return

	_tick_body(world_dt, running)
	_check_achievements(world_dt)
	cold = clampf(cold + cold_rate() * world_dt, 0.0, 100.0)
	if cold >= COLD_HURTS:
		health -= 0.8 * world_dt
		last_hurt = "cold"

	if promille <= 0.0:
		_die("HEADLINE_SOBER")
	elif health <= 0.0:
		_die("HEADLINE_BEATEN")
	elif tired >= 100.0:
		_start_doze("SLEEP_TIRED")
	elif promille > pass_out_promille:
		_start_doze("SLEEP_PASSOUT")
	elif clock_min >= DAY_END_MIN:
		_start_doze("SLEEP_NIGHT")


## Falling asleep on the street happens in steps (seconds from the start):
## eyes nearly shut by DOZE_EYES, the character collapses at DOZE_FALL,
## the day ends at DOZE_TIME. -1 = not dozing.
const DOZE_EYES := 1.5
const DOZE_FALL := 1.8
const DOZE_TIME := 4.5
var doze_t := -1.0
var _doze_cause := ""


func _start_doze(cause: String) -> void:
	if doze_t >= 0.0:
		return
	sleep_place = "street"
	_doze_cause = cause
	doze_t = 0.0


## 0..1 how far the eyelids are closed while dozing off (0 when awake).
func doze_lids() -> float:
	if doze_t < 0.0:
		return 0.0
	if doze_t < DOZE_EYES:
		return 0.92 * smoothstep(0.0, DOZE_EYES, doze_t)
	return lerpf(0.92, 1.0, clampf((doze_t - DOZE_FALL) / (DOZE_TIME - DOZE_FALL), 0.0, 1.0))


## Alcohol, clock, hangover and hunger for `dt` seconds of activity.
func _tick_body(dt: float, is_running: bool) -> void:
	var mult := RUN_DECAY_MULT if is_running else 1.0
	promille = maxf(0.0, promille - PROMILLE_DECAY * dt * mult)
	_absorb(dt)
	clock_min += float(DAY_END_MIN - DAY_START_MIN) / DAY_ACTIVE_SECONDS * dt
	if hangover_drain() > 0.0:
		health -= hangover_drain() * dt
		last_hurt = "hangover"
	health = minf(100.0, health + mend_rate() * dt)
	# Being cold makes you hungry faster.
	var hunger_mult := 1.5 if cold >= COLD_HUNGRY else 1.0
	hunger = minf(100.0, hunger + HUNGER_RATE * dt * mult * hunger_mult)
	if hunger >= HUNGER_HURTS:
		health -= 1.0 * dt
		last_hurt = "hunger"
	# Tiredness grows, faster when running and in the dark.
	var h := clock_min / 60.0
	var dark := 3.0 if h >= 22.0 else (2.0 if h >= 20.0 else 1.0)
	tired = minf(100.0, tired + TIRED_RATE * dt * dark * (1.3 if is_running else 1.0))
	caffeine = maxf(0.0, caffeine - dt / 60.0)
	jitter_t = maxf(0.0, jitter_t - dt)
	focus_t = maxf(0.0, focus_t - dt)
	trip_t = maxf(0.0, trip_t - dt)
	painkiller_t = maxf(0.0, painkiller_t - dt)


## How fast the character gets colder (per second of activity; negative =
## warming up). Missing clothes make it worse; being drunk numbs it.
func cold_rate() -> float:
	var r: float = COLD_WEATHER.get(weather, 0.0)
	if frost:
		r += FROST_COLD
	if is_lost("jacket"):
		r += 0.3
	if is_lost("shoes") and (weather == "rain" or weather == "snow" or frost):
		r += 0.2
	if r > 0.0 and promille > PROMILLE_DRUNK:
		r *= 0.6
	# Running keeps you warm.
	if running and moving:
		r -= COLD_RUN_WARM
	return r


## Warms the character up right away (a punch, a strong drink).
func warm_up(amount: float) -> void:
	cold = maxf(0.0, cold - amount)


## Coffee or an energy drink: less tired; two in a short time = jitters.
## Player speed multiplier while the action button is held: half, like
## the rest of the world, unless the pills are working.
func player_time_scale() -> float:
	return CHARGE_TIME_SCALE if charging and focus_t <= 0.0 else 1.0


## A painkiller from the pharmacy: no hangover shakes for this long
## (seconds of game time).
const PAINKILLER_TIME := 120.0
var painkiller_t := 0.0


## Hangover shakes 0..1: only below the hangover limit, stronger the
## bigger yesterday's peak was and the soberer you are now.
func hangover_shake() -> float:
	if promille >= PROMILLE_HANGOVER or painkiller_t > 0.0:
		return 0.0
	var peak := clampf((yesterday_max - 0.8) / 2.4, 0.15, 1.0)
	var sober := clampf((PROMILLE_HANGOVER - promille) / PROMILLE_HANGOVER, 0.0, 1.0)
	return peak * lerpf(0.5, 1.0, sober)


## A punk's pills: very drunk (a big dose, absorbed like a drink) and
## seeing things for a while (see main._update_trip and the HUD).
const PILLS_PROMILLE := 1.2
const TRIP_TIME := 60.0
var trip_t := 0.0


func take_pills() -> void:
	trip_kinds.clear()
	drink(PILLS_PROMILLE)
	trip_t = TRIP_TIME


## 0..1: how strong the visions are (fade in fast, out over the last 15 s).
func trip_amount() -> float:
	if trip_t <= 0.0:
		return 0.0
	return clampf((TRIP_TIME - trip_t) / 4.0, 0.0, 1.0) * clampf(trip_t / 15.0, 0.0, 1.0)


func caffeinate(awake: float) -> void:
	tired = maxf(0.0, tired - awake)
	caffeine += 1.0
	if caffeine > CAFFEINE_LIMIT:
		jitter_t = JITTER_TIME


## Returns how much the per mille went up: more on an empty stomach.
func drink(amount := DRINK_AMOUNT) -> float:
	if hunger >= HUNGER_EMPTY_STOMACH:
		amount *= 1.4
	# Into the stomach now; into the blood (and the health) bit by bit.
	_doses.append([amount, 0.0])
	if drinks_today == 0 and clock_min < 8.0 * 60.0:
		unlock("MORNING_BEER")
	drinks_today += 1
	silly_moment.emit()
	return amount


## Absorbs the drinks in the stomach. Each dose follows 1 - (1 - t)^2 over
## ABSORB_TIME: quick at first, tailing off. Health comes with it.
func _absorb(dt: float) -> void:
	for d in _doses.duplicate():
		var t0: float = clampf(d[1] / ABSORB_TIME, 0.0, 1.0)
		d[1] += dt
		var t1: float = clampf(d[1] / ABSORB_TIME, 0.0, 1.0)
		var got: float = d[0] * ((1.0 - pow(1.0 - t1, 2.0)) - (1.0 - pow(1.0 - t0, 2.0)))
		promille += got
		health = minf(100.0, health + got * DRINK_HEALTH)
		if t1 >= 1.0:
			_doses.erase(d)
	today_max = maxf(today_max, promille)


## Health lost per second to the hangover (0 when not hungover).
func hangover_drain() -> float:
	if promille >= PROMILLE_HANGOVER:
		return 0.0
	return lerpf(HANGOVER_DRAIN_MIN, HANGOVER_DRAIN_MAX, (PROMILLE_HANGOVER - promille) / PROMILLE_HANGOVER)


## Health mended per second when nicely drunk (soft edges).
func mend_rate() -> float:
	var k := smoothstep(MEND_FROM, MEND_FROM + 0.2, promille) * (1.0 - smoothstep(MEND_TO - 0.2, MEND_TO, promille))
	return MEND_RATE * k


func eat() -> void:
	health = minf(100.0, health + FOOD_HEALTH)
	hunger = maxf(0.0, hunger - FOOD_HUNGER)


## What last hurt the character (for the death headline): "fight", "car",
## "dog", "bouncer", "fall", "cold", "hunger", "hangover", "exhaust", "bike".
var last_hurt := "fight"


func damage(amount: float, source := "fight") -> void:
	last_hurt = source
	# Drunk, blows and falls hurt less: the drunker, the less (from 0.5 per
	# mille up to today's passing-out limit).
	amount *= 1.0 - DRUNK_NUMB * clampf((promille - 0.5) / maxf(pass_out_promille - 0.5, 0.1), 0.0, 1.0)
	health -= amount
	if health <= 0.0 and not over:
		_die("HEADLINE_BEATEN")
		return
	_check_strain()


## Spamming punches costs temporary health.
func add_strain(amount: float) -> void:
	strain += amount
	_check_strain()


## Exhausted: the temporary loss used up all the health (the whole heart
## is light pink). Punches only seldom and runs only a few steps until it
## has fully recovered.
var exhausted := false
## How long the heart may stay all pink before health starts to drop:
## 10 s with a full heart, 1 s with an empty one (world time).
const EXHAUST_GRACE_MAX := 10.0
const EXHAUST_GRACE_MIN := 1.0
const EXHAUST_DAMAGE := 2.0  # health per second after the grace time


func exhaust_grace() -> float:
	return lerpf(EXHAUST_GRACE_MIN, EXHAUST_GRACE_MAX, clampf(health / 100.0, 0.0, 1.0))


func _check_strain() -> void:
	if health > 0.0 and strain >= health:
		strain = health
		exhausted = true


## Exhaustion ends once this share of the health is red again.
const EXHAUST_RECOVER := 0.3


func recover_strain(amount: float) -> void:
	strain = maxf(0.0, strain - amount)
	if strain <= health * (1.0 - EXHAUST_RECOVER):
		exhausted = false


func score() -> int:
	var total := 0
	for d in range(1, day):
		total += d * 1000
	var owned := LostItems.IDS.size() - lost.size()
	return total + money * 100 + owned * 100 + bonus


func is_lost(id: String) -> bool:
	return lost.has(id)


## Lost on the spot during the day (e.g. shoes knocked off by a car): it
## lies at `pos` in block `seg` until found.
func lose_here(id: String, seg: Vector3i, pos: Vector3) -> void:
	if not lost.has(id):
		lost.append(id)
	placements[id] = [seg, pos]


func find_item(id: String) -> void:
	lost.erase(id)
	placements.erase(id)
	dog_items.erase(id)
	carried_items.erase(id)
	high_items.erase(id)
	found_today.append(id)
	# Everything found, the phone last (so without its map and hints).
	if lost.is_empty() and id == "phone" and found_today.size() >= 2:
		unlock("NO_MAP")


## Entering the home door ends the day. Without keys the character sleeps
## in the stairwell outside the door.
## `place`: "home", "stairs", "basement" or "friend".
## Text key for "home": a friend's flat is never called home in the game
## (KEY_FRIEND instead of KEY).
func home_key(key: String) -> String:
	return key + "_FRIEND" if home_type == "friend" else key


func go_home(place: String) -> void:
	if lost.is_empty():
		bonus += 500
		unlock("CLEAN_DAY")
	if place == "home" and promille > 2.5:
		unlock("HOME_DRUNK")
	sleep_place = place
	var causes := {"home": "SLEEP_HOME", "stairs": "SLEEP_STAIRS", "basement": "SLEEP_BASEMENT", "friend": "SLEEP_FRIEND"}
	_end_day(causes[place])


## Caught by the police: the night is spent in a cell.
func go_jail() -> void:
	sleep_place = "jail"
	_end_day("SLEEP_JAIL")


## Chance that a block has police patrolling; grows day by day.
func police_chance() -> float:
	# Kärpät day: the police are out in force.
	var extra := 0.3 if special_day == "karpat" else 0.0
	return minf(0.15 + 0.05 * float(day) + extra, 0.8)


## Search radius in grid units around home; grows every day.
func search_radius() -> float:
	return 1.0 + float(day)


func new_game() -> void:
	_doses.clear()
	day = 1
	promille = PROMILLE_START
	today_max = PROMILLE_START
	yesterday_max = 2.2
	health = 100.0
	money = 0
	confiscated = -1
	soiled = false
	street_nights = 0
	_reset_day_counters()
	last_hurt = "fight"
	hunger = 20.0
	strain = 0.0
	exhausted = false
	cold = 20.0
	tired = 0.0
	caffeine = 0.0
	jitter_t = 0.0
	focus_t = 0.0
	trip_t = 0.0
	doze_t = -1.0
	clock_min = DAY_START_MIN
	busy_time = 0.0
	bonus = 0
	sleep_place = "home"
	# Every game is in one city, picked at random, until death.
	if forced_city >= 0:
		CityMap.set_city(forced_city)
		forced_city = -1
	else:
		CityMap.set_city(rng.randi() % CityMap.CITIES.size())
	home_seg = CityMap.random_segment(rng)
	while CityMap.far_side_is_sea(home_seg) or home_seg == CityMap.police_station():
		home_seg = CityMap.random_segment(rng)
	home_x = rng.randf_range(-11.0, 11.0)
	home_type = ["flat", "basement", "friend"][rng.randi() % 3]
	lock_broken = false
	lost.clear()
	_roll_weather()
	_roll_roadworks()
	_roll_booths()
	_roll_special()
	_roll_checkpoint(home_seg)
	_lose_items()
	_place_lost_items()
	_make_phone_hints()
	modal = ""
	over = false


## A short or bad sleep leaves more alcohol in the blood and heals less.
func new_day() -> void:
	_doses.clear()
	var at_sleep := promille
	_reset_day_counters()
	street_nights = street_nights + 1 if sleep_place == "street" else 0
	if street_nights >= 3:
		unlock("LAUNDRY")
	if sleep_place == "street":
		soiled = true
	elif sleep_place == "home" or sleep_place == "friend":
		soiled = false
	yesterday_max = maxf(today_max, at_sleep)
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
		"jail":
			# A hard morning: very little alcohol, a lot of hunger.
			promille = 0.3
			health = minf(100.0, health + 30.0)
			hunger = minf(100.0, hunger + 20.0)
		_:
			promille = clampf(0.5 + maxf(at_sleep - 1.0, 0.0) * 0.5, 0.3, 2.0)
			health = minf(100.0, health + 35.0)
	# Tiredness is almost gone in the morning; a bad night leaves a little.
	tired = {"home": 0.0, "friend": 5.0}.get(sleep_place, 15.0)
	caffeine = 0.0
	jitter_t = 0.0
	focus_t = 0.0
	trip_t = 0.0
	painkiller_t = 0.0
	doze_t = -1.0
	strain = 0.0
	exhausted = false
	# Morning cold depends on where the night was spent.
	cold = {"home": 10.0, "friend": 15.0, "jail": 30.0}.get(sleep_place, 50.0)
	# Sleeping always burns alcohol and makes you hungry.
	promille = maxf(minf(promille, at_sleep - SLEEP_MIN_DROP), MORNING_MIN_PROMILLE)
	today_max = promille
	var cold_night := sleep_place == "street" or sleep_place == "basement" or sleep_place == "stairs"
	hunger = minf(100.0, hunger + HUNGER_SLEEP + (8.0 if cold_night else 0.0))
	clock_min = DAY_START_MIN
	busy_time = 0.0
	_roll_weather()
	_roll_roadworks()
	_roll_booths()
	_roll_special()
	_choose_wake_place()
	_roll_checkpoint(wake_seg)
	if sleep_place == "jail":
		# Released at the police station door; without an ID card they keep
		# you longer, so the day starts later.
		wake_seg = CityMap.police_station()
		wake_pos = Vector3(CityMap.police_door_x(), 0.0, -6.2)
		if is_lost("idcard"):
			clock_min += 120.0
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


## Special day (rolled every morning from SPECIAL_FROM_DAY): "" (none),
## "karpat" (Kärpät won the championship: fans in yellow and black on
## every street, hugging and handing out drinks, quick to fight; more
## police) or "cleanup" (street cleaning: a sweeper goes round and sucks
## up everything lying on the street). Shown as a newspaper bill in the
## morning.
var special_day := ""
const SPECIAL_FROM_DAY := 2
const SPECIAL_CHANCE := {"karpat": 0.08, "cleanup": 0.08}


func _roll_special() -> void:
	special_day = ""
	if day < SPECIAL_FROM_DAY:
		return
	var r := rng.randf()
	for k in SPECIAL_CHANCE:
		if r < SPECIAL_CHANCE[k]:
			special_day = k
			return
		r -= SPECIAL_CHANCE[k]


## Breath test checkpoint: from CHECKPOINT_FROM_DAY, some mornings the
## police stop everyone passing through one block and breathalyse them.
## Over CHECKPOINT_LIMIT per mille = a night in the cell. The block shows
## on the phone map and by its blue lights.
const CHECKPOINT_FROM_DAY := 3
const CHECKPOINT_CHANCE := 0.35
const CHECKPOINT_LIMIT := 1.5
var checkpoint_segs: Array = []


func _roll_checkpoint(start: Vector3i) -> void:
	checkpoint_segs.clear()
	if day < CHECKPOINT_FROM_DAY or rng.randf() > CHECKPOINT_CHANCE:
		return
	for attempt in 50:
		var cand := CityMap.random_segment(rng)
		if cand != home_seg and cand != start and cand != CityMap.police_station() and not CityMap.closed.has(cand):
			checkpoint_segs.append(cand)
			return


## Election booths: from BOOTH_FROM_DAY a politician hands out free coffee
## at a stall in one or two blocks (rolled every morning).
const BOOTH_FROM_DAY := 8
var booth_segs: Array = []


func _roll_booths() -> void:
	booth_segs.clear()
	if day < BOOTH_FROM_DAY:
		return
	for i in rng.randi_range(1, 2):
		var cand := CityMap.random_segment(rng)
		if not CityMap.far_side_is_sea(cand) and not booth_segs.has(cand) and cand != CityMap.police_station():
			booth_segs.append(cand)


## Roadworks: from ROADWORKS_FROM_DAY on, some mornings one or two
## blocks are closed (never home, the police station or where the day
## starts). At most two, so every street stays reachable.
const ROADWORKS_FROM_DAY := 3
const ROADWORKS_CHANCE := 0.45


func _roll_roadworks() -> void:
	CityMap.closed.clear()
	if day < ROADWORKS_FROM_DAY or rng.randf() > ROADWORKS_CHANCE:
		return
	var count := 1 if rng.randf() < 0.6 else 2
	for attempt in 100:
		if CityMap.closed.size() >= count:
			break
		var cand := CityMap.random_segment(rng)
		if cand == home_seg or cand == CityMap.police_station() or cand == CityMap.start():
			continue
		CityMap.closed.append(cand)


## Every day has its own weather (and its own passing-out limit).
func _roll_weather() -> void:
	pass_out_promille = rng.randf_range(PASS_OUT_MIN, PASS_OUT_MAX)
	var r := rng.randf()
	if r < 0.4:
		weather = "sunny"
	elif r < 0.65:
		weather = "cloudy"
	elif r < 0.85:
		weather = "rain"
	else:
		weather = "snow"
	storm = day >= CityMap.storm_from_day() and rng.randf() < CityMap.storm_chance()
	if storm:
		weather = "rain" if rng.randf() < 0.6 else "cloudy"
	frost = not storm and day >= FROST_FROM_DAY and rng.randf() < FROST_CHANCE
	if frost:
		weather = "sunny"  # clear sky, low blue light


## Snow or hard frost: slippery streets.
func slippery() -> bool:
	return weather == "snow" or frost


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
	dog_items.clear()
	carried_items.clear()
	high_items.clear()
	var radius := search_radius()
	var home_c := _seg_center(home_seg)
	# Where the day starts (home on the first day).
	var start_seg := home_seg if day == 1 else wake_seg
	var start_c := _seg_center(start_seg)
	for id in lost:
		var seg := home_seg
		# The phone is always dropped close to where the day starts (about a
		# block away), so finding it first is an easy start; the rest
		# lie around home.
		var near_phone: bool = id == "phone"
		for attempt in 300:
			var cand := CityMap.random_segment(rng)
			var c := _seg_center(cand)
			var ok := false
			if near_phone:
				ok = absf(c.x - start_c.x) + absf(c.y - start_c.y) <= 1.0 and cand != home_seg
			else:
				ok = absf(c.x - home_c.x) + absf(c.y - home_c.y) <= radius and cand != home_seg
			if ok:
				seg = cand
				break
		var z := rng.randf_range(-7.0, -5.6) if rng.randf() < 0.5 else rng.randf_range(3.2, 5.0)
		placements[id] = [seg, Vector3(rng.randf_range(-14.0, 14.0), 0.0, z)]
		if id != "phone" and day >= DOG_ITEM_FROM_DAY and rng.randf() < DOG_ITEM_CHANCE:
			dog_items.append(id)
			placements[id][1].z = rng.randf_range(-4.0, 1.5)  # the dog trots about the street
		elif id != "phone" and day >= CARRIED_FROM_DAY and rng.randf() < CARRIED_CHANCE:
			carried_items.append(id)
		elif id != "phone" and day >= HIGH_FROM_DAY and rng.randf() < HIGH_CHANCE:
			high_items.append(id)


## Each morning the phone has a little battery and maybe some hints about
## where things were yesterday (messages and a photo). Not every day.
func _make_phone_hints() -> void:
	# First day: half a battery, enough to look at the map a bit.
	battery = 50.0 if day == 1 else rng.randf_range(8.0, 25.0)
	phone_msgs.clear()
	phone_photo = {}
	phone_map_hints.clear()
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
	# Map: the block where each of most lost things lies.
	for id in candidates:
		if rng.randf() < MAP_HINT_CHANCE:
			phone_map_hints.append({"id": id, "seg": placements[id][0]})


func _hint_street(seg: Vector3i) -> String:
	if rng.randf() < 0.6:
		return CityMap.street_name(seg)
	return CityMap.cross_name(seg, rng.randf() < 0.5)


## Distance between two blocks in map grid units (about blocks walked).
func seg_distance(a: Vector3i, b: Vector3i) -> float:
	var ca := _seg_center(a)
	var cb := _seg_center(b)
	return absf(ca.x - cb.x) + absf(ca.y - cb.y)


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
	delete_save()
	player_died.emit(cause)


# --- High scores --------------------------------------------------------------

## The best games on this device: [{"score", "day", "headline", "date"}],
## best first. "headline" is the translation key of the death headline.
const SCORES_FILE := "user://scores.cfg"
const SCORES_MAX := 10
var scores: Array = []


func _load_scores() -> void:
	var cf := ConfigFile.new()
	if cf.load(SCORES_FILE) != OK:
		return
	scores = cf.get_value("scores", "list", [])


## Puts this game in the list. Returns its place (1 = best), or 0 if it
## didn't make the top ten.
func record_score(headline: String) -> int:
	var d := Time.get_date_dict_from_system()
	var entry := {"score": score(), "day": day, "headline": headline,
		"date": "%d.%d.%d" % [d["day"], d["month"], d["year"]]}
	var place := scores.size()
	for i in scores.size():
		if entry["score"] > scores[i]["score"]:
			place = i
			break
	if place >= SCORES_MAX:
		return 0
	scores.insert(place, entry)
	scores.resize(mini(scores.size(), SCORES_MAX))
	var cf := ConfigFile.new()
	cf.set_value("scores", "list", scores)
	cf.save(SCORES_FILE)
	return place + 1


# --- Morning save -----------------------------------------------------------------

## The game saves itself every morning at the start of the day. Closing the
## app mid-day and opening it again goes back to that morning; there is no
## saving during the day. Death deletes the save.
const SAVE_FILE := "user://save.cfg"
## GameState variables kept in the save. New ones can be added here: an
## older save without them just keeps the default.
const SAVE_KEYS := [
	"day", "promille", "today_max", "yesterday_max", "health", "money", "hunger", "cold", "tired",
	"pass_out_promille", "clock_min", "home_seg", "home_x", "home_type", "lock_broken", "lost",
	"placements", "dog_items", "carried_items", "high_items", "sleep_place", "soiled", "bonus", "confiscated", "wake_seg", "wake_pos",
	"weather", "storm", "frost", "special_day", "booth_segs", "checkpoint_segs", "battery", "phone_msgs", "phone_photo", "phone_map_hints", "street_nights",
]


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_FILE)


## Saves the morning. `extra` holds what main.gd needs to rebuild the
## morning (where the character starts, what is in the hand).
func save_morning(extra: Dictionary) -> void:
	var cf := ConfigFile.new()
	for k in SAVE_KEYS:
		cf.set_value("state", k, get(k))
	cf.set_value("state", "city", CityMap.city)
	cf.set_value("state", "closed", CityMap.closed.duplicate())
	for k in extra:
		cf.set_value("extra", k, extra[k])
	cf.save(SAVE_FILE)


## Loads the morning save into the game state. Returns the `extra` part
## given to save_morning, or {} when there is no usable save.
func load_save() -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(SAVE_FILE) != OK or not cf.has_section("state"):
		return {}
	CityMap.set_city(cf.get_value("state", "city", 0))
	for k in SAVE_KEYS:
		if cf.has_section_key("state", k):
			set(k, cf.get_value("state", k))
	CityMap.closed = cf.get_value("state", "closed", []).duplicate()
	_doses.clear()
	_reset_day_counters()
	strain = 0.0
	exhausted = false
	caffeine = 0.0
	jitter_t = 0.0
	focus_t = 0.0
	trip_t = 0.0
	doze_t = -1.0
	busy_time = 0.0
	hit_stop_t = 0.0
	charging = false
	modal = ""
	var extra := {}
	if cf.has_section("extra"):
		for k in cf.get_section_keys("extra"):
			extra[k] = cf.get_value("extra", k)
	return extra


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_FILE)


## Debug (F11): the next new game is in this city instead of a random one.
var forced_city := -1


## Debug: end the day at once as if slept at home.
func debug_next_day() -> void:
	if over or modal != "" or doze_t >= 0.0:
		return
	sleep_place = "home"
	_end_day("SLEEP_HOME")


## Falls asleep on the spot (e.g. after a fall when drowsy).
func fall_asleep(cause: String) -> void:
	if over:
		return
	sleep_place = "street"
	_end_day(cause)


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
	# Hold to run while moving (besides double-tapping an arrow).
	_add_action("run", [KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER])
	_add_action("help", [KEY_F1], [JOY_BUTTON_BACK])
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


# --- Achievements -------------------------------------------------------------

## Achievement ids; names and descriptions are ACH_<ID> / ACH_<ID>_DESC in
## the translations. Unlocked ones are kept on the device.
const ACHIEVEMENTS := [
	"SAUSAGE_KO", "ONE_PUNCH", "PUNKS_ALL", "THROWN_OUT", "BOUNCER_KO", "COP_STOP", "THREE_TARGETS",
	"GULL_STEP", "SPLATS3", "DOG_LEAD", "FOOD_STOLEN", "DOG_CALM",
	"DOCTOR", "SOBER_30", "ELEPHANTS", "MORNING_BEER", "HOME_DRUNK", "PROMILLE_333",
	"CLEAN_DAY", "NO_MAP", "BEGGAR_PAY",
	"GRAVITY5", "BONNET_SURVIVE", "RUN_OVER_SURVIVE", "LAUNDRY", "HEADLINES10", "BACKSTAB",
	"DOG_TRADE", "THIEF_CAUGHT", "COLLEAGUE", "VIRAL", "TOURIST_GUIDE",
]
const ACH_FILE := "user://achievements.cfg"
## Seconds of game time in the mending zone / under the hangover limit.
const DOCTOR_TIME := 60.0
const SOBER_TIME := 30.0
const PROMILLE_333 := 3.33333

var achieved := {}
var headlines_seen := {}
## Per day.
var found_today: Array = []
var falls_today := 0
## Cars crashed today after a flat tyre on broken glass (the player's
## smashed bottles); from CRASHES_FOR_POLICE on, each one brings a cop.
var crashes_today := 0
const CRASHES_FOR_POLICE := 5
var drinks_today := 0
var item_hit_ids := {}
var trip_kinds := {}
var _mend_t := 0.0
var _sober_t := 0.0
## Nights on the street in a row.
var street_nights := 0


func unlock(id: String) -> void:
	if achieved.has(id) or not ACHIEVEMENTS.has(id):
		return
	achieved[id] = true
	_save_achievements()
	achievement_unlocked.emit(id)


func _load_achievements() -> void:
	var cf := ConfigFile.new()
	if cf.load(ACH_FILE) != OK:
		return
	if cf.has_section("unlocked"):
		for id in cf.get_section_keys("unlocked"):
			achieved[id] = true
	if cf.has_section("headlines"):
		for k in cf.get_section_keys("headlines"):
			headlines_seen[k] = true


func _save_achievements() -> void:
	var cf := ConfigFile.new()
	for id in achieved:
		cf.set_value("unlocked", id, true)
	for k in headlines_seen:
		cf.set_value("headlines", k, true)
	cf.save(ACH_FILE)


## A death headline was shown (ten different ones = an achievement).
func saw_headline(key: String) -> void:
	if headlines_seen.has(key):
		return
	headlines_seen[key] = true
	_save_achievements()
	if headlines_seen.size() >= 10:
		unlock("HEADLINES10")


## A thrown thing hit someone (three different people in a day).
func item_hit(who: Object) -> void:
	item_hit_ids[who.get_instance_id()] = true
	if item_hit_ids.size() >= 3:
		unlock("THREE_TARGETS")


func fell_down() -> void:
	silly_moment.emit()
	falls_today += 1
	if falls_today >= 5:
		unlock("GRAVITY5")


func saw_vision(kind: String) -> void:
	trip_kinds[kind] = true
	if trip_kinds.size() >= 4:
		unlock("ELEPHANTS")


## Timed and threshold achievements, every tick of game time.
func _check_achievements(dt: float) -> void:
	if promille > PROMILLE_333:
		unlock("PROMILLE_333")
	if mend_rate() > 0.0:
		_mend_t += dt
		if _mend_t >= DOCTOR_TIME:
			unlock("DOCTOR")
	else:
		_mend_t = 0.0
	if promille < PROMILLE_HANGOVER:
		_sober_t += dt
		if _sober_t >= SOBER_TIME:
			unlock("SOBER_30")
	else:
		_sober_t = 0.0


func _reset_day_counters() -> void:
	viral = false
	found_today.clear()
	falls_today = 0
	crashes_today = 0
	drinks_today = 0
	item_hit_ids.clear()
	_mend_t = 0.0
	_sober_t = 0.0
