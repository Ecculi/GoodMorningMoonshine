extends Node3D
## Street animals. Live in world time (frozen when the player is idle).
##
## Seagull ("gull"): stands about pecking, hops away when someone comes
## close. If the player holds food it flies over and snatches it, unless
## the player swats it away first (punch).
##
## Dog ("dog"): one of several breeds; size, speed, temper and bite come
## from the breed, so dangerous ones can be told by their looks.
## - A kind loose dog follows the player who has food, and now and then
##   grabs it and runs off. Sometimes it sniffs out a lost thing in the
##   block and leads the player to it, barking there.
## - An angry dog attacks. A punch makes it back off; enough punches and
##   it runs away whimpering. Food on the ground (thrown) distracts it:
##   it goes to eat and calms down.

const Item = preload("res://scripts/item.gd")

enum A { IDLE, WANDER, FLY_TO, FLEE, FOLLOW, LEAD, ATTACK, EAT, BOMB }

## Gull revenge: after the player treads on a gull, the others circle
## above and drop on them for a while.
const BOMB_TIME := 12.0
const BOMB_HEIGHT := 3.2

## Breeds: size, colour (body, ears/patches), speed, how often angry,
## bite damage, hit points.
const BREEDS := [
	{"name": "chihuahua", "size": 0.45, "col": Color(0.85, 0.7, 0.5), "spot": Color(0.6, 0.45, 0.3), "speed": 3.6, "angry": 0.35, "bite": 1.5, "hp": 1},
	{"name": "terrier", "size": 0.6, "col": Color(0.9, 0.88, 0.82), "spot": Color(0.55, 0.4, 0.25), "speed": 3.4, "angry": 0.3, "bite": 3.0, "hp": 2},
	{"name": "labrador", "size": 0.85, "col": Color(0.92, 0.78, 0.5), "spot": Color(0.85, 0.7, 0.42), "speed": 3.0, "angry": 0.05, "bite": 5.0, "hp": 3},
	{"name": "husky", "size": 0.9, "col": Color(0.85, 0.86, 0.88), "spot": Color(0.35, 0.36, 0.4), "speed": 3.3, "angry": 0.15, "bite": 6.0, "hp": 3},
	{"name": "shepherd", "size": 1.0, "col": Color(0.6, 0.42, 0.22), "spot": Color(0.12, 0.1, 0.08), "speed": 3.2, "angry": 0.4, "bite": 8.0, "hp": 4},
	{"name": "rottweiler", "size": 1.05, "col": Color(0.1, 0.09, 0.08), "spot": Color(0.6, 0.35, 0.15), "speed": 2.8, "angry": 0.6, "bite": 10.0, "hp": 4},
]

var main
var kind := "gull"
var state: A = A.IDLE
var dir := 1
var angry := false
var breed := {}
var hp := 2
var carrying_food := false

var _model: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _legs: Array = []
var _tail: Node3D
var _head: Node3D
var _t := 0.0
var _timer := 0.0
var _cooldown := 0.0
var _target := Vector3.ZERO
var _follow_t := 0.0
var _led := false
var _bark_t := 0.0
var _food_item = null
var _knock := 0.0
## Angry dog: pause after a bite (seconds), sideways offset while backing
## off, and how hard the next charge is.
var _rest_t := 0.0
## Player position last frame (gull aiming).
var _last_pp := Vector3.INF
var _rest_z := 0.0
var _charge_k := 0.85
var _rng := RandomNumberGenerator.new()


func setup(k: String, rng: RandomNumberGenerator, pos: Vector3) -> void:
	kind = k
	_rng.seed = rng.randi()
	position = pos
	_target = pos
	dir = 1 if _rng.randf() < 0.5 else -1
	_model = Node3D.new()
	add_child(_model)
	if kind == "gull":
		_build_gull()
		state = A.IDLE
		_timer = _rng.randf_range(1.0, 3.0)
	else:
		breed = BREEDS[_rng.randi() % BREEDS.size()]
		angry = _rng.randf() < breed["angry"]
		hp = breed["hp"]
		_build_dog()
		state = A.WANDER


# --- Looks -------------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


func _build_gull() -> void:
	var white := Color(0.96, 0.96, 0.95)
	var grey := Color(0.62, 0.65, 0.7)
	_box(_model, Vector3(0, 0.2, 0), Vector3(0.34, 0.15, 0.15), white)
	_box(_model, Vector3(-0.2, 0.22, 0), Vector3(0.1, 0.05, 0.12), grey)  # tail
	_head = _pivot(_model, Vector3(0.18, 0.3, 0))
	_box(_head, Vector3(0, 0, 0), Vector3(0.1, 0.1, 0.09), white)
	_box(_head, Vector3(0.08, -0.01, 0), Vector3(0.07, 0.025, 0.03), Color(0.95, 0.8, 0.15))  # beak
	_box(_head, Vector3(0.03, 0.02, 0.046), Vector3(0.015, 0.015, 0.005), Color(0.05, 0.05, 0.05))
	_box(_head, Vector3(0.03, 0.02, -0.046), Vector3(0.015, 0.015, 0.005), Color(0.05, 0.05, 0.05))
	for z in [-0.08, 0.08]:
		var w := _pivot(_model, Vector3(0, 0.25, z))
		_box(w, Vector3(0, 0, signf(z) * 0.14), Vector3(0.2, 0.02, 0.28), grey)
		if z < 0:
			_wing_l = w
		else:
			_wing_r = w
	for z in [-0.04, 0.04]:
		_legs.append(_box(_model, Vector3(0, 0.07, z), Vector3(0.02, 0.14, 0.02), Color(0.9, 0.7, 0.4)))


func _build_dog() -> void:
	var s: float = breed["size"]
	var col: Color = breed["col"]
	var spot: Color = breed["spot"]
	var h := 0.32 * s  # leg length
	_box(_model, Vector3(0, h + 0.12 * s, 0), Vector3(0.62 * s, 0.24 * s, 0.24 * s), col)
	_box(_model, Vector3(0.05 * s, h + 0.2 * s, 0), Vector3(0.3 * s, 0.1 * s, 0.25 * s), spot)  # saddle
	_head = _pivot(_model, Vector3(0.33 * s, h + 0.3 * s, 0))
	_box(_head, Vector3(0.05 * s, 0, 0), Vector3(0.2 * s, 0.18 * s, 0.18 * s), col)
	_box(_head, Vector3(0.18 * s, -0.04 * s, 0), Vector3(0.12 * s, 0.09 * s, 0.11 * s), col.darkened(0.1))  # snout
	_box(_head, Vector3(0.245 * s, -0.02 * s, 0), Vector3(0.025 * s, 0.035 * s, 0.05 * s), Color(0.05, 0.05, 0.05))  # nose
	for z in [-0.06, 0.06]:
		_box(_head, Vector3(0.0, 0.11 * s, z * s), Vector3(0.05 * s, 0.09 * s, 0.05 * s), spot)  # ears
		_box(_head, Vector3(0.11 * s, 0.03 * s, z * 1.3 * s), Vector3(0.02, 0.02, 0.01), Color(0.05, 0.05, 0.05))
	for p in [Vector2(0.22, -0.08), Vector2(0.22, 0.08), Vector2(-0.22, -0.08), Vector2(-0.22, 0.08)]:
		var lg := _pivot(_model, Vector3(p.x * s, h, p.y * s))
		_box(lg, Vector3(0, -h * 0.5, 0), Vector3(0.07 * s, h, 0.07 * s), col)
		_legs.append(lg)
	_tail = _pivot(_model, Vector3(-0.31 * s, h + 0.2 * s, 0))
	_box(_tail, Vector3(-0.08 * s, 0.04 * s, 0), Vector3(0.16 * s, 0.04 * s, 0.04 * s), col)
	if angry:
		# Raised hackles: a dark ridge on the back.
		_box(_model, Vector3(-0.05 * s, h + 0.25 * s, 0), Vector3(0.4 * s, 0.04 * s, 0.06 * s), spot.darkened(0.3))


# --- Behaviour ------------------------------------------------------------------

func _process(_delta: float) -> void:
	var dt: float = GameState.world_dt
	if dt <= 0.0 or main == null:
		return
	_t += dt
	_cooldown = maxf(0.0, _cooldown - dt)
	var start := position
	if kind == "gull":
		_gull(dt)
	else:
		_dog(dt)
	position.x += _knock * dt
	_knock = move_toward(_knock, 0.0, 10.0 * dt)
	var moved := position - start
	var flat := Vector2(moved.x, moved.z)
	if flat.length() > 0.001:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-flat.y, flat.x), 1.0 - exp(-10.0 * dt))
	_animate(dt, flat.length() / dt)
	if absf(position.x) > 30.0 or position.y > 12.0:
		main.remove_animal(self)


func _player_dist() -> float:
	var p: Vector3 = main.player.position
	return Vector2(p.x - position.x, p.z - position.z).length()


func _player_has_food() -> bool:
	var h = main.player.hand_item
	return h != null and is_instance_valid(h) and h.kind == Item.Kind.FOOD


func _move_to(target: Vector3, speed: float, dt: float) -> bool:
	var to := Vector2(target.x - position.x, target.z - position.z)
	if to.length() < 0.05:
		return true
	var step := to.normalized() * minf(speed * dt, to.length())
	position.x += step.x
	position.z += step.y
	return to.length() <= speed * dt


func _gull(dt: float) -> void:
	match state:
		A.IDLE:
			position.y = move_toward(position.y, 0.0, 3.0 * dt)
			# Trodden on: a puff of feathers, off it goes, and the others
			# will get even.
			if _player_dist() < 0.35 and GameState.moving and position.y < 0.05:
				_feathers()
				state = A.FLEE
				dir = 1 if position.x >= main.player.position.x else -1
				main.gull_trampled(self)
				return
			# Food in the player's hand: here we go.
			if _player_has_food() and _player_dist() < 7.0 and _cooldown <= 0.0:
				state = A.FLY_TO
				main.popup("!", position + Vector3(0, 0.6, 0), Color(1, 1, 1))
				return
			# Someone too close: hop away a bit.
			if _player_dist() < 1.3 and main.player.running:
				_timer = 0.0
				_target = position + Vector3(signf(position.x - main.player.position.x) * 2.0, 0, 0)
			_timer -= dt
			if _timer <= 0.0:
				_timer = _rng.randf_range(1.5, 4.0)
				_target = position + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-0.4, 0.4))
				_target.z = clampf(_target.z, -7.6, 5.4)
			_move_to(_target, 0.8, dt)
		A.FLY_TO:
			if not _player_has_food():
				state = A.FLEE
				return
			var hand: Vector3 = main.player.position + Vector3(0.3 * main.player.facing, 1.3, 0.2)
			position.y = move_toward(position.y, hand.y, 3.0 * dt)
			if _move_to(hand, 5.0, dt) or (position - hand).length() < 0.45:
				# Snatched!
				main.player._consume_hand_item()
				carrying_food = true
				main.popup("!", main.player.position + Vector3(0, 2.3, 0), Color(1, 0.6, 0.5))
				state = A.FLEE
		A.FLEE:
			# Up and away, out of the picture.
			position.y += 2.2 * dt
			position.x += dir * 4.5 * dt
			position.z -= 0.6 * dt
		A.BOMB:
			# Circle above the player and let go now and then.
			_timer -= dt
			if _timer <= 0.0:
				state = A.FLEE
				return
			var p: Vector3 = main.player.position
			# How the player is moving (for aiming).
			var pv := (p - _last_pp) / dt if _last_pp != Vector3.INF else Vector3.ZERO
			_last_pp = p
			pv.y = 0.0
			# Hover close above the player, drifting a little round them.
			var ang := _t * 1.6 + float(get_instance_id() % 7)
			var over := p + pv * 0.4 + Vector3(cos(ang) * 0.5, 0, sin(ang) * 0.25)
			position.y = move_toward(position.y, BOMB_HEIGHT, 2.5 * dt)
			_move_to(over, 6.5, dt)
			if _cooldown <= 0.0 and position.y > BOMB_HEIGHT - 0.6:
				_cooldown = _rng.randf_range(1.0, 2.2)
				var dr = Dropping.new()
				dr.main = main
				main.add_child(dr)
				var from := position + Vector3(0, -0.05, 0)
				dr.global_position = from
				# Aimed: where the player's head will be when it gets there.
				var drop_h := maxf(from.y - (p.y + 1.6), 0.2)
				var fall_t := sqrt(2.0 * drop_h / 9.8)
				var aim := p + pv * fall_t
				dr.vel = Vector3((aim.x - from.x) / fall_t, 0, (aim.z - from.z) / fall_t)


## Another gull was trodden on: come and get even (start a little later).
func start_bombing(delay: float) -> void:
	if kind != "gull" or state == A.FLEE:
		return
	state = A.BOMB
	_timer = BOMB_TIME + delay
	_cooldown = delay + _rng.randf_range(0.5, 1.5)
	carrying_food = false


## A puff of feathers where the gull was.
func _feathers() -> void:
	main.popup("!", position + Vector3(0, 0.6, 0), Color(1, 1, 1))
	for i in 14:
		var f = Feather.new()
		main.add_child(f)
		f.global_position = position + Vector3(0, 0.25, 0)
		f.vel = Vector3(_rng.randf_range(-1.6, 1.6), _rng.randf_range(1.2, 2.8), _rng.randf_range(-1.0, 1.0))
		f.spin = Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6), _rng.randf_range(-6, 6))


## Hit by a thrown thing: a dog runs off whimpering (any angry dog is
## got rid of this way), a gull flies away.
func hit_by_item(_kind: int) -> void:
	if state == A.FLEE:
		return
	if kind == "gull":
		dir = 1 if position.x >= main.player.position.x else -1
		state = A.FLEE
		main.popup("*", position + Vector3(0, 0.5, 0), Color(1, 1, 1))
		return
	angry = false
	_run_off("Vink!")


## A punch at the gull: it flies off without the food.
func swat() -> void:
	if kind == "gull":
		if state != A.FLEE:
			dir = 1 if position.x >= main.player.position.x else -1
			state = A.FLEE
			main.popup("*", position + Vector3(0, 0.5, 0), Color(1, 1, 1))
		return
	# Dog: backs off; enough punches and it runs away whimpering.
	hp -= 1
	_knock = 4.0 * signf(position.x - main.player.position.x)
	_cooldown = 1.5
	if hp <= 0:
		_run_off("Vink!")
	else:
		main.popup("Grr", position + Vector3(0, 0.8, 0), Color(1, 0.6, 0.5))
		if not angry:
			angry = true  # you hit it: now it is cross
			state = A.ATTACK


func _run_off(sound: String) -> void:
	state = A.FLEE
	dir = 1 if position.x >= main.player.position.x else -1
	main.popup(sound, position + Vector3(0, 0.8, 0), Color(1, 1, 1))


func _dog(dt: float) -> void:
	var speed: float = breed["speed"]
	position.y = 0.0
	# Food lying on the ground nearby: go and eat it (calms an angry dog).
	if state != A.EAT and state != A.FLEE and not carrying_food:
		var f = main.food_on_ground_near(position, 6.0)
		if f != null:
			_food_item = f
			state = A.EAT
	match state:
		A.WANDER:
			if angry and _player_dist() < 5.0:
				state = A.ATTACK
				main.popup("Hau!", position + Vector3(0, 0.9, 0), Color(1, 0.5, 0.4))
				return
			if not angry and _player_has_food() and _player_dist() < 8.0:
				state = A.FOLLOW
				_follow_t = 0.0
				return
			if not angry and not _led and _player_dist() < 4.0 and not _player_has_food():
				var lost = main.nearest_lost_node(position)
				if lost != null and _rng.randf() < 0.35 * dt:
					_led = true
					_target = lost.position + Vector3(-0.8 * signf(lost.position.x - position.x), 0, 0)
					state = A.LEAD
					main.popup("Hau!", position + Vector3(0, 0.9, 0), Color(1, 1, 1))
					return
			position.x += dir * speed * 0.3 * dt
			if absf(position.x) > 26.0:
				dir = -dir
		A.FOLLOW:
			if not _player_has_food():
				state = A.WANDER
				return
			_follow_t += dt
			var p: Vector3 = main.player.position
			var spot := p + Vector3(-main.player.facing * 0.9, 0, 0.3)
			_move_to(spot, speed * 0.9, dt)
			# Now and then it just grabs the food and legs it.
			if _follow_t > 3.0 and _player_dist() < 1.2 and _rng.randf() < 0.25 * dt:
				main.player._consume_hand_item()
				carrying_food = true
				main.popup("!", p + Vector3(0, 2.3, 0), Color(1, 0.6, 0.5))
				_run_off("Hau!")
		A.LEAD:
			# Trot to the lost thing, then stand there barking.
			if _move_to(_target, speed * 0.6, dt):
				_bark_t -= dt
				if _bark_t <= 0.0:
					_bark_t = 1.6
					main.popup("Hau!", position + Vector3(0, 0.9, 0), Color(1, 1, 1))
				if _player_dist() < 1.5:
					state = A.WANDER
		A.ATTACK:
			if _player_dist() > 12.0:
				state = A.WANDER
				return
			var p: Vector3 = main.player.position
			var side := signf(position.x - p.x) if position.x != p.x else 1.0
			if _rest_t > 0.0:
				# After a bite: back off a couple of steps, then stand
				# barking for a moment before going again.
				_rest_t -= dt
				var back := p + Vector3(side * 2.2, 0, _rest_z)
				_move_to(back, speed * 0.5, dt)
				_bark_t -= dt
				if _bark_t <= 0.0:
					_bark_t = _rng.randf_range(0.7, 1.3)
					main.popup("Hau!", position + Vector3(0, 0.9, 0), Color(1, 0.5, 0.4))
				return
			# Charge, not always flat out and not in a dead straight line.
			var spot := p + Vector3(side * 0.6, 0, sin(_t * 2.3) * 0.4)
			_move_to(spot, speed * _charge_k, dt)
			if _player_dist() < 0.9:
				main.player.take_hit(breed["bite"], position.x)
				main.popup("Hau!", position + Vector3(0, 0.9, 0), Color(1, 0.5, 0.4))
				_rest_t = _rng.randf_range(1.5, 3.0)
				_rest_z = _rng.randf_range(-0.8, 0.8)
				_bark_t = 0.4
				_charge_k = _rng.randf_range(0.7, 1.0)
		A.EAT:
			if _food_item == null or not is_instance_valid(_food_item) or not _food_item.can_be_eaten():
				_food_item = null
				state = A.WANDER
				return
			if _move_to(_food_item.global_position, speed, dt):
				main.remove_item(_food_item)
				_food_item = null
				angry = false
				state = A.WANDER
				main.popup("♥", position + Vector3(0, 0.9, 0), Color(1, 0.5, 0.6))
		A.FLEE:
			position.x += dir * speed * 1.2 * dt


func _animate(dt: float, speed: float) -> void:
	if kind == "gull":
		var flying := position.y > 0.05
		var flap := sin(_t * 18.0) * 0.9 if flying else 0.0
		if _wing_l != null:
			_wing_l.rotation.x = -flap - (0.0 if flying else 0.05)
			_wing_r.rotation.x = flap + (0.0 if flying else 0.05)
		# Pecking now and then while standing.
		if _head != null:
			_head.rotation.z = (-0.6 if not flying and fmod(_t, 3.0) < 0.25 else 0.0)
		for l in _legs:
			l.visible = not flying
		return
	var gait := clampf(speed / 2.0, 0.0, 1.0)
	var ph := _t * (6.0 + speed * 2.0)
	for i in _legs.size():
		var sgn := 1.0 if i == 0 or i == 3 else -1.0
		_legs[i].rotation.z = sin(ph) * 0.6 * gait * sgn
	if _tail != null:
		# Wags when friendly, stiff when angry.
		_tail.rotation.y = 0.0 if angry else sin(_t * 12.0) * 0.6
		_tail.rotation.z = -0.3 if angry else 0.4
	if _head != null and state == A.LEAD and _bark_t > 1.3:
		_head.rotation.z = 0.25
	elif _head != null:
		_head.rotation.z = 0.0


## A feather from a trodden-on gull: puffs up, then sways down slowly and
## fades away on the ground.
class Feather extends MeshInstance3D:
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	var _life := 0.0
	var _phase := randf() * TAU

	## Street surface height (sidewalks are a kerb higher).
	func _ground_y(p: Vector3) -> float:
		if p.z < -5.0 or (p.z > 2.5 and p.z < 5.8):
			return 0.13
		return 0.01

	func _ready() -> void:
		var qm := QuadMesh.new()
		qm.size = Vector2(0.09, 0.035)
		mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.97, 0.97, 0.96) if randf() < 0.7 else Color(0.65, 0.68, 0.72)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material_override = m

	func _process(_d: float) -> void:
		var dt: float = GameState.world_dt
		if dt <= 0.0:
			return
		_life += dt
		var gy := _ground_y(global_position)
		if global_position.y > gy:
			# Air drag: falls slowly, swaying side to side.
			_phase += dt * 5.0
			vel.y = move_toward(vel.y, -0.45, 6.0 * dt)
			vel.x = move_toward(vel.x, sin(_phase) * 0.5, 3.0 * dt)
			vel.z = move_toward(vel.z, 0.0, 3.0 * dt)
			global_position += vel * dt
			rotation += spin * dt
			spin = spin.move_toward(Vector3(0, 0, sin(_phase) * 2.0), 4.0 * dt)
		else:
			global_position.y = gy
			rotation.x = -PI * 0.5
		if _life > 6.0:
			var m: StandardMaterial3D = material_override
			m.albedo_color.a = maxf(0.0, 1.0 - (_life - 6.0) / 2.0)
			if _life > 8.0:
				queue_free()


## A gull dropping: falls; hits the player's head (a splat on the screen)
## or lands on the street as a white spot that fades.
class Dropping extends MeshInstance3D:
	var main
	var vel := Vector3.ZERO
	var _landed := 0.0

	## Street surface height (sidewalks are a kerb higher).
	func _ground_y(p: Vector3) -> float:
		if p.z < -5.0 or (p.z > 2.5 and p.z < 5.8):
			return 0.13
		return 0.01

	func _ready() -> void:
		var sm := SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.09
		sm.radial_segments = 8
		sm.rings = 4
		mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.95, 0.95, 0.88)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material_override = m

	func _process(_d: float) -> void:
		var dt: float = GameState.world_dt
		if dt <= 0.0:
			return
		if _landed > 0.0:
			_landed += dt
			var m: StandardMaterial3D = material_override
			m.albedo_color.a = maxf(0.0, 1.0 - _landed / 8.0)
			if _landed > 8.0:
				queue_free()
			return
		vel.y -= 9.8 * dt
		global_position += vel * dt
		var p: Vector3 = main.player.global_position
		var flat := Vector2(global_position.x - p.x, global_position.z - p.z).length()
		if global_position.y < p.y + 2.0 and global_position.y > p.y + 0.8 and flat < 0.6:
			main.hud.splat()
			queue_free()
			return
		var gy := _ground_y(global_position)
		if global_position.y <= gy:
			# A flat white spot on the street.
			global_position.y = gy
			scale = Vector3(1.6, 0.15, 1.6)
			_landed = 0.001

