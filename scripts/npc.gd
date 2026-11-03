extends Node3D
## A passer-by. Walks along the sidewalk, fights back when provoked and
## drops loot when knocked out. Lives in world time (frozen when the
## player is idle).

const PersonModel = preload("res://scripts/person_model.gd")
const Item = preload("res://scripts/item.gd")

enum S { WALK, FIGHT, STUNNED, KO }

const EDGE_X := 25.0
const CHASE_SPEED := 2.3
const WINDUP := 0.45
const ATTACK_COOLDOWN := 1.3
const HIT_DAMAGE := 9.0
const KO_TIME := 8.0
const PICKPOCKET_CHANCE := 0.6

var main
var model
var state: S = S.WALK
var dir := 1
var speed := 1.3
var hp := 3
## Some passers-by show the punch coming (arm goes up), some don't.
var telegraphs := true
var pickpocketed := false

var _windup := -1.0
var _cooldown := 0.0
var _timer := 0.0
var _knock := 0.0
var _mark: Label3D

const SHIRTS := [Color(0.75, 0.2, 0.2), Color(0.2, 0.55, 0.3), Color(0.85, 0.7, 0.2),
	Color(0.5, 0.3, 0.6), Color(0.9, 0.9, 0.88), Color(0.2, 0.2, 0.25), Color(0.85, 0.45, 0.2)]
const PANTS := [Color(0.15, 0.2, 0.35), Color(0.25, 0.25, 0.25), Color(0.4, 0.3, 0.2), Color(0.1, 0.1, 0.1)]
const SKINS := [Color(0.98, 0.84, 0.72), Color(0.87, 0.68, 0.52), Color(0.6, 0.42, 0.3), Color(0.4, 0.27, 0.2)]
const HAIRS := [Color(0.1, 0.08, 0.06), Color(0.45, 0.3, 0.15), Color(0.85, 0.75, 0.45), Color(0.7, 0.7, 0.7)]


func setup(rng: RandomNumberGenerator, x: float, z: float, d: int) -> void:
	position = Vector3(x, 0, z)
	dir = d
	speed = rng.randf_range(1.0, 1.6)
	telegraphs = rng.randf() < 0.6
	model = PersonModel.new(SHIRTS[rng.randi() % SHIRTS.size()], PANTS[rng.randi() % PANTS.size()],
		SKINS[rng.randi() % SKINS.size()], HAIRS[rng.randi() % HAIRS.size()], rng.randf_range(0.92, 1.06))
	add_child(model)
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


func _process(_delta: float) -> void:
	var dt: float = GameState.world_dt
	if dt <= 0.0:
		return
	match state:
		S.WALK:
			_walk(dt)
		S.FIGHT:
			_fight(dt)
		S.STUNNED:
			_timer -= dt
			model.animate(0.0, dt)
			if _timer <= 0.0:
				state = S.FIGHT
		S.KO:
			_timer += dt
			if _timer > KO_TIME:
				main.respawn_npc(self)
				return
	position.x += _knock * dt
	_knock = move_toward(_knock, 0.0, 12.0 * dt)
	if state != S.KO:
		model.rotation.y = 0.0 if dir > 0 else PI


func _walk(dt: float) -> void:
	position.x += dir * speed * dt
	model.animate(1.0, dt, speed / 1.3)
	if position.x > EDGE_X:
		position.x = -EDGE_X
	elif position.x < -EDGE_X:
		position.x = EDGE_X


func _fight(dt: float) -> void:
	var p = main.player
	var dx: float = p.position.x - position.x
	var dz: float = p.position.z - position.z
	if _windup < 0.0:
		dir = 1 if dx >= 0.0 else -1
	_cooldown -= dt

	if _windup >= 0.0:
		_windup += dt
		model.animate(0.0, dt)
		if _windup >= WINDUP:
			_windup = -1.0
			model.raise_arm(false)
			model.punch()
			_cooldown = ATTACK_COOLDOWN
			# The player can dodge by moving away in depth or sideways.
			if dx * dir > -0.2 and absf(dx) < 1.3 and absf(dz) < 0.5:
				p.take_hit(HIT_DAMAGE, position.x)
		return

	var target := Vector2(p.position.x - dir * 0.9, p.position.z)
	var cur := Vector2(position.x, position.z)
	if cur.distance_to(target) > 0.25:
		var nxt := cur.move_toward(target, CHASE_SPEED * dt)
		position.x = nxt.x
		position.z = nxt.y
		model.animate(1.0, dt, 1.6)
	else:
		model.animate(0.0, dt)
		if _cooldown <= 0.0:
			_windup = 0.0
			if telegraphs:
				model.raise_arm(true)


func take_hit(dmg: int, attacker: Node3D) -> void:
	if state == S.KO:
		return
	hp -= dmg
	_knock = 3.5 * signf(position.x - attacker.position.x)
	_windup = -1.0
	model.raise_arm(false)
	main.popup("*", position + Vector3(0, 1.7, 0), Color(1, 0.9, 0.4))
	if hp <= 0:
		_knock_out()
	else:
		state = S.FIGHT
		_cooldown = maxf(_cooldown, 0.5)
		_mark.visible = true


func hit_by_item(kind: int) -> void:
	if state == S.KO:
		return
	match kind:
		Item.Kind.BOTTLE:
			take_hit(1, main.player)
			if state != S.KO:
				state = S.STUNNED
				_timer = 2.0
		Item.Kind.CAN:
			state = S.FIGHT
			_mark.visible = true


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
	if main.rng.randf() < PICKPOCKET_CHANCE:
		var amount: int = main.rng.randi_range(1, 6)
		GameState.money += amount
		main.popup("+%d €" % amount, position + Vector3(0, 2.0, 0), Color(1, 0.85, 0.3))
	else:
		_mark.visible = true
		state = S.FIGHT


func _knock_out() -> void:
	state = S.KO
	_timer = 0.0
	_mark.visible = false
	model.raise_arm(false)
	model.lie_down()
	main.spawn_loot(position)
