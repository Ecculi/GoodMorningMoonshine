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
## - "influencer": (from day 6) films the player doing anything silly
##   (fighting, falling, drinking); if the clip gets finished it goes
##   viral and the police recognise the player from further away for the
##   rest of the day. A punch or a throw stops the filming.
## - "tourist": (from day 8) asks the way with a picture of a sight in a
##   thought bubble; walk a few steps the right way from beside them to
##   answer. Right: a tip; wrong: an angry tourist.
## - "thief": pickpocket (from day 5) in a dark hoodie; sidles up, bumps
##   into the player and takes money or a pocket thing, then runs. Catch
##   him or knock him out to get it back.
## - "granny": (from day 5) slow little old lady with a handbag; annoy her
##   (hit, throw, pickpocket) and she swings the bag surprisingly hard.
## - "priest": (from day 6) black clothes and a white collar; gives a cold
##   or hungry player a bun or a coffee (once), tutting if they are drunk.
##   Hitting a priest always brings the police.
## - "canvasser": (from day 8) an extremist party's man (which party is never
##   said); follows the player about a metre behind and keeps pushing a
##   leaflet into their hand (it pushes out whatever was there). Shake him
##   off by running to another block, or hit him and he scurries off.
## - "politician": (from day 8) stands behind an election stall, smiles
##   and offers a handshake and a free coffee (once). Hit him and his two
##   aides ("aide", blue vests) go for you, and the police always come.
## - "fan": (Kärpät day) a hockey fan in yellow and black with a flag;
##   meeting the player, hugs them and often hands over a beer. Some are
##   rowdy and pick a fight; hit one and every fan in the block comes.
## - "pal": (the little task of the day) an acquaintance waiting in one
##   spot with a thought bubble of what they want (a sausage or a bottle);
##   bring it and press the button next to them for money and points.
## - "ex": (from day 10) the ex-girlfriend, always in the same outfit in
##   one game, with her new boyfriend ("exbf": big, tank top, cap the
##   wrong way round) at her side. See GameState (the ex) and _ex().
## - "beggar": sits by a wall with a cup; for 2 € tells where a lost thing is
## - "drunk": stands swaying with a bottle; sells a sip for 1 € or for food
## - "punk": walks in a gang of 2-3; hit one and the whole gang attacks;
##   left alone, they may offer a can of beer

const PersonModel = preload("res://scripts/person_model.gd")
const LostItems = preload("res://scripts/lost_items.gd")
const Item = preload("res://scripts/item.gd")
const Ragdoll = preload("res://scripts/ragdoll.gd")

enum S { WALK, FIGHT, STUNNED, KO, LEAVE, CHASE, RETURN }

const EDGE_X := 25.0
## Middle of the crossing street at either end of the block.
const SIDE_STREET_X := 19.5
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
## Knocked out this many times; at _ko_limit (2-3, per person) they stay
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
## A knocked-out police officer drops the baton this often.
const BATON_DROP_CHANCE := 0.5
## Granny: slow on her feet, but the handbag hits hard.
const GRANNY_CHASE_SPEED := 2.1
const GRANNY_DAMAGE := 16.0
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
## Who started it: this person landed a blow on the player before the
## player hit them (then hitting back is self-defence), or the player hit
## them first while they were minding their own business.
var attacked_player := false
var player_started := false
## Bouncer: going to choke the player out (saw them start a fight).
var choking := false
## Fighting style: "normal", "quick" (fast, weak punches, backs off after
## each one), "heavy" (slow, always visible wind-up, hits hard) or
## "circler" (comes at you from the side, along the depth of the street).
var style := "normal"
var _windup_time := WINDUP
var _cooldown_time := ATTACK_COOLDOWN
var _side := 1.0
## Seconds left of being wide open after a swing that missed: the
## player's punch does double damage (a counter).
var _open_t := 0.0
## Lean from a hit (radians, + = backwards); fades out.
var _flinch := 0.0
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
	_ko_limit = rng.randi_range(2, 3)
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
		"influencer":
			model = PersonModel.new(Color(0.95, 0.45, 0.7), Color(0.95, 0.95, 0.95), skin,
				[Color(0.95, 0.85, 0.55), Color(0.9, 0.5, 0.75), Color(0.2, 0.15, 0.1)][rng.randi() % 3], 1.0)
			_head_box(Vector3(0.03, 1.83, 0), Vector3(0.3, 0.06, 0.34), Color(0.1, 0.1, 0.12))  # cap
			speed = 1.2
			_phone = MeshInstance3D.new()
			var pbm := BoxMesh.new()
			pbm.size = Vector3(0.03, 0.16, 0.09)
			_phone.mesh = pbm
			var pmat := StandardMaterial3D.new()
			pmat.albedo_color = Color(0.1, 0.1, 0.12)
			pmat.emission_enabled = true
			pmat.emission = Color(0.4, 0.6, 1.0) * 0.4
			_phone.material_override = pmat
			_phone.position = Vector3(0.04, -0.06, 0)
			model.hand.add_child(_phone)
		"tourist":
			var tshirt: Color = [Color(1.0, 0.55, 0.15), Color(0.15, 0.75, 0.7), Color(0.95, 0.85, 0.2),
				Color(0.9, 0.35, 0.5)][rng.randi() % 4]
			model = PersonModel.new(tshirt, Color(0.8, 0.72, 0.5), skin, HAIRS[rng.randi() % HAIRS.size()], 1.0)
			_head_box(Vector3(0, 1.84, 0), Vector3(0.42, 0.04, 0.46), Color(0.9, 0.88, 0.75))  # sun hat brim
			_head_box(Vector3(-0.01, 1.89, 0), Vector3(0.26, 0.1, 0.3), Color(0.9, 0.88, 0.75))
			# Camera on a strap round the neck.
			var cam := MeshInstance3D.new()
			var cbm := BoxMesh.new()
			cbm.size = Vector3(0.08, 0.1, 0.16)
			cam.mesh = cbm
			var cmat := StandardMaterial3D.new()
			cmat.albedo_color = Color(0.08, 0.08, 0.09)
			cam.material_override = cmat
			cam.position = Vector3(0.18, 1.3, 0)
			model.add_child(cam)
			var lens := MeshInstance3D.new()
			var lbm := BoxMesh.new()
			lbm.size = Vector3(0.06, 0.06, 0.06)
			lens.mesh = lbm
			var lmat := StandardMaterial3D.new()
			lmat.albedo_color = Color(0.3, 0.32, 0.36)
			lens.material_override = lmat
			lens.position = Vector3(0.24, 1.3, 0)
			model.add_child(lens)
			speed = 0.9
		"priest":
			model = PersonModel.new(Color(0.07, 0.07, 0.08), Color(0.07, 0.07, 0.08), skin,
				HAIRS[rng.randi() % HAIRS.size()], rng.randf_range(0.96, 1.04))
			_head_box(Vector3(0.11, 1.56, 0), Vector3(0.05, 0.05, 0.1), Color(0.97, 0.97, 0.97))  # white collar tab
			speed = 1.0
			telegraphs = true
		"politician":
			model = PersonModel.new(Color(0.15, 0.2, 0.35), Color(0.15, 0.2, 0.35), skin,
				HAIRS[rng.randi() % HAIRS.size()], 1.0)
			_head_box(Vector3(0.11, 1.42, 0), Vector3(0.04, 0.3, 0.07), Color(0.15, 0.4, 0.8))  # tie
			_head_box(Vector3(0.11, 1.55, 0), Vector3(0.05, 0.06, 0.18), Color(0.97, 0.97, 0.97))  # collar
			stationary = true
			trades_left = 1
		"aide":
			model = PersonModel.new(Color(0.15, 0.4, 0.8), Color(0.2, 0.2, 0.25), skin,
				HAIRS[rng.randi() % HAIRS.size()], rng.randf_range(0.97, 1.05))
			stationary = true
		"fan":
			var yellow := Color(1.0, 0.8, 0.1)
			var black := Color(0.08, 0.08, 0.09)
			model = PersonModel.new(yellow if rng.randf() < 0.7 else black, black, skin,
				HAIRS[rng.randi() % HAIRS.size()], rng.randf_range(0.94, 1.06))
			_head_box(Vector3(0.0, 1.84, 0), Vector3(0.3, 0.12, 0.34), black if rng.randf() < 0.5 else yellow)  # beanie
			_head_box(Vector3(0.0, 1.5, 0), Vector3(0.3, 0.08, 0.48), yellow)  # scarf
			# A little flag on a stick: yellow and black halves.
			var pole := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.012
			pm.bottom_radius = 0.012
			pm.height = 0.7
			pole.mesh = pm
			var pmat := StandardMaterial3D.new()
			pmat.albedo_color = Color(0.6, 0.45, 0.25)
			pole.material_override = pmat
			pole.position = Vector3(0, 0.25, 0)
			model.hand.add_child(pole)
			for k in 2:
				var half := MeshInstance3D.new()
				var hm := BoxMesh.new()
				hm.size = Vector3(0.01, 0.22, 0.17)
				half.mesh = hm
				var hmat := StandardMaterial3D.new()
				hmat.albedo_color = yellow if k == 0 else black
				half.material_override = hmat
				half.position = Vector3(0, 0.49, 0.1 + k * 0.17)
				model.hand.add_child(half)
			speed = rng.randf_range(1.2, 1.7)
			rowdy = rng.randf() < 0.25
		"pal":
			model = PersonModel.new(Color(0.3, 0.5, 0.35), Color(0.25, 0.25, 0.3), skin,
				HAIRS[rng.randi() % HAIRS.size()], 1.0)
			_head_box(Vector3(0.0, 1.84, 0), Vector3(0.3, 0.1, 0.34), Color(0.75, 0.2, 0.2))  # beanie
			stationary = true
		"ex":
			var looks := [
				[Color(0.8, 0.1, 0.12), Color(0.12, 0.12, 0.15), Color(0.2, 0.12, 0.08), true],
				[Color(0.55, 0.3, 0.65), Color(0.85, 0.85, 0.88), Color(0.95, 0.85, 0.5), false],
				[Color(0.3, 0.45, 0.3), Color(0.25, 0.25, 0.35), Color(0.75, 0.3, 0.12), true],
			]
			var lk: Array = looks[GameState.ex_look % looks.size()]
			model = PersonModel.new(lk[0], lk[1], skin, lk[2], 0.95)
			_head_box(Vector3(-0.2, 1.68, 0), Vector3(0.1, 0.24, 0.1), lk[2])  # ponytail
			if lk[3]:
				_head_box(Vector3(0.16, 1.72, 0), Vector3(0.03, 0.06, 0.26), Color(0.05, 0.05, 0.06))  # sunglasses
			speed = 1.2
			telegraphs = true
		"exbf":
			model = PersonModel.new(Color(0.95, 0.95, 0.95), Color(0.2, 0.25, 0.4), skin,
				Color(0.1, 0.08, 0.06), 1.15)
			_head_box(Vector3(-0.06, 1.85, 0), Vector3(0.34, 0.08, 0.34), Color(0.1, 0.1, 0.12))  # cap
			_head_box(Vector3(-0.22, 1.82, 0), Vector3(0.12, 0.03, 0.26), Color(0.1, 0.1, 0.12))  # peak at the back
			hp = 6
			hit_damage = EXBF_DAMAGE
			chase_speed = CHASE_SPEED * 1.1
		"canvasser":
			model = PersonModel.new(Color(0.3, 0.32, 0.36), Color(0.2, 0.2, 0.22), skin,
				HAIRS[rng.randi() % HAIRS.size()], rng.randf_range(0.97, 1.04))
			_head_box(Vector3(-0.02, 1.83, 0), Vector3(0.29, 0.03, 0.33), HAIRS[0])  # short back and sides
			# A stack of leaflets in the hand.
			var stack := MeshInstance3D.new()
			var sbm := BoxMesh.new()
			sbm.size = Vector3(0.16, 0.06, 0.22)
			stack.mesh = sbm
			var smat := StandardMaterial3D.new()
			smat.albedo_color = Color(0.9, 0.9, 0.86)
			stack.material_override = smat
			stack.position = Vector3(0.04, -0.06, 0)
			model.hand.add_child(stack)
			speed = 1.2
			telegraphs = true
		"thief":
			model = PersonModel.new(Color(0.16, 0.17, 0.2), Color(0.12, 0.14, 0.22), skin,
				HAIRS[rng.randi() % HAIRS.size()], rng.randf_range(0.95, 1.02))
			_head_box(Vector3(-0.04, 1.8, 0), Vector3(0.3, 0.14, 0.36), Color(0.16, 0.17, 0.2))  # hood up
			speed = 1.35
			telegraphs = false
		"granny":
			var coat: Color = [Color(0.55, 0.42, 0.6), Color(0.45, 0.5, 0.62), Color(0.62, 0.45, 0.38),
				Color(0.4, 0.48, 0.38)][rng.randi() % 4]
			model = PersonModel.new(coat, Color(0.3, 0.28, 0.32), skin, Color(0.85, 0.85, 0.87), 0.88)
			var scarf: Color = [Color(0.85, 0.3, 0.35), Color(0.3, 0.5, 0.8), Color(0.9, 0.75, 0.3)][rng.randi() % 3]
			_head_box(Vector3(-0.02, 1.8, 0), Vector3(0.32, 0.12, 0.36), scarf)  # headscarf
			hp = 2
			speed = 0.65
			chase_speed = GRANNY_CHASE_SPEED
			hit_damage = GRANNY_DAMAGE
			telegraphs = true
			# Handbag on the arm.
			var bag := MeshInstance3D.new()
			var gbm := BoxMesh.new()
			gbm.size = Vector3(0.26, 0.2, 0.1)
			bag.mesh = gbm
			var gmat := StandardMaterial3D.new()
			gmat.albedo_color = Color(0.35, 0.18, 0.12)
			bag.material_override = gmat
			bag.position = Vector3(0, -0.16, 0)
			model.hand.add_child(bag)
			var strap := MeshInstance3D.new()
			var sbm := BoxMesh.new()
			sbm.size = Vector3(0.18, 0.02, 0.02)
			strap.mesh = sbm
			strap.material_override = gmat
			strap.position = Vector3(0, -0.03, 0)
			model.hand.add_child(strap)
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
	_pick_style(rng)
	match role:
		"police", "bouncer", "priest":
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


## Opponents fight differently: some quick and weak, some slow and hard,
## some come at you from the side.
func _pick_style(rng: RandomNumberGenerator) -> void:
	match role:
		"guard", "bouncer", "exbf":
			style = "heavy"
		"police":
			style = "normal"
		"granny":
			style = "granny"
		"punk":
			style = ["quick", "circler", "normal"][rng.randi() % 3]
		_:
			var r := rng.randf()
			style = "quick" if r < 0.3 else ("heavy" if r < 0.55 else ("circler" if r < 0.75 else "normal"))
	_side = 1.0 if rng.randf() < 0.5 else -1.0
	match style:
		"quick":
			_windup_time = 0.28
			_cooldown_time = 0.9
			hit_damage *= 0.6
		"heavy":
			_windup_time = 0.75
			_cooldown_time = 1.8
			hit_damage *= 1.6
			telegraphs = true
		"circler":
			_windup_time = 0.4
			_cooldown_time = 1.2
		"granny":
			# The bag goes up well before it comes down.
			_windup_time = 0.6
			_cooldown_time = 1.6


## Missed a swing and is off balance for a moment.
func is_open() -> bool:
	return _open_t > 0.0 and state != S.KO


func is_down() -> bool:
	return state == S.KO


## Police and guards (everyone else is an ordinary person in a fight).
func is_lawman() -> bool:
	return role == "police" or role == "guard"


## Beggar, street drunk or someone carrying a lost thing: the action
## button trades instead of punching.
func is_trader() -> bool:
	return (role == "beggar" or role == "drunk" or role == "politician" or role == "pal" or role == "ex"
		or carry_id != "") and state == S.WALK


## Carrying one of the player's lost things (a passer-by who picked it
## up): it shows in the hand, with a yellow arrow above when close.
## Get it back by paying, swapping a bottle, pickpocketing or a knockout.
const CARRY_PRICE := 5
var carry_id := ""
var _carry_model: Node3D
var _carry_arrow: Label3D


func carry_lost(id: String) -> void:
	carry_id = id
	trades_left = 1
	speed = minf(speed, 1.15)
	_carry_model = LostItems.build_mesh(id)
	_carry_model.scale = Vector3.ONE * 1.2
	_carry_model.position = Vector3(0.05, -0.1, 0)
	model.hand.add_child(_carry_model)
	_carry_arrow = Label3D.new()
	_carry_arrow.text = "▼"
	_carry_arrow.font_size = 96
	_carry_arrow.pixel_size = 0.005
	_carry_arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_carry_arrow.no_depth_test = true
	_carry_arrow.modulate = Color(1, 0.85, 0.2)
	_carry_arrow.outline_size = 18
	_carry_arrow.visible = false
	add_child(_carry_arrow)


## Lets go of the lost thing: it drops to the ground at `at`.
func _drop_carried(at: Vector3) -> void:
	if carry_id == "":
		return
	var id := carry_id
	carry_id = ""
	if _carry_model != null:
		_carry_model.queue_free()
		_carry_model = null
	if _carry_arrow != null:
		_carry_arrow.queue_free()
		_carry_arrow = null
	main.carrier_dropped(id, at)


## Keeps the hint position up to date (hot/cold, the edge arrow) and shows
## the arrow when close enough to recognise the thing.
func _update_carry() -> void:
	if not GameState.placements.has(carry_id):
		_drop_carried(position)
		return
	GameState.placements[carry_id][1] = Vector3(position.x, 0.0, position.z)
	var p: Vector3 = main.player.position
	var d := Vector2(p.x - position.x, p.z - position.z).length()
	var reach := LostItems.REVEAL_DIST_NO_GLASSES if GameState.is_lost("glasses") else LostItems.REVEAL_DIST
	_carry_arrow.visible = d < reach + 3.0
	_carry_arrow.position = Vector3(0, 2.35 + absf(sin(Time.get_ticks_msec() / 250.0)) * 0.15, 0)


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
	if role == "priest" or role == "canvasser" or role == "politician":
		# Doesn't hit back: hurries off, shocked.
		state = S.LEAVE
		dir = 1 if position.x >= main.player.position.x else -1
		main.popup("!", position + Vector3(0, 2.2, 0), Color(1, 0.9, 0.5))
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
	if role == "ex":
		_ex_talk(p, top)
		GameState.busy_time = maxf(GameState.busy_time, 0.6)
		return true
	if trades_left <= 0:
		main.popup("…", top, Color(0.85, 0.85, 0.85))
		return true
	if carry_id != "":
		# Swap a bottle for it, or buy it back.
		if p.hand_item != null and p.hand_item.kind == Item.Kind.BOTTLE:
			var b = p.hand_item
			p.hand_item = null
			main.remove_item(b)
			main.popup("♥", top, Color(1, 0.5, 0.6))
		elif GameState.money >= CARRY_PRICE:
			GameState.money -= CARRY_PRICE
			main.popup("-%d €" % CARRY_PRICE, top, Color(1, 0.85, 0.3))
		else:
			main.popup("%d €?" % CARRY_PRICE, top, Color(1, 0.85, 0.3))
			return true
		trades_left = 0
		model.punch()
		_drop_carried(Vector3(p.position.x, 0.0, p.position.z))
		GameState.busy_time = maxf(GameState.busy_time, 0.6)
		return true
	match role:
		"pal":
			var want: int = Item.Kind.FOOD if want_kind == "food" else Item.Kind.BOTTLE
			if p.hand_item == null or p.hand_item.kind != want:
				main.popup("?", top, Color(1, 1, 1))
				return true
			p._consume_hand_item()
			trades_left = 0
			_hide_bubble()
			var pay: int = main.rng.randi_range(4, 8)
			GameState.money += pay
			GameState.bonus += GameState.TASK_BONUS
			GameState.task["done"] = true
			model.punch()
			main.popup("♥", top, Color(1, 0.5, 0.6), 1.3)
			main.popup("+%d €" % pay, p.position + Vector3(0, 2.4, 0), Color(1, 0.85, 0.3))
		"politician":
			# A handshake, a big smile and a free coffee.
			model.punch()
			p.model.punch()
			trades_left -= 1
			main.popup("☺", top, Color(1, 0.9, 0.4), 1.3)
			p._pickup(main.spawn_item(Item.Kind.COFFEE, p.position))
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


## Influencer: filming the player (a couple of seconds, REC blinking).
const FILM_TIME := 2.5
var filming := false
var _film_t := 0.0
var _film_done := false
var _phone: MeshInstance3D
var _rec: Label3D


func start_filming() -> void:
	if role != "influencer" or _film_done or filming or state != S.WALK:
		return
	filming = true
	_film_t = 0.0
	model.raise_arm(true)
	if _rec == null:
		_rec = Label3D.new()
		_rec.text = "● REC"
		_rec.font_size = 64
		_rec.pixel_size = 0.006
		_rec.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_rec.no_depth_test = true
		_rec.modulate = Color(1, 0.2, 0.2)
		_rec.outline_size = 12
		_rec.position = Vector3(0, 2.25, 0)
		add_child(_rec)
	_rec.visible = true


## Stops filming. `ruined`: knocked the phone, no clip (and no more).
func _stop_filming(ruined: bool) -> void:
	if not filming:
		return
	filming = false
	_film_done = true
	model.raise_arm(false)
	if _rec != null:
		_rec.visible = false
	if ruined:
		main.popup("Hei!", position + Vector3(0, 2.2, 0), Color(1, 0.6, 0.6))
		if _phone != null:
			_phone.visible = false


## Stands still facing the player with the phone up until the clip is done;
## then it goes viral.
func _film(dt: float) -> bool:
	if not filming:
		return false
	var p = main.player
	dir = 1 if p.position.x >= position.x else -1
	model.animate(0.0, dt)
	_film_t += dt
	_rec.modulate.a = 1.0 if int(_film_t * 3.0) % 2 == 0 else 0.35
	if _film_t >= FILM_TIME:
		_stop_filming(false)
		GameState.viral = true
		GameState.unlock("VIRAL")
		main.popup("♥ 12k", position + Vector3(0, 2.4, 0), Color(1, 0.45, 0.6), 1.3)
	return true


## Tourist: "wander", "ask" (bubble up, waiting for the player to show
## the way) or "done".
var tour_mode := "wander"
var _landmark := {}
var _ask_t := 0.0
var _ask_from := Vector3.ZERO
var _ask_near := false
var _bubble: Node3D
const ASK_DIST := 3.0
## Standing this close counts as "beside" the tourist; walking this far
## from there is the answer.
const ASK_BESIDE := 1.6
const ASK_ANSWER := 3.0
const ASK_PATIENCE := 14.0


func _tourist(dt: float) -> bool:
	var p = main.player
	var d := Vector2(p.position.x - position.x, p.position.z - position.z).length()
	match tour_mode:
		"wander":
			if d < ASK_DIST and not p.is_helpless() and GameState.modal == "":
				_landmark = main.pick_landmark()
				if _landmark.is_empty():
					tour_mode = "done"
					return false
				tour_mode = "ask"
				_ask_t = 0.0
				_ask_near = false
				_show_bubble(_landmark["kind"])
				return true
		"ask":
			dir = 1 if p.position.x >= position.x else -1
			model.animate(0.0, dt)
			_ask_t += dt
			_bubble.position.y = 2.65 + sin(_ask_t * 3.0) * 0.05
			if d < ASK_BESIDE:
				_ask_near = true
				_ask_from = p.position
			elif _ask_near:
				var moved: Vector3 = p.position - _ask_from
				if Vector2(moved.x, moved.z).length() > ASK_ANSWER:
					_answered(main.points_towards(_ask_from, moved, _landmark["seg"]), moved)
					return true
			if _ask_t > ASK_PATIENCE:
				_hide_bubble()
				main.popup("?", position + Vector3(0, 2.2, 0), Color(1, 1, 1))
				tour_mode = "done"
			return true
	return false


func _answered(right: bool, moved: Vector3) -> void:
	_hide_bubble()
	tour_mode = "done"
	if right:
		var tip: int = main.rng.randi_range(2, 5)
		GameState.money += tip
		main.popup("+%d €" % tip, main.player.position + Vector3(0, 2.4, 0), Color(1, 0.85, 0.3))
		main.popup("♥", position + Vector3(0, 2.3, 0), Color(1, 0.5, 0.6), 1.3)
		GameState.unlock("TOURIST_GUIDE")
		# Off the way they were shown.
		dir = 1 if moved.x >= 0.0 else -1
	else:
		main.popup("#!?", position + Vector3(0, 2.3, 0), Color(1, 0.3, 0.25), 1.4)
		_flinch = -0.25  # stamps a foot, leaning in
		dir = -1 if moved.x >= 0.0 else 1
		speed = 1.6  # storms off


## Thought bubble with a little picture of the sight (no words).
func _show_bubble(kind: String) -> void:
	_hide_bubble()
	_bubble = Node3D.new()
	_bubble.position = Vector3(0, 2.65, 0)
	add_child(_bubble)
	var white := Color(0.98, 0.98, 0.98)
	_bub_ball(Vector3(0, 0, 0), Vector3(0.95, 0.7, 0.08), white)
	_bub_ball(Vector3(-0.32, -0.42, 0), Vector3(0.14, 0.12, 0.05), white)
	_bub_ball(Vector3(-0.42, -0.56, 0), Vector3(0.08, 0.07, 0.04), white)
	var z := 0.06
	match kind:
		"church":
			_bub_box(Vector3(0, -0.08, z), Vector3(0.22, 0.26, 0.02), Color(0.92, 0.9, 0.85))
			_bub_prism(Vector3(0, 0.13, z), Vector3(0.28, 0.16, 0.02), Color(0.3, 0.32, 0.36), 0.5)
			_bub_box(Vector3(0, 0.26, z), Vector3(0.025, 0.1, 0.02), Color(0.85, 0.7, 0.2))
			_bub_box(Vector3(0, 0.27, z), Vector3(0.07, 0.022, 0.02), Color(0.85, 0.7, 0.2))
			_bub_box(Vector3(0, -0.15, z + 0.01), Vector3(0.06, 0.1, 0.02), Color(0.4, 0.25, 0.15))
		"market":
			_bub_box(Vector3(0, -0.14, z), Vector3(0.36, 0.08, 0.02), Color(0.55, 0.35, 0.2))
			for k in 4:
				_bub_box(Vector3(-0.135 + k * 0.09, 0.08, z), Vector3(0.09, 0.08, 0.02),
					Color(0.85, 0.15, 0.15) if k % 2 == 0 else Color(0.97, 0.97, 0.97))
			for sx in [-0.16, 0.16]:
				_bub_box(Vector3(sx, -0.03, z), Vector3(0.02, 0.2, 0.02), Color(0.4, 0.3, 0.2))
			var fruit := [Color(0.95, 0.5, 0.1), Color(0.3, 0.7, 0.2), Color(0.9, 0.2, 0.2)]
			for k in 3:
				_bub_box(Vector3(-0.09 + k * 0.09, -0.07, z + 0.01), Vector3(0.05, 0.05, 0.02), fruit[k])
		"food":
			# A sausage.
			_bub_ball(Vector3(-0.12, 0.0, z), Vector3(0.1, 0.1, 0.02), Color(0.78, 0.32, 0.25))
			_bub_ball(Vector3(0.12, 0.0, z), Vector3(0.1, 0.1, 0.02), Color(0.78, 0.32, 0.25))
			_bub_box(Vector3(0, 0.0, z), Vector3(0.24, 0.1, 0.02), Color(0.78, 0.32, 0.25))
		"bottle":
			_bub_box(Vector3(0, -0.06, z), Vector3(0.1, 0.24, 0.02), Color(0.2, 0.5, 0.25))
			_bub_box(Vector3(0, 0.12, z), Vector3(0.04, 0.12, 0.02), Color(0.2, 0.5, 0.25))
		"station":
			_bub_box(Vector3(0, -0.08, z), Vector3(0.4, 0.2, 0.02), Color(0.65, 0.3, 0.22))
			_bub_box(Vector3(0, 0.12, z), Vector3(0.1, 0.2, 0.02), Color(0.65, 0.3, 0.22))
			_bub_ball(Vector3(0, 0.15, z + 0.01), Vector3(0.07, 0.07, 0.01), Color(0.97, 0.97, 0.9))
			_bub_box(Vector3(0, 0.165, z + 0.02), Vector3(0.008, 0.03, 0.01), Color(0.1, 0.1, 0.1))
			_bub_box(Vector3(0.012, 0.15, z + 0.02), Vector3(0.025, 0.008, 0.01), Color(0.1, 0.1, 0.1))
			for wx in [-0.13, -0.06, 0.06, 0.13]:
				_bub_box(Vector3(wx, -0.06, z + 0.01), Vector3(0.04, 0.07, 0.01), Color(0.95, 0.85, 0.5))
		_:
			# Harbour: a boat with a sail on the waves.
			_bub_box(Vector3(0, -0.18, z), Vector3(0.44, 0.07, 0.02), Color(0.2, 0.45, 0.8))
			_bub_box(Vector3(0, -0.11, z + 0.01), Vector3(0.26, 0.06, 0.02), Color(0.5, 0.3, 0.15))
			_bub_box(Vector3(0, 0.04, z + 0.01), Vector3(0.015, 0.26, 0.02), Color(0.4, 0.3, 0.2))
			_bub_prism(Vector3(0.09, 0.05, z + 0.01), Vector3(0.16, 0.22, 0.02), Color(0.97, 0.97, 0.97), 0.0)
	var q := Label3D.new()
	q.text = "?"
	q.font_size = 72
	q.pixel_size = 0.006
	q.no_depth_test = true
	q.modulate = Color(0.15, 0.15, 0.2)
	q.position = Vector3(0.36, 0.14, 0.1)
	_bubble.add_child(q)


func _hide_bubble() -> void:
	if _bubble != null:
		_bubble.queue_free()
		_bubble = null


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _bub_ball(pos: Vector3, scl: Vector3, c: Color) -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _flat(c)
	mi.position = pos
	mi.scale = scl
	_bubble.add_child(mi)


func _bub_box(pos: Vector3, size: Vector3, c: Color) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = _flat(c)
	mi.position = pos
	_bubble.add_child(mi)


func _bub_prism(pos: Vector3, size: Vector3, c: Color, apex: float) -> void:
	var pm := PrismMesh.new()
	pm.size = size
	pm.left_to_right = apex
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = _flat(c)
	mi.position = pos
	_bubble.add_child(mi)


## Someone carrying a lost thing stops when the player comes up from the
## front (to trade). From behind they don't notice: a pickpocket chance.
func _carrier_wait(dt: float) -> bool:
	var p = main.player
	var dx: float = p.position.x - position.x
	if dx * dir <= 0.0 or absf(dx) > 1.8 or absf(p.position.z - position.z) > 0.9 or p.is_helpless():
		return false
	model.animate(0.0, dt)
	return true


## Fan (Kärpät day): the first time the player comes close, a hug and
## often a beer; a rowdy one wants a fight instead.
var rowdy := false
var _fan_met := false


func _fan(_dt: float) -> bool:
	if _fan_met:
		return false
	var p = main.player
	var d := Vector2(p.position.x - position.x, p.position.z - position.z).length()
	if d > 1.4 or p.is_helpless() or GameState.modal != "":
		return false
	_fan_met = true
	dir = 1 if p.position.x >= position.x else -1
	var top := position + Vector3(0, 2.3, 0)
	if rowdy:
		main.popup("Häh?!", top, Color(1, 0.4, 0.3))
		provoke()
		return true
	main.popup("Kärpät!", top, Color(1, 0.85, 0.1), 1.2)
	_hug_t = 1.0
	model.raise_arm(true)
	p.model.raise_arm(true)
	p.get_tree().create_timer(1.0).timeout.connect(func(): p.model.raise_arm(false))
	main.popup_icon(main.heart_texture(), (position + p.position) * 0.5 + Vector3(0, 2.1, 0.3))
	if main.rng.randf() < 0.5:
		var it = main.spawn_item(Item.Kind.BOTTLE, p.position, 1, Item.Drink.BEER)
		if p.hand_item == null:
			p._pickup(it)
	GameState.busy_time = maxf(GameState.busy_time, 1.0)
	return true


## Pal: what they want ("food" or "bottle"), shown in a thought bubble.
var want_kind := ""


func set_want(kind: String) -> void:
	want_kind = kind
	trades_left = 1
	_show_bubble(kind)


## Canvasser: notices the player within CANVASS_NOTICE, then sticks about
## a metre behind them (a bit faster than walking: only running shakes
## him off) and every few seconds pushes a leaflet into their hand.
const CANVASS_NOTICE := 6.0
const CANVASS_SPEED := 2.9
const CANVASS_EVERY := 4.0
var _canvass_on := false
var _flyer_t := 1.0


func _canvass(dt: float) -> bool:
	var p = main.player
	var to := Vector2(p.position.x - position.x, p.position.z - position.z)
	if not _canvass_on:
		if to.length() < CANVASS_NOTICE and not p.is_helpless() and GameState.modal == "":
			_canvass_on = true
			main.popup("!", position + Vector3(0, 2.2, 0), Color(0.9, 0.9, 0.9))
		else:
			return false
	dir = 1 if to.x >= 0.0 else -1
	if to.length() > 1.1:
		var step := to.normalized() * minf(CANVASS_SPEED * dt, to.length() - 1.0)
		position.x += step.x
		position.z += step.y
		model.animate(1.0, dt, 1.6)
	else:
		model.animate(0.0, dt)
	model.raise_arm(to.length() < 1.6)
	_flyer_t -= dt
	if _flyer_t <= 0.0 and to.length() < 1.4 and not p.is_helpless():
		_flyer_t = CANVASS_EVERY
		var it = main.spawn_item(Item.Kind.FLYER, p.position)
		p._pickup(it)
		main.popup("!", p.position + Vector3(0, 2.3, 0), Color(0.9, 0.9, 0.9))
	return true


## The ex. `partner`: her new boyfriend (and his `partner` is her).
const EX_NOTICE := 8.0
const EX_WALK_UP := 2.2
const EXBF_DAMAGE := 18.0
var partner = null
var _ex_seek := false


## Without the lost thing she comes over for a chat when she spots the
## player (sneaking, only from very close); running away works. With it,
## she just walks about and waits for the player to come and ask.
func _ex(dt: float) -> bool:
	if carry_id != "" or GameState.ex_met or GameState.ex_is_mad():
		return false
	var p = main.player
	var to := Vector2(p.position.x - position.x, p.position.z - position.z)
	if not _ex_seek:
		var reach := 2.0 if p.is_sneaking() else EX_NOTICE
		if sees(p.position, reach) and not p.is_helpless() and GameState.modal == "":
			_ex_seek = true
			main.popup("Moi!", position + Vector3(0, 2.2, 0), Color(1, 0.7, 0.8))
		else:
			return false
	if to.length() > 12.0:
		_ex_seek = false  # got away
		return false
	dir = 1 if to.x >= 0.0 else -1
	var step := to.normalized() * minf(EX_WALK_UP * dt, maxf(to.length() - 0.9, 0.0))
	position.x += step.x
	position.z += step.y
	model.animate(1.0, dt, 1.5)
	if to.length() < 1.0 and not p.is_helpless():
		_ex_seek = false
		main.ex_chat(self)
	return true


## The button next to her.
func _ex_talk(p, top: Vector3) -> void:
	var h = p.hand_item
	var gift: bool = h != null and (h.kind == Item.Kind.FOOD or h.kind == Item.Kind.COFFEE or h.kind == Item.Kind.FLOWER)
	if gift:
		p._consume_hand_item()
		main.popup_icon(main.heart_texture(), top)
		GameState.ex_mad_day = -1
		GameState.ex_met = true
		if carry_id != "":
			_ex_give_back(p)
		else:
			GameState.bonus += 200
			main.popup("♥", top + Vector3(0, 0.4, 0), Color(1, 0.5, 0.6), 1.3)
		return
	if GameState.ex_is_mad() or GameState.promille > GameState.EX_SOBER:
		# Too drunk (or still cross about last night's call).
		main.ex_offended(self, GameState.promille > GameState.EX_SOBER + 1.0)
		return
	if carry_id != "":
		GameState.ex_met = true
		_ex_give_back(p)
	else:
		main.ex_chat(self)


func _ex_give_back(p) -> void:
	model.punch()
	main.popup("…okei", position + Vector3(0, 2.3, 0), Color(1, 0.8, 0.85))
	GameState.unlock("EX_BACK")
	_drop_carried(Vector3(p.position.x, 0.0, p.position.z))


## Stormed off: keeps the lost thing (gone for today) and walks away.
func ex_storm_off() -> void:
	if carry_id != "":
		GameState.placements.erase(carry_id)
		carry_id = ""
		if _carry_model != null:
			_carry_model.queue_free()
			_carry_model = null
		if _carry_arrow != null:
			_carry_arrow.queue_free()
			_carry_arrow = null
	_ex_seek = false
	stationary = false
	state = S.LEAVE
	dir = 1 if position.x >= main.player.position.x else -1
	main.popup("#!?", position + Vector3(0, 2.3, 0), Color(1, 0.3, 0.25), 1.4)


## The new boyfriend sticks right beside her (unless he is busy with the
## player).
func _exbf(dt: float) -> bool:
	if partner == null or not is_instance_valid(partner) or partner.is_down():
		return false
	var want := Vector3(partner.position.x - partner.dir * 0.7, 0.0, clampf(partner.position.z + 0.45, -7.3, 5.1))
	var to := Vector2(want.x - position.x, want.z - position.z)
	if to.length() > 0.05:
		var step := to.normalized() * minf(maxf(partner.speed, 2.6) * dt, to.length())
		position.x += step.x
		position.z += step.y
		model.animate(1.0, dt, 1.3)
	else:
		model.animate(0.0, dt)
	dir = partner.dir
	return true


## Priest: gives a cold or hungry player a bun (food) or a coffee, once.
## Drunk, they get a disapproving shake of the head, but the gift anyway.
const PRIEST_NOTICE := 2.4
const PRIEST_HUNGRY := 50.0
const PRIEST_GIVE_TIME := 1.4
var _gift_given := false
var _gift_t := 0.0


func _priest(dt: float) -> bool:
	var p = main.player
	if _gift_t > 0.0:
		_gift_t -= dt
		dir = 1 if p.position.x >= position.x else -1
		model.animate(0.0, dt)
		if _gift_t <= 0.0:
			model.raise_arm(false)
		return true
	if _gift_given:
		return false
	var d := Vector2(p.position.x - position.x, p.position.z - position.z).length()
	if d > PRIEST_NOTICE or p.is_helpless() or GameState.modal != "":
		return false
	var hungry := GameState.hunger >= PRIEST_HUNGRY
	var cold := GameState.cold >= GameState.COLD_SHIVER
	if not hungry and not cold:
		return false
	_gift_given = true
	_gift_t = PRIEST_GIVE_TIME
	model.raise_arm(true)
	var kind: int = Item.Kind.FOOD
	if cold and (not hungry or main.rng.randf() < 0.5):
		kind = Item.Kind.COFFEE
	var it = main.spawn_item(kind, p.position)
	p._pickup(it)
	var top := position + Vector3(0, 2.3, 0)
	if GameState.promille > GameState.PROMILLE_DRUNK:
		main.popup("tsk tsk", top + Vector3(0, 0.4, 0), Color(0.85, 0.85, 0.9), 0.8)
	main.popup_icon(main.heart_texture(), top)
	GameState.busy_time = maxf(GameState.busy_time, 0.6)
	return true


## Pickpocket: "prowl" (walks about, tails a passer-by, sidles up to the
## player), "flee" (got something: runs for the end of the block) or
## "done" (finished; just walks on).
var thief_mode := "prowl"
var loot_id := ""
var loot_money := 0
var _tail_target = null
const THIEF_NOTICE := 7.0
const THIEF_RUN := 4.6


func _thieve(dt: float) -> bool:
	var p = main.player
	var to := Vector2(p.position.x - position.x, p.position.z - position.z)
	match thief_mode:
		"flee":
			if loot_id != "" and GameState.placements.has(loot_id):
				GameState.placements[loot_id][1] = position
			if to.length() < 0.7 and not p.is_helpless():
				# Caught by the collar.
				main.popup("!", position + Vector3(0, 2.2, 0), Color(1, 0.85, 0.3))
				_give_back()
				GameState.unlock("THIEF_CAUGHT")
				thief_mode = "done"
				dir = 1 if position.x >= p.position.x else -1
				return false
			dir = 1 if position.x >= p.position.x else -1
			position.x += dir * THIEF_RUN * dt
			position.z = move_toward(position.z, -6.4 if position.z < -1.25 else 4.0, dt * 1.5)
			model.animate(1.0, dt, 2.2)
			if absf(position.x) > EDGE_X:
				main.thief_escaped(self)
			return true
		"prowl":
			if to.length() < THIEF_NOTICE and not p.is_helpless() and GameState.modal == "":
				# Sidle up and bump into the player in passing.
				var step := to.normalized() * minf(2.0 * dt, to.length())
				position.x += step.x
				position.z += step.y
				dir = 1 if step.x >= 0.0 else -1
				model.animate(1.0, dt, 1.3)
				if to.length() < 0.6:
					_steal_from_player()
				return true
			# Otherwise tail a passer-by (and maybe meet a colleague).
			if _tail_target == null or not is_instance_valid(_tail_target) or _tail_target.state != S.WALK:
				_tail_target = null
				for n in main.npcs:
					if n.role == "civ" and n.state == S.WALK and not n.pickpocketed \
							and absf(n.position.x - position.x) < 10.0:
						_tail_target = n
						break
			if _tail_target != null:
				var behind := Vector3(_tail_target.position.x - _tail_target.dir * 0.8, 0, _tail_target.position.z)
				var d2 := Vector2(behind.x - position.x, behind.z - position.z)
				if d2.length() > 0.1:
					var st := d2.normalized() * minf(1.8 * dt, d2.length())
					position.x += st.x
					position.z += st.y
				dir = _tail_target.dir
				model.animate(1.0, dt, 1.2)
				return true
	return false


## Bumps into the player: lifts some money or something from a pocket.
func _steal_from_player() -> void:
	var p = main.player
	thief_mode = "flee"
	attacked_player = true  # hitting him back is fair game
	p.bumped(position.x)
	var pocket: Array = []
	for id in ["wallet", "phone", "keys", "idcard", "glasses", "sunglasses"]:
		if not GameState.is_lost(id):
			pocket.append(id)
	var take_money: bool = GameState.money > 0 and (pocket.is_empty() or main.rng.randf() < 0.5)
	if take_money:
		loot_money = maxi(1, GameState.money / 2)
		GameState.money -= loot_money
		main.popup("-%d €" % loot_money, p.position + Vector3(0, 2.4, 0), Color(1, 0.5, 0.4))
	elif not pocket.is_empty():
		loot_id = pocket[main.rng.randi() % pocket.size()]
		GameState.lose_here(loot_id, main.segment, position)
		main.hud.add_today(loot_id)
		main.hud.think([loot_id])
	else:
		main.popup("?", position + Vector3(0, 2.2, 0), Color(1, 1, 1))
		thief_mode = "done"
		return
	main.popup("hehe", position + Vector3(0, 2.2, 0), Color(0.85, 0.85, 0.9))


## Caught or knocked out: the loot comes back.
func _give_back() -> void:
	if loot_money > 0:
		GameState.money += loot_money
		main.popup("+%d €" % loot_money, main.player.position + Vector3(0, 2.4, 0), Color(1, 0.85, 0.3))
		loot_money = 0
	if loot_id != "":
		var id := loot_id
		loot_id = ""
		main.drop_lost(id, position)


## The player tried the same victim this thief was tailing: two
## professionals, caught in the act together.
func meet_colleague() -> void:
	if thief_mode != "prowl":
		return
	thief_mode = "done"
	_tail_target = null
	main.popup("!?", position + Vector3(0, 2.2, 0), Color(1, 0.9, 0.5))
	main.popup("!?", main.player.position + Vector3(0, 2.4, 0), Color(1, 0.9, 0.5))
	main.popup("Kollega!", position + Vector3(0, 2.8, 0), Color(0.85, 0.85, 0.9), 0.8)
	GameState.unlock("COLLEAGUE")


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
	if carry_id != "":
		_update_carry()
	_open_t = maxf(0.0, _open_t - dt)
	if _pointing and state != S.WALK:
		_pointing = false
		model.pointing = false
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
				if role == "priest" or role == "canvasser" or role == "politician":
					state = S.LEAVE
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
	# A car in the way (parked, stopped, wrecked): go round it instead of
	# walking into it on the spot.
	if state != S.KO:
		_go_round_cars(Vector2(position.x - start_pos.x, position.z - start_pos.z), dt)
	position.x += _knock * dt
	_knock = move_toward(_knock, 0.0, 12.0 * dt)
	# Cars are solid for everyone.
	if state != S.KO:
		position = main.push_out_of_cars(position)
	if state != S.KO:
		_turn(position - start_pos - Vector3(_knock * dt, 0, 0), dt)
	if role == "police" and state != S.KO:
		_glance(dt)
	# Leaning from a hit; straightens up again.
	if _flinch != 0.0 and state != S.KO:
		_flinch = move_toward(_flinch, 0.0, dt * 1.6)
		var base: float = model.rotation.z if (role == "drunk" and state == S.WALK) else 0.0
		model.rotation.z = base + _flinch


## Turn smoothly towards where this person is going (any direction, like
## the player). Standing still: face along `dir` (towards the player when
## fighting).
func _turn(moved: Vector3, dt: float) -> void:
	var target: float
	if Vector2(moved.x, moved.z).length() > 0.2 * dt:
		target = atan2(-moved.z, moved.x)
	elif state == S.FIGHT or state == S.CHASE or _pointing:
		var p = main.player
		target = atan2(-(p.position.z - position.z), p.position.x - position.x)
	elif model.sitting or ((role == "bouncer" or role == "politician") and stationary):
		target = -PI * 0.5  # back to the wall, facing the street
	else:
		target = 0.0 if dir > 0 else PI
	model.rotation.y = lerp_angle(model.rotation.y, target, 1.0 - exp(-10.0 * dt))


## Passers-by stop and point at the player while the police are after
## them in view.
var _pointing := false


func _point_at_player(dt: float) -> bool:
	var want: bool = (role == "civ" or role == "granny" or role == "tourist" or role == "priest") and not stationary \
		and main.police_hunting_in_view()
	if want != _pointing:
		_pointing = want
		model.pointing = want
		if want and main.rng.randf() < 0.5:
			main.popup("!", position + Vector3(0, 2.1, 0), Color(1, 0.9, 0.5))
	if not want:
		return false
	# Face the player (see _turn) and stand there pointing.
	dir = 1 if main.player.position.x >= position.x else -1
	model.animate(0.0, dt)
	return true


func _walk(dt: float) -> void:
	if _point_at_player(dt):
		return
	if _hug_t > 0.0:
		_hug_t -= dt
		model.animate(0.0, dt)
		if _hug_t <= 0.0:
			model.raise_arm(false)
		return
	if stationary:
		model.animate(0.0, dt)
		if role == "politician":
			# Smiles and holds out a hand when the player comes by.
			var pd := Vector2(main.player.position.x - position.x, main.player.position.z - position.z).length()
			model.raise_arm(pd < 3.0 and trades_left > 0)
		if role == "drunk":
			# Sways on the spot, now and then a swig.
			_sway_t += dt
			model.rotation.z = sin(_sway_t * 1.3) * 0.07 + sin(_sway_t * 0.7) * 0.04
		return
	if role == "punk":
		main.punk_meet(self)
	if role == "collector" and _collect(dt):
		return
	if role == "thief" and _thieve(dt):
		return
	if role == "influencer" and _film(dt):
		return
	if role == "tourist" and _tourist(dt):
		return
	if role == "priest" and _priest(dt):
		return
	if role == "ex" and _ex(dt):
		return
	if role == "exbf" and _exbf(dt):
		return
	if carry_id != "" and _carrier_wait(dt):
		return
	if role == "canvasser" and _canvass(dt):
		return
	if role == "fan" and _fan(dt):
		return
	# The way on is fenced off: off along the side street before the fence
	# (up or down, whichever is open), or back if there is none.
	if absf(position.x) > 18.5 and position.x * dir > 0.0 and not main.end_open(dir):
		var t: int = main.shut_end_turn(dir)
		if t == 2:
			dir = -dir
		else:
			position.x = move_toward(position.x, dir * SIDE_STREET_X, speed * dt)
			position.z += t * speed * dt
			model.animate(1.0, dt, speed / 1.3)
			if position.z < -13.0 or position.z > 10.0:
				main.respawn_npc(self)
			return
	position.x += dir * speed * dt
	model.animate(1.0, dt, speed / 1.3)
	# Back to the line they were walking on after going round a car.
	if not is_nan(_lane_z) and _detour_t <= 0.0:
		position.z = move_toward(position.z, _lane_z, 0.8 * dt)
		if absf(position.z - _lane_z) < 0.02:
			_lane_z = NAN
	if position.x > EDGE_X:
		position.x = -EDGE_X
	elif position.x < -EDGE_X:
		position.x = EDGE_X


## Run round a car twice with someone after you and they lose it for a
## moment: they stop, stamp and shake their fists, then carry on. The
## laps are counted from the player's angle round the car nearest them,
## while the pursuer is close to that car too.
const CIRCLE_RAGE_LAPS := 2.0
const CIRCLE_RAGE_TIME := 2.5
const CIRCLE_NEAR := 5.0
var _circle_car = null
var _circle_angle := 0.0
var _circle_sum := 0.0
var _rage_t := 0.0
var _rage_puff := 0.0


func _car_circle_rage(dt: float) -> bool:
	if _rage_t > 0.0:
		_rage_t -= dt
		_windup = -1.0
		model.animate(0.0, dt)
		# Stamping and fist shaking.
		model.raise_arm(int(_rage_t * 5.0) % 2 == 0)
		_flinch = -0.12 * absf(sin(_rage_t * 14.0))
		_rage_puff -= dt
		if _rage_puff <= 0.0:
			_rage_puff = 0.8
			main.popup(["#@!", "%&#!", "ARGH"][randi() % 3], position + Vector3(0, 2.2, 0), Color(1, 0.3, 0.25))
		if _rage_t <= 0.0:
			model.raise_arm(false)
		return true
	var p: Vector3 = main.player.position
	var car = main.nearest_car(p, CIRCLE_NEAR)
	if car == null or Vector2(car.position.x - position.x, car.position.z - position.z).length() > CIRCLE_NEAR + 1.0:
		_circle_car = null
		_circle_sum = 0.0
		return false
	var a := atan2(p.z - car.position.z, p.x - car.position.x)
	if car != _circle_car:
		_circle_car = car
		_circle_angle = a
		_circle_sum = 0.0
		return false
	_circle_sum += wrapf(a - _circle_angle, -PI, PI)
	_circle_angle = a
	if absf(_circle_sum) >= CIRCLE_RAGE_LAPS * TAU:
		_circle_sum = 0.0
		_rage_t = CIRCLE_RAGE_TIME
		_rage_puff = 0.0
		GameState.unlock("CAR_CIRCLE")
		return true
	return false


## Going round a car: which side (+1 / -1 in z), the line walked on
## before (NAN = not detouring) and how long ago a car was last in the way.
var _detour_side := 0.0
var _detour_car = null
var _lane_z := NAN
var _detour_t := 0.0
## Clearance kept from a car's side when going round it.
const CAR_CLEARANCE := 0.55


## Moving (`moved` this frame) into a car: sidestep along the car to its
## nearer free side, keeping the same pace, so the person goes round it
## (and on past it) instead of pushing against it. The side is kept until
## the car is passed, so nobody dithers at the bumper.
func _go_round_cars(moved: Vector2, dt: float) -> void:
	_detour_t = maxf(0.0, _detour_t - dt)
	var step := moved.length()
	if step < 0.0001:
		return
	var car = main.car_in_way(position, moved)
	if car == null:
		_detour_car = null
		return
	if is_nan(_lane_z):
		_lane_z = start_lane_z(moved)
	_detour_t = 0.6
	var hw: float = main.Car.HALF_WIDTH + CAR_CLEARANCE
	if car != _detour_car:
		_detour_car = car
		_detour_side = 1.0 if position.z >= car.position.z else -1.0
		# No room on that side (wall, hedge): the other way.
		var tz: float = car.position.z + _detour_side * hw
		if tz < -7.4 or tz > 5.2:
			_detour_side = -_detour_side
	var target_z: float = clampf(car.position.z + _detour_side * hw, -7.4, 5.2)
	# Undo most of the push into the car and step sideways instead.
	position.x -= moved.x * 0.85
	position.z = move_toward(position.z, target_z, maxf(step, 1.2 * dt))


func start_lane_z(moved: Vector2) -> float:
	return position.z - moved.y


## The player hit this person. Decides once who started it: if they were
## already out to fight the player (or had hit them), it is self-defence;
## otherwise the player started it, and any bouncer close by steps in.
func _hit_by_player() -> void:
	if tour_mode == "ask":
		_hide_bubble()
		tour_mode = "done"
	if role == "bouncer":
		return  # hitting the bouncer himself: thrown out as before
	if role == "priest":
		# Hitting a priest: someone always calls the police, at once.
		main.report_crime(position, true, false, true)
	if role == "politician":
		main.politician_attacked(position)
	if role == "ex":
		main.ex_offended(self, true)
	if not player_started and not attacked_player:
		var hostile := state == S.FIGHT or state == S.CHASE or state == S.STUNNED
		player_started = not hostile
		attacked_player = hostile
	if player_started:
		main.player_started_fight(position)


## Bouncer: saw the player start a fight. Runs over and gets them in a
## chokehold (the meter is counted in main.gd).
func start_choke() -> void:
	if role != "bouncer" or state == S.KO or choking:
		return
	choking = true
	stationary = false
	state = S.CHASE
	_far_t = 0.0
	_mark.modulate = Color(0.75, 0.3, 1.0)
	_mark.visible = true


## The player has passed out (or got away): back to the door.
func end_choke() -> void:
	choking = false
	_mark.visible = false
	model.raise_arm(false)
	if state == S.CHASE:
		state = S.RETURN


## Police: run after the player. Contact time is counted in main.gd.
func _chase(dt: float) -> void:
	if _car_circle_rage(dt):
		return
	var p = main.player
	var to := Vector2(p.position.x - position.x, p.position.z - position.z)
	dir = 1 if to.x >= 0.0 else -1
	if to.length() > GIVE_UP_DIST:
		_far_t += dt
		if _far_t > GIVE_UP_TIME:
			state = S.RETURN if role == "bouncer" else S.WALK
			_mark.visible = false
			choking = false
			return
	else:
		_far_t = 0.0
	if choking:
		# Chokehold: stays right behind the player, arms up round the neck.
		if to.length() > 0.45:
			var cstep := to.normalized() * minf(chase_speed * dt, to.length() - 0.4)
			position.x += cstep.x
			position.z += cstep.y
			model.animate(1.0, dt, 1.8)
		else:
			model.animate(0.0, dt)
		model.raise_arm(to.length() < 1.0)
		return
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
	if _car_circle_rage(dt):
		return
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
	if style == "quick" and _cooldown > _cooldown_time * 0.4:
		# Backs off a step after punching.
		target.x = p.position.x - dir * 2.0
	elif style == "circler" and _windup < 0.0 and _cooldown > 0.0:
		# Circles round, out to one side, before coming in.
		target = Vector2(p.position.x - dir * 1.1, clampf(p.position.z + _side * 0.9, -7.3, 5.1))
	var cur := Vector2(position.x, position.z)
	if _windup >= 0.0:
		# Winding up: keeps stepping after the player (a lunge), so just
		# walking on doesn't dodge it. Running or stepping aside does.
		_windup += dt
		var lunge := cur.move_toward(target, chase_speed * 0.9 * dt)
		position.x = lunge.x
		position.z = lunge.y
		model.animate(0.6, dt, 1.4)
		if _windup >= _windup_time:
			_windup = -1.0
			model.raise_arm(false)
			model.punch(style == "heavy")
			_cooldown = _cooldown_time * randf_range(0.85, 1.2)
			dx = p.position.x - position.x
			dz = p.position.z - position.z
			if dx * dir > -0.2 and absf(dx) < 1.5 and absf(dz) < 0.6:
				p.take_hit(hit_damage, position.x, {"granny": "granny", "exbf": "ex"}.get(role, "fight"))
				if role == "granny":
					main.popup("KOPS!", p.position + Vector3(0, 2.3, 0), Color(1, 0.8, 0.3), 1.3)
				if not player_started:
					attacked_player = true
				main.shake(0.12 if style == "heavy" else 0.06)
			elif absf(dx) < 2.6 and absf(dz) < 2.0 and not p.is_helpless():
				# Dodged: the swing goes through air and they stumble
				# forward, wide open for a counter.
				_open_t = OPEN_TIME
				_knock = dir * 1.6
				main.popup("?", position + Vector3(0, 2.1, 0), Color(0.8, 0.9, 1.0))
			_side = -_side
		return

	if cur.distance_to(target) > 0.25:
		var nxt := cur.move_toward(target, chase_speed * dt)
		position.x = nxt.x
		position.z = nxt.y
		model.animate(1.0, dt, 1.6)
	else:
		model.animate(0.0, dt)
	# Close enough: start the punch (no need to stand right next to them).
	# Only one opponent winds up at a time; the others wait their turn.
	if _cooldown <= 0.0 and absf(dx) < 1.4 and absf(dz) < 0.6 and _open_t <= 0.0:
		if _someone_else_swinging():
			_cooldown = randf_range(0.3, 0.6)
			return
		_windup = 0.0
		if telegraphs:
			model.raise_arm(true)


## Seconds an opponent stays open after a missed swing.
const OPEN_TIME := 1.0


func _someone_else_swinging() -> bool:
	for n in main.npcs:
		if n != self and is_instance_valid(n) and n._windup >= 0.0 and n.state == S.FIGHT:
			return true
	return false


## surprise: punched from behind (see is_back_turned). `floor_them` (a
## fully charged surprise punch) knocks anyone but police and guards out
## at once, and they fall forward on their face.
func take_hit(dmg: int, attacker: Node3D, knock_mult := 1.0, surprise := false, floor_them := false) -> void:
	if state == S.KO:
		return
	if attacker == main.player:
		_hit_by_player()
		if role == "ex":
			return  # she isn't hurt; the boyfriend is
	if filming:
		_stop_filming(true)
	times_hit += 1
	hp -= dmg
	if surprise and floor_them and not is_lawman():
		hp = mini(hp, 0)
	var away := signf(position.x - attacker.position.x)
	_knock = 3.5 * knock_mult * away
	_windup = -1.0
	_open_t = 0.0
	model.raise_arm(false)
	# Lean away from the blow: backwards if hit from the front, forwards
	# if from behind; harder blows bend further.
	var facing_x: float = cos(model.rotation.y)
	var back := 1.0 if facing_x * away <= 0.0 else -1.0
	_flinch = back * clampf(0.18 + 0.1 * dmg * knock_mult, 0.2, 0.6)
	main.popup("*", position + Vector3(0, 1.7, 0), Color(1, 0.9, 0.4), 1.0 + 0.25 * dmg)
	if attacker == main.player:
		main.report_crime(position, false)
	if attacker == main.player:
		_alert_gang()
	if hp <= 0:
		# Cars throw people much further than fists.
		# Knocked away from the punch.
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
		if dmg >= 3:
			# A hard blow: reels for a moment and can't hit back.
			state = S.STUNNED
			_timer = 0.8
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
	_hit_by_player()
	if role == "ex":
		return
	if filming:
		_stop_filming(true)
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
	if carry_id != "":
		_drop_carried(Vector3(p.position.x, 0.0, p.position.z))
	elif main.rng.randf() < 0.9:
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
	for n in main.npcs:
		if n.role == "thief" and n.thief_mode == "prowl" and (n._tail_target == self \
				or Vector2(n.position.x - position.x, n.position.z - position.z).length() < 2.5):
			n.meet_colleague()
	# Sneaking up barefoot, pickpocketing works better.
	var chance := 0.85 if p.is_sneaking() else PICKPOCKET_CHANCE
	# A hiccup right now gives the player away.
	if p.hic_window > 0.0:
		chance = 0.0
	if role == "ex" or role == "exbf":
		chance *= 0.5  # they keep an eye on each other
	if main.rng.randf() < chance:
		if role == "ex" and carry_id != "":
			# Well, that's one way to get it back.
			GameState.unlock("EX_BACK")
			_drop_carried(Vector3(p.position.x, 0.0, p.position.z))
			return
		if not GameState.has_watch and role == "civ" and main.rng.randf() < GameState.WATCH_CHANCE:
			# A wristwatch: from now on it shows the day of the week.
			GameState.has_watch = true
			main.popup("⌚", position + Vector3(0, 2.0, 0), Color(1, 0.9, 0.5), 1.3)
			return
		if carry_id != "":
			# Slips the lost thing out of their hand.
			_drop_carried(Vector3(p.position.x, 0.0, p.position.z))
			return
		var amount: int = main.rng.randi_range(1, 6)
		GameState.money += amount
		main.popup("+%d €" % amount, position + Vector3(0, 2.0, 0), Color(1, 0.85, 0.3))
	elif is_lawman():
		notice()
	elif role == "granny" or main.rng.randf() < 0.5:
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
	if role == "exbf" and partner != null and is_instance_valid(partner):
		main.ex_offended(partner, false)  # her man flattened: she's off
	_drop_carried(Vector3(position.x + 0.4 * float(dir), 0.0, position.z))
	if role == "thief" and (loot_id != "" or loot_money > 0):
		_give_back()
		GameState.unlock("THIEF_CAUGHT")
	if role == "thief":
		thief_mode = "done"
	_flinch = 0.0
	_open_t = 0.0
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
	# A knocked-out police officer may drop the baton (the first time).
	if role == "police" and not _looted:
		_looted = true
		if randf() < BATON_DROP_CHANCE:
			var from := position + Vector3(0, 0.9, 0)
			var b = main.spawn_item(Item.Kind.BATON, from)
			b.launch(from, Vector3(randf_range(-1.5, 1.5), randf_range(1.5, 2.5), randf_range(-0.8, 0.8)))
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
