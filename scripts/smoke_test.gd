extends Node
## Automatic smoke test for CI: run the game with `-- --smoke`. It jumps to
## a late day, switches the special days and features on one after another,
## spawns every kind of character next to the player and walks, punches
## and throws about, so that script errors in code that a fresh day-1 start
## never reaches show up in the log. It only drives the game; it checks
## nothing itself (the workflow fails on any SCRIPT ERROR in the log).

const CityMap = preload("res://scripts/city_map.gd")
const Item = preload("res://scripts/item.gd")

const ROLES := ["civ", "police", "guard", "priest", "canvasser", "fan", "politician", "aide", "thief",
	"granny", "tourist", "influencer", "collector", "beggar", "drunk", "punk"]

var main
var _frame := 0
var _held := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	# The steps only count while the game runs (or a card waits for a
	# button), so the day card and the death photo don't eat them.
	var m: String = main.hud.mode
	if GameState.over and m != "dead" and m != "scores" and m != "start":
		_release()
		return
	_frame += 1
	var f := _frame
	if f == 20:
		print("SMOKE: day 10")
		GameState.day = 9
		GameState.debug_next_day()
		return
	match f:
		200:
			print("SMOKE: characters")
			_spawn_everyone()
			GameState.promille = 2.0
			GameState.hunger = 80.0
			GameState.cold = 80.0
			GameState.tired = 80.0
		260:
			_give(Item.Kind.BAG)
		300:
			_give(Item.Kind.BOTTLE)
		330:
			_give(Item.Kind.FOOD)
		360:
			print("SMOKE: frost and Kärpät")
			GameState.frost = true
			GameState.special_day = "karpat"
			main._enter_block(main.segment, main.player.position, 1)
			_spawn_everyone()
		460:
			print("SMOKE: cleanup day")
			GameState.special_day = "cleanup"
			main._enter_block(main.segment, Vector3(-10, 0, 3.5), 1)
			main._sweeper_timer = 0.0
			for i in 6:
				main.spawn_item(Item.Kind.CAN, Vector3(-8.0 + i * 3.0, 0, 3.5))
		560:
			print("SMOKE: booth, checkpoint, task, high and carried things")
			var seg: Vector3i = main.segment
			GameState.booth_segs = [seg]
			GameState.checkpoint_segs = [seg]
			GameState.task = {"want": "food", "seg": seg, "x": 4.0, "done": false}
			for id in GameState.placements:
				GameState.placements[id][0] = seg
			var ids: Array = GameState.placements.keys()
			if ids.size() > 0:
				GameState.carried_items = [ids[0]]
			if ids.size() > 1:
				GameState.high_items = [ids[1]]
			main._enter_block(seg, Vector3(-4, 0, 3.5), 1)
		640:
			print("SMOKE: phone")
			main.open_phone()
			main.phone_page = 2
		680:
			GameState.modal = ""
			main.phone_page = 0
		700:
			print("SMOKE: pharmacy and bar")
			main.shop_type = "pharmacy"
			main.shop_sel = 1
			GameState.money = 20
			GameState.modal = "shop"
		710:
			main._buy(main.shop_options()[1])
		730:
			main.shop_type = "bar"
			main.shop_sel = 0
		760:
			GameState.modal = ""
		780:
			print("SMOKE: church and police desk")
			var ch := CityMap.church()
			if CityMap.is_valid(ch):
				GameState.weekday = 6
				GameState.church_day = -1
				main._enter_block(ch, Vector3(CityMap.CHURCH_DOOR_X, 0, -6.5), 1)
				main.try_enter_door(main.player.position)
		840:
			print("SMOKE: the sea")
			main._enter_block(Vector3i(0, 0, 1), Vector3(0, 0, -7.2), 1)
			GameState.promille = 2.5
			main.player.fall_in_water()
		960:
			print("SMOKE: save and continue")
			main._save_morning(main.segment, main.player.position, 1)
			main._continue_game()
			GameState.over = true
			main.hud.show_card("start", "", "")
		990:
			main.start_choice(0)
		1020:
			print("SMOKE: the ex")
			main.debug_tools._ex()
			GameState.promille = 2.8
		1040:
			main.open_phone()
			main.phone_page = 0
			main._call_ex()
		1060:
			for n in main.npcs.duplicate():
				if is_instance_valid(n) and n.role == "ex":
					n.offer_trade(main.player)
					main.ex_chat(n)
					main.ex_offended(n, true)
		1100:
			print("SMOKE: death and high scores")
			GameState.health = -1.0
			GameState.damage(1.0)
		1250:
			main.hud.show_card("scores", "x", "")
		1300:
			main.hud.hide_card()
			main._new_game()
	_drive(f)


## Walks back and forth, punches now and then, holds the button to throw.
func _drive(f: int) -> void:
	if GameState.over:
		_release()
		return
	var phase := (f / 90) % 4
	var want := "move_right" if phase < 2 else "move_left"
	if phase == 1 or phase == 3:
		want += "+move_up" if (f / 45) % 2 == 0 else "+move_down"
	if want != _held:
		_release()
		for a in want.split("+"):
			Input.action_press(a)
		_held = want
	if f % 37 == 0:
		Input.action_press("action")
	elif f % 37 == 3:
		Input.action_release("action")
	if f % 151 == 0:
		Input.action_press("action")  # held long: a throw
	elif f % 151 == 40:
		Input.action_release("action")
	if f % 120 == 60:
		Input.action_press("run")
	elif f % 120 == 100:
		Input.action_release("run")


func _release() -> void:
	for a in _held.split("+"):
		if a != "":
			Input.action_release(a)
	_held = ""


func _spawn_everyone() -> void:
	var p: Vector3 = main.player.position
	for i in ROLES.size():
		var n = main._spawn_npc(false, ROLES[i])
		n.position = Vector3(clampf(p.x + (i % 8 - 4) * 1.2, -15.0, 15.0), 0, -6.0 if i % 2 == 0 else 3.6)
	var pal = main._spawn_npc(false, "pal")
	pal.position = p + Vector3(1.0, 0, 0)
	pal.set_want("food")
	var c = main._spawn_npc(false)
	c.position = p + Vector3(-1.0, 0, 0)
	if GameState.placements.size() > 0:
		var id: String = GameState.placements.keys()[0]
		c.carry_lost(id)


func _give(kind: int) -> void:
	var it = main.spawn_item(kind, main.player.position)
	main.player._pickup(it)
