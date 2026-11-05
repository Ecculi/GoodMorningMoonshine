extends Node
## Global game state: the character's condition, the clock and the
## "time only moves when the player does something" rule.

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

## Stamina ("kunto"): the red part of the heart. Exertion turns red into
## light pink from the top down; the pink level is the real health.
## When all of it is pink the character is out of breath.
const STAMINA_PUNCH := 9.0
const STAMINA_PUNCH_CHARGED := 9.0  # extra at full charge
const STAMINA_THROW := 7.0
const STAMINA_RUN := 11.0  # per second
## Resting: standing still recovers fast (in real time, even though the
## world is frozen), walking slowly. Out of breath only standing helps.
const STAMINA_REGEN_IDLE := 22.0
const STAMINA_REGEN_WALK := 7.0
const STAMINA_REGEN_DELAY := 0.8
## Out of breath ends when this share of the health is red again.
const WINDED_RECOVER := 0.3
## How long the heart may stay all pink before health starts to drop:
## 10 s with a full heart, 1 s with an empty one.
const WINDED_GRACE_MAX := 10.0
const WINDED_GRACE_MIN := 1.0
const WINDED_DAMAGE := 2.0  # health per second after the grace time
## Holding the action button while standing still runs time at half speed.
const CHARGE_TIME_SCALE := 0.5

var day := 1
var promille := PROMILLE_START
var health := 100.0
var money := 0
var clock_min := float(DAY_START_MIN)
var stamina := 100.0
var winded := false
var _rest_wait := 0.0
var _winded_time := 0.0

## Set by the player every frame.
var moving := false
var running := false
## Set by the player while the action button is held down.
var charging := false
## Actions (punching, throwing) keep the world running for a moment.
var busy_time := 0.0
## True while the world advances this frame.
var active := false
## Delta time for everything that lives in the game world (0 when frozen).
var world_dt := 0.0
## True during death and day-change screens.
var over := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	TranslationServer.set_locale("fi")


func _process(delta: float) -> void:
	if over:
		world_dt = 0.0
		active = false
		return
	busy_time = maxf(0.0, busy_time - delta)
	if moving or busy_time > 0.0:
		active = true
		world_dt = delta
	elif charging:
		active = true
		world_dt = delta * CHARGE_TIME_SCALE
	else:
		active = false
		world_dt = 0.0
	_update_stamina(delta)
	if not active:
		return

	var mult := RUN_DECAY_MULT if running else 1.0
	promille = maxf(0.0, promille - PROMILLE_DECAY * world_dt * mult)
	clock_min += float(DAY_END_MIN - DAY_START_MIN) / DAY_ACTIVE_SECONDS * world_dt
	if promille < PROMILLE_HANGOVER:
		health -= 1.5 * world_dt

	if promille <= 0.0:
		_die("HEADLINE_SOBER")
	elif health <= 0.0:
		_die("HEADLINE_BEATEN")
	elif promille > PROMILLE_PASS_OUT:
		_end_day("SLEEP_PASSOUT")
	elif clock_min >= DAY_END_MIN:
		_end_day("SLEEP_NIGHT")


func drink() -> void:
	promille += DRINK_AMOUNT


func eat() -> void:
	health = minf(100.0, health + FOOD_HEALTH)


func damage(amount: float) -> void:
	health -= amount
	stamina = minf(stamina, maxf(health, 0.0))
	if health <= 0.0 and not over:
		_die("HEADLINE_BEATEN")


## Spends stamina on an exertion (punch, throw, running).
func exert(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	_rest_wait = STAMINA_REGEN_DELAY
	if stamina <= 0.0:
		winded = true


## How long the heart may stay all pink before it starts to hurt.
func winded_grace() -> float:
	return lerpf(WINDED_GRACE_MIN, WINDED_GRACE_MAX, clampf(health / 100.0, 0.0, 1.0))


func _update_stamina(delta: float) -> void:
	stamina = minf(stamina, maxf(health, 0.0))
	if running and moving:
		exert(STAMINA_RUN * world_dt)
	_rest_wait = maxf(0.0, _rest_wait - delta)
	# Out of breath, only standing still counts as a rest.
	var resting := _rest_wait <= 0.0 and not charging and not (winded and moving)
	if resting:
		var regen := STAMINA_REGEN_WALK * world_dt if moving else STAMINA_REGEN_IDLE * delta
		stamina = minf(maxf(health, 0.0), stamina + regen)
	if winded and stamina >= health * WINDED_RECOVER:
		winded = false
	# All pink and not resting yet: after the grace time health starts to drop.
	if stamina <= 0.0 and not resting:
		_winded_time += world_dt
		if _winded_time > winded_grace():
			damage(WINDED_DAMAGE * world_dt)
	else:
		_winded_time = 0.0


func score() -> int:
	var total := 0
	for d in range(1, day):
		total += d * 1000
	return total + money * 100


func new_game() -> void:
	day = 1
	promille = PROMILLE_START
	health = 100.0
	stamina = 100.0
	winded = false
	_winded_time = 0.0
	money = 0
	clock_min = DAY_START_MIN
	busy_time = 0.0
	over = false


## Sleeping on the street is short, so more alcohol is left in the blood.
func new_day() -> void:
	var at_sleep := promille
	day += 1
	promille = clampf(0.5 + maxf(at_sleep - 1.0, 0.0) * 0.5, 0.3, 2.0)
	health = minf(100.0, health + 35.0)
	stamina = health
	winded = false
	_winded_time = 0.0
	clock_min = DAY_START_MIN
	busy_time = 0.0
	over = false


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
