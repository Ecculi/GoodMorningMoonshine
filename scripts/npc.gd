extends Node3D
## A person on the street. Lives in world time (frozen when the player is
## idle). `role`:
## - "civ": passer-by; fights back when provoked, drops loot when knocked out
## - "police": patrols; chases the player after a crime and arrests them
##   (main.gd counts the contact time)
## - "guard": stands by a shop; beats the player up after a crime
## - "bouncer": stands by the bar door; hit him and he runs after you like
##   the police, throws you out onto the street by the scruff of the neck,
##   then walks back to the door
## - "collector": can collector (from day 4); gets to the bins before the
##   player and picks up bottles and cans lying in the street
## - "beggar": sits by a wall with a cup; for 2 € tells where a lost thing is
## - "drunk": stands swaying with a bottle; sells a sip for 1 € or for food
## - "punk": walks in a gang of 2-3; hit one and the whole gang attacks;
##   left alone, they may offer a can of beer

const PersonModel = preload("res://scripts/person_model.gd")
const Item = preload("res://scripts/item.gd")
const Ragdoll = preload("res://scripts/ragdoll.gd")

enum S { WALK, FIGHT, STUNNED, KO, LEAVE, CHASE, RETURN }

const EDGE_X := 25.0
## Faster than the player walks (2.6), slower than running (6.4): walking
## away is no escape, running is.
const CHASE_SPEED := 3.2
const WINDUP := 0.45
const ATTACK_COOLDOWN := 1.3
const HIT_DAMAGE := 9.0
## A knocked-out passer-by lies this long (world time), then gets up and
## limps away out of the block. They never just vanish.
const KO_TIME := 10.0
## Hit by a hard thrown thing: chance to black out for a moment.
const DAZE_CHANCE := {Item.Kind.BOTTLE: 0.6, Item.Kind.ENERGY: 0.4}
## A pursuer hit by a thrown thing stops this long (seconds) and staggers.
const STAGGER_TIME := {Item.Kind.BOTTLE: 2.2, Item.Kind.ENERGY: 1.8, Item.Kind.COFFEE: 1.6,
	Item.Kind.CAN: 1.2, Item.Kind.FOOD: 0.9, Item.Kind.PILLS: 0.6}
const DAZE_TIME_MIN := 3.0
const DAZE_TIME_MAX := 5.0
var _ko_time := KO_TIME
## Knocked out this many times; at _ko_limit (2-4, per person) they stay
## out cold and don't get up any more.
var _ko_count := 0
var _ko_limit := 3
## True while out only briefly (thrown item): gets up and carries on.
var _dazed := false
const LEAVE_SPEED := 0.9
const PICKPOCKET_CHANCE := 0.6
const POLICE_SPEED := 3.4
const GUARD_SPEED := 3.0
const GUARD_DAMAGE := 12.0
## Police see only in front of their face: a cone this wide (half angle)
## and this long (main.gd shortens it when the player sneaks barefoot).
## Right next to them they notice whatever way they look.
const VISION_HALF_ANGLE := deg_to_rad(50.0)
const VISION_RANGE := 16.0
const VISION_NEAR := 1.5
## Walking police now and then turn their head to look across the street.
const GLANCE_EVERY_MIN := 3.0
const GLANCE_EVERY_MAX := 7.0
const GLANCE_TIME_MIN := 1.2
const GLANCE_TIME_MAX := 2.5
const GLANCE_TURN := deg_to_rad(70.0)
## Police give up when the player stays this far away this long.
const GIVE_UP_DIST := 14.0
const GIVE_UP_TIME := 4.0

var main
var model
var state: S = S.WALK
var dir := 1
var speed := 1.3
var hp := 3
## Some passers-by show the punch coming (arm goes up), some don't.
var telegraphs := true
var pickpocketed := false
var role := "civ"
var chase_speed := CHASE_SPEED
var hit_damage := HIT_DAMAGE
## Guards stand still at their post until there is trouble.
var stationary := false
var _far_t := 0.0
var _hug_t := 0.0
## A driver who got out of this car; goes back to it when done.
var car_ref = null
var _driver_far_t := 0.0

var _windup := -1.0
var _cooldown := 0.0
var _timer := 0.0
var _knock := 0.0
var _mark: Label3D
var _looted := false
var _ragdoll = null
## Punks: gang id (shared by the gang) and its members.
var gang_id := -1
var gang: Array = []
## Beggar / drunk: how many trades are left.
var trades_left := 1
## Bouncer: his spot by the door.
var post := Vector3.ZERO
const BOUNCER_SPEED := 3.3
const BOUNCER_THROW_DAMAGE := 10.0
var _sway_t := 0.0
## Police glancing across the street: time to the next glance, time left
## of the current one.
var _glance_wait := 0.0
var _glance_t := 0.0

const SHIRTS := [Color(0.75, 0.2, 0.2), Color(0.2, 0.55, 0.3), Color(0.85, 0.7, 0.2),
	Color(0.5, 0.3, 0.6), Color(0.9, 0.9, 0.88), Color(0.2, 0.2, 0.25), Color(0.85, 0.45, 0.2)]
const PANTS := [Color(0.15, 0.2, 0.35), Color(0.25, 0.25, 0.25), Color(0.4, 0.3, 0.2), Color(0.1, 0.1, 0.1)]
const SKINS := [Color(0.98, 0.84, 0.72), Color(0.87, 0.68, 0.52), Color(0.6, 0.42, 0.3), Color(0.4, 0.27, 0.2)]
const HAIRS := [Color(0.1, 0.08, 0.06), Color(0.45, 0.3, 0.15), Color(0.85, 0.75, 0.45), Color(0.7, 0.7, 0.7)]


func setup(rng: RandomNumberGenerator, x: float, z: float, d: int, who := "civ") -> void:
	position = Vector3(x, 0, z)
	dir = d
	role = who
	_ko_limit = rng.randi_range(2, 4)
	speed = rng.randf_range(1.0, 1.6)
	telegraphs = rng.randf() < 0.6
	var skin: Color = SKINS[rng.randi() % SKINS.size()]
	match role:
		"police":
			model = PersonModel.new(Color(0.12, 0.17, 0.32), Color(0.1, 0.12, 0.22), skin, Color(0.1, 0.12, 0.22), 1.04)
			# Cap with a light band.
			_cap(Color(0.1, 0.12, 0.22), Color(0.85, 0.85, 0.9))
			hp = 6
			speed = 1.1
			chase_speed = POLICE_SPEED
			telegraphs = true
			_glance_wait = rng.randf_range(GLANCE_EVERY_MIN, GLANCE_EVERY_MAX)
		"guard":
			model = PersonModel.new(Color(0.85, 0.9, 0.15), Color(0.08, 0.08, 0.1), skin, Color(0.1, 0.1, 0.1), 1.08)
			hp = 5
			stationary = true
			chase_speed = GUARD_SPEED
			hit_damage = GUARD_DAMAGE
		"bouncer":
			model = PersonModel.new(Color(0.08, 0.08, 0.09), Color(0.08, 0.08, 0.09), Color(0.85, 0.68, 0.55),
				Color(0.1, 0.1, 0.1), 1.12)
			hp = 6
			stationary = true
			chase_speed = BOUNCER_SPEED
			telegraphs = true
		"collector":
			model = PersonModel.new(Color(0.35, 0.4, 0.3), Color(0.3, 0.28, 0.25), skin,
				Color(0.45, 0.42, 0.38), 0.97)
			speed = 1.3
			# A big bag of cans in the hand.
			var bag := MeshInstance3D.new()
			var bgm := BoxMesh.new()
			bgm.size = Vector3(0.3, 0.42, 0.3)
			bag.mesh = bgm
			var bgmat := StandardMaterial3D.new()
			bgmat.albedo_color = Color(0.15, 0.35, 0.75)
			bag.material_override = bgmat
			bag.position = Vector3(0, -0.25, 0)
			model.hand.add_child(bag)
		"punk":
			# Black leather jacket, ripped jeans, a bright mohawk.
			model = PersonModel.new(Color(0.08, 0.08, 0.09), Color(0.25, 0.3, 0.45), skin,
				Color(0.1, 0.1, 0.1), rng.randf_range(0.95, 1.05))
			var mh: Color = [Color(1.0, 0.2, 0.6), Color(0.3, 1.0, 0.3), Color(0.2, 0.6, 1.0), Color(1.0, 0.5, 0.1)][rng.randi() % 4]
			_head_box(Vector3(-0.02, 1.9, 0), Vector3(0.24, 0.16, 0.05), mh)
			hp = 3
		"beggar":
			model = PersonModel.new(Color(0.42, 0.36, 0.3), Color(0.3, 0.27, 0.22), skin,
				Color(0.5, 0.5, 0.48), 0.98)
			_head_box(Vector3(0.0, 1.84, 0), Vector3(0.3, 0.1, 0.34), Color(0.3, 0.35, 0.5))  # beanie
			stationary = true
			model.sitting = true
			# Paper cup in front.
			var cup := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = 0.04
			cm.height = 0.12
			cup.mesh = cm
			var cmat := StandardMaterial3D.new()
			cmat.albedo_color = Color(0.92, 0.9, 0.85)
			cup.material_override = cmat
			cup.position = Vector3(1.05, 0.88, 0.0)  # on the ground (the model sits 0.82 lower)
			model.add_child(cup)
			trades_left = 1
		"drunk":
			model = PersonModel.new(Color(0.35, 0.3, 0.22), Color(0.22, 0.22, 0.25), skin.darkened(0.05),
				Color(0.4, 0.38, 0.35), 1.0)
			stationary = true
			# Bottle in hand.
			var bt := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 0.03
			bm.bottom_radius = 0.045
			bm.height = 0.26
			bt.mesh = bm
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(0.18, 0.42, 0.2)
			bt.material_override = bmat
			bt.position = Vector3(0, -0.12, 0)
			model.hand.add_child(bt)
			trades_left = 2
			_sway_t = rng.randf_range(0.0, 6.0)
		_:
			model = PersonModel.new(SHIRTS[rng.randi() % SHIRTS.size()], PANTS[rng.randi() % PANTS.size()],
				skin, HAIRS[rng.randi() % HAIRS.size()], rng.randf_range(0.92, 1.06))
	add_child(model)
	match role:
		"police", "bouncer":
			model.set_shoe_color(Color(0.05, 0.05, 0.06))
		"guard":
			model.set_shoe_color(Color(0.1, 0.1, 0.12))
		"beggar", "drunk":
			model.set_shoe_color(Color(0.3, 0.22, 0.15))
		"punk":
			model.set_shoe_color(Color(0.08, 0.08, 0.08))  # boots
		_:
			model.set_shoe_color([Color(0.12, 0.1, 0.09), Color(0.35, 0.22, 0.12), Color(0.85, 0.85, 0.85),
				Color(0.15, 0.25, 0.5), Color(0.6, 0.15, 0.15)][rng.randi() % 5])
	_mark = Label3D.new()
	_mark.text = "!"
	_mark.font_size = 96
	_mark.pixel_size = 0.006
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.no_depth_test = true
	_mark.modulate = Color(1, 0.25, 0.2)
	_mark.outline_size = 16
	_mark.position = Vector3(0, 2.25, 0)
	_mark.visible = false
	add_child(_mark)


func is_down() -> bool:
	return state == S.KO


## Police and guards (everyone else is an ordinary person in a fight).
func is_lawman() -> bool:
	return role == "police" or role == "guard"


## Beggar or street drunk: the action button trades instead of punching.
func is_trader() -> bool:
	return (role == "beggar" or role == "drunk") and state == S.WALK


func _head_box(pos: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	mi.material_override = m
	mi.position = pos
	mi.set_meta("head_extra", true)
	model.add_child(mi)


## Hit one punk and the whole gang comes for you.
func _alert_gang() -> void:
	for g in gang:
		if g != self and is_instance_valid(g) and g.state != S.KO:
			g.provoke()


## Starts a fight with the player (stands up first if sitting).
func provoke() -> void:
	if state == S.KO:
		return
	if role == "bouncer":
		# Goes after you like the police.
		stationary = false
		state = S.CHASE
		_far_t = 0.0
		_mark.modulate = Color(1, 0.25, 0.2)
		_mark.visible = true
		return
	if model.sitting:
		model.sitting = false
	stationary = false
	state = S.FIGHT
	_mark.visible = true


## The action button at a beggar or a drunk (instead of a punch).
## Returns true when it was handled as a trade.
func offer_trade(p: Node3D) -> bool:
	if not is_trader():
		return false
	var top := position + Vector3(0, 1.4 if model.sitting else 2.2, 0)
	if trades_left <= 0:
		main.popup("…", top, Color(0.85, 0.85, 0.85))
		return true
	match role:
		"beggar":
			if GameState.money < 2:
				main.popup("€?", top, Color(1, 0.85, 0.3))
				return true
			GameState.money -= 2
			trades_left -= 1
			main.popup("-2 €", top, Color(1, 0.85, 0.3))
			main.beggar_tip(position)
		"drunk":
			var paid := false
			if p.hand_item != null and p.hand_item.kind == Item.Kind.FOOD:
				p._consume_hand_item()
				paid = true
			elif GameState.money >= 1:
				GameState.money -= 1
				main.popup("-1 €", top, Color(1, 0.85, 0.3))
				paid = true
			if not paid:
				main.popup("€?", top, Color(1, 0.85, 0.3))
				return true
			trades_left -= 1
			model.punch()
			GameState.drink(0.3)
			main.popup("glug", p.position + Vector3(0, 2.1, 0), Color(1, 0.8, 0.3))
	GameState.busy_time = maxf(GameState.busy_time, 0.6)
	return true


## Can collector: heads for the nearest unsearched bin or bottle/can in
## the street, empties it into the bag, and goes on to the next.
## Returns true while busy with that (instead of just walking).
var _goal := {}
var _rummage_t := 0.0


func _collect(dt: float) -> bool:
	if _rummage_t > 0.0:
		_rummage_t -= dt
		model.animate(0.0, dt)
		return true
	if _goal.is_empty() or (_goal["type"] == "item" and not is_instance_valid(_goal["item"])):
		_goal = main.collector_target(position)
		if _goal.is_empty():
			return false
	var to := Vector2(_goal["pos"].x - position.x, _goal["pos"].z - position.z)
	if to.length() < 0.35:
		if _goal["type"] == "bin":
			main.collector_take_bin(_goal["i"])
		elif is_instance_valid(_goal["item"]) and _goal["item"].can_pickup():
			main.popup("kolin", position + Vector3(0, 1.8, 0), Color(0.85, 0.85, 0.9))
			main.remove_item(_goal["item"])
		model.punch()
		_rummage_t = 1.0
		_goal = {}
		return true
	var stp := to.normalized() * minf(speed * dt, to.length())
	position.x += stp.x
	position.z += stp.y
	dir = 1 if stp.x >= 0.0 else -1
	model.animate(1.0, dt, speed / 1.3)
	return true


func is_hostile() -> bool:
	return state == S.CHASE or state == S.FIGHT


func _cap(col: Color, band: Color) -> void:
	for spec in [[Vector3(0.02, 1.86, 0), Vector3(0.34, 0.1, 0.34), col], [Vector3(0.02, 1.81, 0), Vector3(0.35, 0.04, 0.35), band],
			[Vector3(0.2, 1.8, 0), Vector3(0.14, 0.03, 0.3), col]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec[1]
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = spec[2]
		mi.material_override = m
		mi.position = spec[0]
		# Copied onto the rag doll's head too.
		mi.set_meta("head_extra", true)
		model.add_child(mi)


## Where the face points, as a ground-plane angle (atan2(-z, x), like the
## body's rotation.y): the body's facing plus the head turn.
func view_angle() -> float:
	return model.rotation.y + model.head_yaw


## A surprise punch from behind works only on someone just walking (or
## standing) about, not fighting or chasing, with their back to `from`:
## the face points more than SURPRISE_ANGLE away from it.
const SURPRISE_ANGLE := deg_to_rad(105.0)


func is_back_turned(from: Vector3) -> bool:
	if state != S.WALK or model.sitting or _rise_t > 0.0:
		return false
	var to := Vector2(from.x - position.x, from.z - position.z)
	if to.length() < 0.01:
		return false
	var a := view_angle()
	var fwd := Vector2(cos(a), -sin(a))
	return absf(fwd.angle_to(to)) > SURPRISE_ANGLE


## Police: is `p` inside the vision cone (`reach` metres long)?
func sees(p: Vector3, reach: float) -> bool:
	if state == S.KO:
		return false
	var to := Vector2(p.x - position.x, p.z - position.z)
	var d := to.length()
	if d < VISION_NEAR:
		return true
	if d > reach:
		return false
	var a := view_angle()
	var fwd := Vector2(cos(a), -sin(a))
	return absf(fwd.angle_to(to)) <= VISION_HALF_ANGLE


## Walking police look across the street now and then (turn the head
## towards the other side for a moment). Otherwise the head turns back.
func _glance(dt: float) -> void:
	var target := 0.0
	if state == S.WALK and not stationary:
		if _glance_t > 0.0:
			_glance_t -= dt
			# The other side of the street from where they walk; the head
			# turns towards it, a bit forward.
			var side := 1.0 if position.z < -1.0 else -1.0
			var want := atan2(-side, float(dir) * 0.36)
			target = clampf(wrapf(want - model.rotation.y, -PI, PI), -GLANCE_TURN, GLANCE_TURN)
			if _glance_t <= 0.0:
				_glance_wait = randf_range(GLANCE_EVERY_MIN, GLANCE_EVERY_MAX)
		else:
			_glance_wait -= dt
			if _glance_wait <= 0.0:
				_glance_t = randf_range(GLANCE_TIME_MIN, GLANCE_TIME_MAX)
	else:
		_glance_t = 0.0
	model.turn_head(lerp_angle(model.head_yaw, target, 1.0 - exp(-6.0 * dt)))


## Police and guards react to a crime they noticed.
func notice() -> void:
	if state == S.KO or not is_lawman():
		return
	_mark.modulate = Color(0.3, 0.5, 1.0) if role == "police" else Color(1, 0.25, 0.2)
	_mark.visible = true
	_far_t = 0.0
	state = S.CHASE if role == "police" else S.FIGHT


func _process(_delta: float) -> void:
	var dt: float = GameState.world_dt
	if dt <= 0.0:
		return
	# Getting back up after a fall: no moving until standing.
	if _rise_t > 0.0:
		_rise_t -= dt
		return
	var start_pos := position
	match state:
		S.WALK:
			_walk(dt)
		S.FIGHT:
			_fight(dt)
		S.CHASE:
			_chase(dt)
		S.RETURN:
			# Back to the door, then stand there facing the street again.
			var to := Vector2(post.x - position.x, post.z - position.z)
			if to.length() < 0.1:
				position = post
				state = S.WALK
				stationary = true
				model.animate(0.0, dt)
			else:
				var stp := to.normalized() * minf(1.6 * dt, to.length())
				position.x += stp.x
				position.z += stp.y
				model.animate(1.0, dt)
		S.STUNNED:
			_timer -= dt
			model.animate(0.0, dt)
			if _timer <= 0.0:
				state = S.CHASE if role == "police" or role == "bouncer" else S.FIGHT
		S.KO:
			_timer += dt
			if _ragdoll != null:
				var t: Vector3 = _ragdoll.torso_position()
				position = Vector3(t.x, 0.0, clampf(t.z, -7.4, 5.2))
			if _ko_count >= _ko_limit:
				pass  # out cold for good: stays down
			elif _timer > _ko_time and _dazed and role != "bouncer":
				# Came round after a thrown hit: back up and angry.
				_dazed = false
				_ko_time = KO_TIME
				_end_ragdoll()
				if not is_lawman():
					state = S.FIGHT
					_mark.visible = true
				else:
					state = S.WALK
					notice()
			elif _timer > _ko_time and role == "bouncer":
				# Comes round and goes back to the door.
				_dazed = false
				_ko_time = KO_TIME
				_end_ragdoll()
				hp = 6
				_mark.visible = false
				state = S.RETURN
			elif _timer > _ko_time:
				if not is_lawman():
					# Face away from the player before rising, then limp off.
					dir = 1 if position.x >= main.player.position.x else -1
				_end_ragdoll()
				if not is_lawman():
					_get_up()
				else:
					# Police and guards get back up angry (leave the KO state
					# first, or notice() would ignore them).
					hp = 3
					state = S.WALK
					notice()
		S.LEAVE:
			if car_ref != null and is_instance_valid(car_ref):
				# A driver walks back to the car and drives off.
				var to := Vector2(car_ref.position.x - position.x, car_ref.position.z - position.z)
				dir = 1 if to.x >= 0.0 else -1
				if to.length() < 1.3:
					car_ref.driver_back()
					main.npcs.erase(self)
					queue_free()
					return
				var stp := to.normalized() * minf(1.4 * dt, to.length())
				position.x += stp.x
				position.z += stp.y
				model.animate(0.8, dt, 0.8)
				_turn(position - start_pos, dt)
				return
			# Limp away from the player towards the nearer block end.
			position.x += dir * LEAVE_SPEED * dt
			model.animate(0.6, dt, 0.6)
			if absf(position.x) > EDGE_X:
				main.respawn_npc(self)
				return
	position.x += _knock * dt
	_knock = move_toward(_knock, 0.0, 12.0 * dt)
	# Cars are solid for everyone.
	if state != S.KO:
		position = main.push_out_of_cars(position)
	if state != S.KO:
		_turn(position - start_pos - Vector3(_knock * dt, 0, 0), dt)
	if role == "police" and state != S.KO:
		_glance(dt)


## Turn smoothly towards where this person is going (any direction, like
## the player). Standing still: face along `dir` (towards the player when
## fighting).
func _turn(moved: Vector3, dt: float) -> void:
	var target: float
	if Vector2(moved.x, moved.z).length() > 0.2 * dt:
		target = atan2(-moved.z, moved.x)
	elif state == S.FIGHT or state == S.CHASE:
		var p = main.player
		target = atan2(-(p.position.z - position.z), p.position.x - position.x)
	elif model.sitting or (role == "bouncer" and stationary):
		target = -PI * 0.5  # back to the wall, facing the street
	else:
		target = 0.0 if dir > 0 else PI
	model.rotation.y = lerp_angle(model.rotation.y, target, 1.0 - exp(-10.0 * dt))


func _walk(dt: float) -> void:
	if _hug_t > 0.0:
		_hug_t -= dt
		model.animate(0.0, dt)
		if _hug_t <= 0.0:
			model.raise_arm(false)
		return
	if stationary:
		model.animate(0.0, dt)
		if role == "drunk":
			# Sways on the spot, now and then a swig.
			_sway_t += dt
			model.rotation.z = sin(_sway_t * 1.3) * 0.07 + sin(_sway_t * 0.7) * 0.04
		return
	if role == "punk":
		main.punk_meet(self)
	if role == "collector" and _collect(dt):
		return
	position.x += dir * speed * dt
	model.animate(1.0, dt, speed / 1.3)
	if position.x > EDGE_X:
		position.x = -EDGE_X
	elif position.x < -EDGE_X:
		position.x = EDGE_X


## Police: run after the player. Contact time is counted in main.gd.
func _chase(dt: float) -> void:
	var p = main.player
	var to := Vector2(p.position.x - position.x, p.position.z - position.z)
	dir = 1 if to.x >= 0.0 else -1
	if to.length() > GIVE_UP_DIST:
		_far_t += dt
		if _far_t > GIVE_UP_TIME:
			state = S.RETURN if role == "bouncer" else S.WALK
			_mark.visible = false
			return
	else:
		_far_t = 0.0
	if role == "bouncer" and to.length() < 0.8:
		# Caught: scruff of the neck and seat of the pants, out you go.
		model.raise_arm(true)
		model.punch()
		p.thrown_out(position.x, BOUNCER_THROW_DAMAGE)
		main.popup("!", position + Vector3(0, 2.4, 0), Color(1, 0.3, 0.25))
		_mark.visible = false
		state = S.RETURN
		model.raise_arm(false)
		return
	if to.length() > 0.5:
		var step := to.normalized() * minf(chase_speed * dt, to.length() - 0.45)
		position.x += step.x
		position.z += step.y
		model.animate(1.0, dt, 1.8)
	else:
		model.animate(0.0, dt)
		model.raise_arm(true)


func _fight(dt: float) -> void:
	var p = main.player
	var dx: float = p.position.x - position.x
	var dz: float = p.position.z - position.z
	# A driver gives up when the player gets away, and goes back to the car.
	if car_ref != null:
		if Vector2(dx, dz).length() > 10.0:
			_driver_far_t += dt
			if _driver_far_t > 3.0:
				state = S.LEAVE
				_mark.visible = false
				return
		else:
			_driver_far_t = 0.0
	if _windup < 0.0:
		dir = 1 if dx >= 0.0 else -1
	_cooldown -= dt

	var target := Vector2(p.position.x - dir * 0.8, p.position.z)
	var cur := Vector2(position.x, position.z)
	if _windup >= 0.0:
		# Winding up: keeps stepping after the player (a lunge), so just
		# walking on doesn't dodge it. Running or stepping aside does.
		_windup += dt
		var lunge := cur.move_toward(target, chase_speed * 0.9 * dt)
		position.x = lunge.x
		position.z = lunge.y
		model.animate(0.6, dt, 1.4)
		if _windup >= WINDUP:
			_windup = -1.0
			model.raise_arm(false)
			model.punch()
			_cooldown = ATTACK_COOLDOWN
			dx = p.position.x - position.x
			dz = p.position.z - position.z
			if dx * dir > -0.2 and absf(dx) < 1.5 and absf(dz) < 0.6:
				p.take_hit(hit_damage, position.x)
		return

	if cur.distance_to(target) > 0.25:
		var nxt := cur.move_toward(target, chase_speed * dt)
		position.x = nxt.x
		position.z = nxt.y
		model.animate(1.0, dt, 1.6)
	else:
		model.animate(0.0, dt)
	# Close enough: start the punch (no need to stand right next to them).
	if _cooldown <= 0.0 and absf(dx) < 1.4 and absf(dz) < 0.6:
		_windup = 0.0
		if telegraphs:
			model.raise_arm(true)


## surprise: punched from behind (see is_back_turned). `floor_them` (a
## fully charged surprise punch) knocks anyone but police and guards out
## at once, and they fall forward on their face.
func take_hit(dmg: int, attacker: Node3D, knock_mult := 1.0, surprise := false, floor_them := false) -> void:
	if state == S.KO:
		return
	times_hit += 1
	hp -= dmg
	if surprise and floor_them and not is_lawman():
		hp = mini(hp, 0)
	_knock = 3.5 * knock_mult * signf(position.x - attacker.position.x)
	_windup = -1.0
	model.raise_arm(false)
	main.popup("*", position + Vector3(0, 1.7, 0), Color(1, 0.9, 0.4))
	if attacker == main.player:
		main.report_crime(position, false)
	if attacker == main.player:
		_alert_gang()
	if hp <= 0:
		# Cars throw people much further than fists.
		# Knocked away from the punch.
		var away := signf(position.x - attacker.position.x)
		var push := Vector3(away * randf_range(1.3, 1.8), randf_range(1.3, 1.8), randf_range(-0.3, 0.3))
		if attacker.has_method("_check_hits"):
			push = Vector3(attacker.dir * 7.0, 3.5, randf_range(-0.8, 0.8))
			# Run over: half the time the shoes fly off.
			if not _shoeless and randf() < 0.5:
				_shoeless = true
				model.set_shoes(false)
				main.npc_shoes_fly_off(position, attacker.dir)
		if surprise:
			# Forward on the face: pushed along the way they were facing.
			var a: float = model.rotation.y
			var fwd := Vector3(cos(a), 0.0, -sin(a))
			push = fwd * randf_range(1.6, 2.2) + Vector3(0, 0.6, 0)
			_knock_out(push, fwd)
			if attacker == main.player:
				GameState.unlock("BACKSTAB")
		else:
			_knock_out(push)
	elif surprise and is_lawman():
		# Police and guards are only staggered, but for longer.
		state = S.STUNNED
		_timer = 1.6
		_mark.visible = true
	elif role == "bouncer":
		provoke()
	elif not is_lawman():
		provoke()
		_cooldown = maxf(_cooldown, 0.5)
	else:
		# Hitting police or a guard only staggers them for a moment.
		state = S.STUNNED
		_timer = 0.6
		_mark.visible = true


## Sausage hits taken (three knock you out, with an achievement).
var _sausage_hits := 0
## Times punched or hit (for "one punch").
var times_hit := 0
## Lost their shoes to a car.
var _shoeless := false


func hit_by_item(kind: int) -> void:
	if state == S.KO:
		return
	GameState.item_hit(self)
	if kind == Item.Kind.FOOD:
		_sausage_hits += 1
		if _sausage_hits >= 3:
			# Out cold from a pelting with sausages.
			_dazed = true
			_ko_time = randf_range(DAZE_TIME_MIN, DAZE_TIME_MAX)
			main.popup("*", position + Vector3(0, 1.9, 0), Color(1, 0.9, 0.4))
			_knock_out(Vector3(signf(position.x - main.player.position.x) * 1.5, 1.0, 0))
			main.report_crime(position, false)
			GameState.unlock("SAUSAGE_KO")
			return
	# Hard things can knock them out for a moment.
	if randf() < DAZE_CHANCE.get(kind, 0.0):
		if kind == Item.Kind.BOTTLE:
			hp -= 1
		if hp <= 0:
			take_hit(0, main.player)  # out for good: the usual knockout
			return
		var away := signf(position.x - main.player.position.x)
		_dazed = true
		_ko_time = randf_range(DAZE_TIME_MIN, DAZE_TIME_MAX)
		main.popup("*", position + Vector3(0, 1.9, 0), Color(1, 0.9, 0.4))
		_knock_out(Vector3(away * 2.0, 1.2, 0))
		main.report_crime(position, false)
		_alert_gang()
		return
	# Someone chasing or fighting the player: any hit stops them for a
	# moment (they stagger back), harder things for longer. A good throw
	# buys time to get away.
	if is_hostile():
		if role == "police" and state == S.CHASE and kind == Item.Kind.BOTTLE:
			GameState.unlock("COP_STOP")
		var stop: float = STAGGER_TIME.get(kind, 0.8)
		if kind == Item.Kind.BOTTLE:
			hp -= 1
			if hp <= 0:
				take_hit(0, main.player)
				return
		_knock = 3.0 * signf(position.x - main.player.position.x)
		_windup = -1.0
		model.raise_arm(false)
		state = S.STUNNED
		_timer = stop
		main.popup("*", position + Vector3(0, 1.9, 0), Color(1, 0.9, 0.4))
		_far_t = 0.0
		return
	match kind:
		Item.Kind.BOTTLE:
			take_hit(1, main.player)
			if state != S.KO:
				state = S.STUNNED
				_timer = 2.0
		_:
			# Anything else just makes them cross.
			if not is_lawman():
				provoke()
				_alert_gang()
			else:
				notice()


## A drunk hug: the passer-by stops, confused, and the player's hands
## wander into their pockets (almost always works, never starts a fight).
func hug(p: Node3D) -> void:
	pickpocketed = true
	_hug_t = 1.0
	model.raise_arm(true)
	p.model.raise_arm(true)
	p.get_tree().create_timer(1.0).timeout.connect(func(): p.model.raise_arm(false))
	GameState.busy_time = maxf(GameState.busy_time, 1.0)
	main.popup_icon(main.heart_texture(), (position + p.position) * 0.5 + Vector3(0, 2.1, 0.3))
	if main.rng.randf() < 0.9:
		var amount: int = main.rng.randi_range(1, 6)
		GameState.money += amount
		main.popup("+%d €" % amount, position + Vector3(0, 2.4, 0), Color(1, 0.85, 0.3))


func check_pickpocket(p: Node3D) -> void:
	if state != S.WALK or pickpocketed:
		return
	var dx := p.position.x - position.x
	if dx * dir >= 0.0:
		return  # player is in front, not behind
	if absf(dx) > 0.9 or absf(p.position.z - position.z) > 0.45:
		return
	pickpocketed = true
	GameState.busy_time = maxf(GameState.busy_time, 0.3)
	p.model.punch()
	# Barefoot the player sneaks quietly, so pickpocketing works better.
	var chance := 0.85 if GameState.is_lost("shoes") else PICKPOCKET_CHANCE
	# A hiccup right now gives the player away.
	if p.hic_window > 0.0:
		chance = 0.0
	if main.rng.randf() < chance:
		var amount: int = main.rng.randi_range(1, 6)
		GameState.money += amount
		main.popup("+%d €" % amount, position + Vector3(0, 2.0, 0), Color(1, 0.85, 0.3))
	elif is_lawman():
		notice()
	elif main.rng.randf() < 0.5:
		_mark.visible = true
		state = S.FIGHT
	else:
		# Caught: shouts for the police instead of fighting.
		_mark.visible = true
		main.report_crime(position, true)


func _get_up() -> void:
	state = S.LEAVE
	hp = 1
	pickpocketed = true


const RISE_TIME := 0.8
var _rise_t := 0.0


## Get up from the pose the rag doll ended in (not just pop upright).
func _end_ragdoll() -> void:
	model.visible = true
	if _ragdoll != null:
		var pose: Dictionary = _ragdoll.lying_pose(dir, model.scale.x)
		position = Vector3(pose["feet"].x, 0.0, clampf(pose["feet"].z, -7.4, 5.2))
		model.rotation.y = 0.0 if dir > 0 else PI
		model.rise_from(pose["angle"], RISE_TIME)
		_rise_t = RISE_TIME
		_ragdoll.queue_free()
		_ragdoll = null
	else:
		model.rotation.z = 0.0
		model.position.y = 0.0


## face_down: a direction to topple the rag doll over forwards (fall on
## the face); zero = the usual random tumble.
func _knock_out(push := Vector3(0, 1.5, 0), face_down := Vector3.ZERO) -> void:
	model.turn_head(0.0)  # the rag doll copies the head straight
	state = S.KO
	_timer = 0.0
	_ko_count += 1
	if role == "bouncer":
		GameState.unlock("BOUNCER_KO")
	if role == "punk" and gang.size() >= 2:
		var all_down := true
		for g in gang:
			if is_instance_valid(g) and g.state != S.KO:
				all_down = false
		if all_down:
			GameState.unlock("PUNKS_ALL")
	_mark.visible = false
	model.raise_arm(false)
	if model.sitting:
		model.sitting = false
	# Fall over as a rag doll.
	_knock = 0.0
	_ragdoll = Ragdoll.new()
	add_child(_ragdoll)
	_ragdoll.build(model, push)
	if face_down != Vector3.ZERO:
		# Tip the top of the body over in that direction.
		_ragdoll.torso.angular_velocity = Vector3.UP.cross(face_down.normalized()) * 5.0
	model.visible = false
	# Let the fall play out even if the player stands still.
	GameState.busy_time = maxf(GameState.busy_time, 1.2)
	# Loot only the first time (no farming the same person); never from
	# police or guards.
	if not _looted and not is_lawman():
		_looted = true
		if role == "punk":
			# Punks carry pills: a little bag falls out.
			main.spawn_item(Item.Kind.PILLS, Vector3(position.x + randf_range(-0.4, 0.4), 0.0,
				position.z + randf_range(0.2, 0.5)))
		else:
			main.spawn_loot(position)
