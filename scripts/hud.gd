extends Control

const LostItems = preload("res://scripts/lost_items.gd")
## The morning thought bubble stays until the player has walked this far.
const BUBBLE_WALK := 5.0
## Health heart (colour drains away, no number), alcohol in per mille
## inside a bottle icon, money, throw charge, and the full-screen cards
## for day changes and death (newspaper headline).

var main
var mode := ""  # "", "day" or "dead"
var card_title := ""
var card_sub := ""
var card_time := 0.0

var _hurt := 0.0
var _fade := 0.0
var _fade_speed := 4.0
## Heart above the player's head while punching too fast.
var _head_heart_t := 0.0
var _shown_strain := 0.0
var _bubble_on := false
## Items shown in the thought bubble (morning: today's lost items).
var _bubble_items: Array = []
var _bubble_walked := 0.0
## A short thought also disappears by itself after this many seconds.
var _think_t := 0.0
var _bubble_last := Vector3.ZERO
## Belongings that were missing this morning (found ones turn coloured).
var _today: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func flash_hurt() -> void:
	_hurt = 0.35


func show_card(m: String, title: String, sub: String) -> void:
	mode = m
	card_title = title
	card_sub = sub
	card_time = 0.0


func hide_card() -> void:
	mode = ""


## Morning: the character pats their pockets; missing things are crossed out.
func show_pocket_check() -> void:
	_today = GameState.lost.duplicate()
	_bubble_items = _today
	_bubble_on = not _today.is_empty()
	_bubble_walked = 0.0
	if main != null and main.player != null:
		_bubble_last = main.player.position


## A short thought bubble, e.g. "my phone is missing" (gone after ~2 m).
func think(items: Array) -> void:
	_bubble_items = items
	_bubble_on = true
	_bubble_walked = BUBBLE_WALK - 2.0
	if main != null and main.player != null:
		_bubble_last = main.player.position
	_think_t = 1.5


func show_head_heart() -> void:
	_head_heart_t = 2.0


## Quick fade from black when the view changes to another block.
func fade_in() -> void:
	_fade = 1.0
	_fade_speed = 4.0


## Knocked out: the screen goes black and slowly comes back.
func blackout(seconds: float) -> void:
	_fade = 1.0
	_fade_speed = 1.0 / maxf(seconds, 0.1)


## Phone icon in the top right corner: tap or click it to open the phone;
## the key is written under it.
func _phone_icon_rect(vs: Vector2) -> Rect2:
	return Rect2(Vector2(vs.x - 66, 12), Vector2(48, 78))


func _draw_phone_icon(vs: Vector2, font: Font) -> void:
	if mode != "" or GameState.modal != "":
		return
	var r := _phone_icon_rect(vs)
	var body := Rect2(r.position + Vector2(10, 0), Vector2(28, 48))
	var col := Color(0.12, 0.12, 0.14)
	for c in [Vector2(3, 3), Vector2(25, 3), Vector2(3, 45), Vector2(25, 45)]:
		draw_circle(body.position + c, 3.0, col)
	draw_rect(Rect2(body.position + Vector2(0, 3), Vector2(28, 42)), col)
	draw_rect(Rect2(body.position + Vector2(3, 0), Vector2(22, 48)), col)
	# Screen and home button.
	draw_rect(Rect2(body.position + Vector2(4, 6), Vector2(20, 32)), Color(0.45, 0.7, 0.95))
	draw_circle(body.position + Vector2(14, 43), 2.0, Color(0.6, 0.6, 0.65))
	# The key that opens it: a key cap with a P (touch screens have their
	# own phone button, so no key there).
	if not DisplayServer.is_touchscreen_available():
		var kc := Rect2(Vector2(r.get_center().x - 11, r.end.y - 24), Vector2(22, 20))
		draw_rect(kc, Color(0.15, 0.15, 0.18, 0.85))
		draw_rect(kc, Color.WHITE, false, 1.5)
		draw_string(font, Vector2(kc.position.x, kc.end.y - 5), "P", HORIZONTAL_ALIGNMENT_CENTER, kc.size.x, 15, Color.WHITE)


func _input(event: InputEvent) -> void:
	if main == null or mode != "" or GameState.modal != "" or GameState.over:
		return
	var pos := Vector2(-1, -1)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	else:
		return
	if _phone_icon_rect(get_viewport_rect().size).has_point(pos):
		main.open_phone()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_hurt = maxf(0.0, _hurt - delta)
	_fade = maxf(0.0, _fade - delta * _fade_speed)
	if _bubble_on and main != null and main.player != null:
		var p: Vector3 = main.player.position
		var d := Vector2(p.x - _bubble_last.x, p.z - _bubble_last.z).length()
		if d < 2.0:  # ignore jumps when the view changes
			_bubble_walked += d
		_bubble_last = p
		if _think_t > 0.0:
			_think_t -= delta
			if _think_t <= 0.0:
				_bubble_on = false
		if _bubble_walked >= BUBBLE_WALK:
			_bubble_on = false
	card_time += delta
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var vs := get_viewport_rect().size
	if _fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, _fade))
	if _hurt > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.8, 0.0, 0.0, _hurt * 0.5))

	# Low health: the heart beats and blinks so a near-empty heart is
	# clearly "still alive, but in danger".
	var heart_size := 58.0
	if GameState.health < 15.0 and GameState.health > 0.0:
		var beat := absf(sin(Time.get_ticks_msec() / 180.0))
		heart_size = 58.0 + 8.0 * beat
		draw_circle(Vector2(46, 46), 34.0 + 6.0 * beat, Color(1, 0.1, 0.15, 0.25 * beat))
	_draw_heart(Vector2(46, 46), heart_size, clampf(GameState.health / 100.0, 0.0, 1.0),
		clampf(GameState.strain / 100.0, 0.0, 1.0))
	_draw_bottle(Vector2(118, 10), GameState.promille, font)
	_draw_coin(Vector2(186, 46), GameState.money, font)
	_draw_phone_icon(vs, font)
	_draw_charge()
	_draw_shading_hand(vs)
	_draw_hand_hint(font)
	_draw_bin_hint()
	_draw_head_heart(delta_draw())
	_draw_arrest()
	_draw_lost_list(vs)
	if _bubble_on and mode == "" and GameState.modal == "":
		_draw_pocket_check(vs)

	if mode == "day":
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, clampf(card_time * 2.0, 0.0, 0.9)))
		draw_string(font, Vector2(0, vs.y * 0.45), card_title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 56, Color.WHITE)
		draw_string(font, Vector2(0, vs.y * 0.45 + 60), card_sub, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 28, Color(0.8, 0.8, 0.8))
	elif mode == "dead":
		_draw_headline(vs, font)


func _heart_points(center: Vector2, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var s := size / 34.0
	for i in 48:
		var t := TAU * float(i) / 48.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(center + Vector2(x, -y) * s)
	return pts


## Red = health, light pink on top = the part temporarily used up by
## punching too fast (comes back after resting).
func _draw_heart(center: Vector2, size: float, frac: float, strain := 0.0) -> void:
	var pts := _heart_points(center, size)
	draw_colored_polygon(pts, Color(0.32, 0.32, 0.36, 0.9))
	var s := size / 34.0
	var top := center.y - 13.0 * s
	var bottom := center.y + 17.0 * s
	var level := lerpf(bottom, top, frac)
	var red_level := lerpf(bottom, top, maxf(0.0, frac - strain))
	var pink_clip := PackedVector2Array([Vector2(center.x - size, level), Vector2(center.x + size, level),
		Vector2(center.x + size, bottom + 2.0), Vector2(center.x - size, bottom + 2.0)])
	if bottom - level > 0.5:
		for poly in Geometry2D.intersect_polygons(pts, pink_clip):
			draw_colored_polygon(poly, Color(1.0, 0.65, 0.72))
	var clip := PackedVector2Array([Vector2(center.x - size, red_level), Vector2(center.x + size, red_level),
		Vector2(center.x + size, bottom + 2.0), Vector2(center.x - size, bottom + 2.0)])
	if bottom - red_level > 0.5:
		for poly in Geometry2D.intersect_polygons(pts, clip):
			draw_colored_polygon(poly, Color(0.9, 0.12, 0.18))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.08, 0.08, 0.1), 2.0, true)


func _draw_bottle(origin: Vector2, promille: float, font: Font) -> void:
	var pts := PackedVector2Array()
	for p in [Vector2(-7, 0), Vector2(7, 0), Vector2(7, 20), Vector2(22, 36), Vector2(22, 100),
			Vector2(-22, 100), Vector2(-22, 36), Vector2(-7, 20)]:
		pts.append(origin + Vector2(22, 0) + p)
	draw_colored_polygon(pts, Color(0.2, 0.3, 0.22, 0.85))
	var frac := clampf(promille / GameState.PROMILLE_MAX_SHOWN, 0.0, 1.0)
	var bottom := origin.y + 100.0
	var level := lerpf(bottom, origin.y + 4.0, frac)
	var clip := PackedVector2Array([Vector2(origin.x - 10, level), Vector2(origin.x + 60, level),
		Vector2(origin.x + 60, bottom + 2), Vector2(origin.x - 10, bottom + 2)])
	var fill_col := Color(0.95, 0.65, 0.15)
	if promille < GameState.PROMILLE_HANGOVER:
		fill_col = Color(0.85, 0.25, 0.2)
	elif promille > GameState.PROMILLE_DRUNK:
		fill_col = Color(0.95, 0.85, 0.3)
	for poly in Geometry2D.intersect_polygons(pts, clip):
		draw_colored_polygon(poly, fill_col)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.08, 0.08, 0.1), 2.0, true)
	# Exact reading inside the bottle: alcohol is the key number.
	var text := GameState.format_promille(promille).replace(" ", "")
	var pos := Vector2(origin.x, origin.y + 74)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 44, 15, 5, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 44, 15, Color.WHITE)


func _draw_coin(center: Vector2, amount: int, font: Font) -> void:
	draw_circle(center, 18.0, Color(0.95, 0.75, 0.2))
	draw_arc(center, 18.0, 0.0, TAU, 32, Color(0.5, 0.35, 0.05), 2.0, true)
	draw_string(font, center + Vector2(-18, 6), "€", HORIZONTAL_ALIGNMENT_CENTER, 36, 18, Color(0.45, 0.3, 0.05))
	var text := str(amount)
	draw_string_outline(font, center + Vector2(26, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color.BLACK)
	draw_string(font, center + Vector2(26, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)


## Police holding on: a blue-red ring fills around the player.
func _draw_arrest() -> void:
	if main == null or main.arrest <= 0.0:
		return
	var p: Vector3 = main.player.global_position + Vector3(0, 1.0, 0)
	if main.camera.is_position_behind(p):
		return
	var sp: Vector2 = main.camera.unproject_position(p)
	draw_arc(sp, 34.0, 0, TAU, 40, Color(0, 0, 0, 0.35), 7.0, true)
	var col := Color(0.25, 0.45, 1.0) if int(Time.get_ticks_msec() / 150) % 2 == 0 else Color(1.0, 0.25, 0.25)
	draw_arc(sp, 34.0, -PI * 0.5, -PI * 0.5 + TAU * main.arrest, 40, col, 7.0, true)


## Held item: what a short press and a hold do, as icons above the head
## for a few seconds after picking it up (no text):
##   [button] -> drink / eat / punch
##   [button + clock] -> throw
func _draw_hand_hint(_font: Font) -> void:
	if main == null or main.player == null or mode != "" or GameState.modal != "":
		return
	var pl = main.player
	if pl.hand_item == null or pl.hand_hint_t <= 0.0 or pl.is_aiming():
		return
	var p: Vector3 = pl.global_position + Vector3(0, 2.75, 0)
	if main.camera.is_position_behind(p):
		return
	var sp: Vector2 = main.camera.unproject_position(p)
	var a := clampf(pl.hand_hint_t, 0.0, 1.0)
	var rows := [[false, pl.hand_short_action_key()], [true, "ACT_THROW"]]
	for i in rows.size():
		var c := sp + Vector2(0, -34 + i * 34)
		draw_rect(Rect2(c - Vector2(52, 15), Vector2(104, 30)), Color(0, 0, 0, 0.4 * a))
		_hint_button(c + Vector2(-30, 0), rows[i][0], a)
		_hint_arrow(c + Vector2(4, 0), a)
		_hint_action(c + Vector2(32, 0), rows[i][1], a)


## Dazzled by the sun: the player's own hand comes down into view at the
## top of the screen, palm down like a visor, dark against the light.
func _draw_shading_hand(vs: Vector2) -> void:
	if main == null or mode != "" or GameState.modal != "":
		return
	var amt: float = main.shade_amount()
	if amt <= 0.01:
		return
	var u := vs.y
	var o := Vector2(vs.x * 0.16, lerpf(-u * 0.24, 0.0, amt))
	var pt := func(x: float, y: float) -> Vector2:
		return o + Vector2(x, y) * u
	var col := Color(0.36, 0.26, 0.22, 0.95 * amt)
	# Soft edge first (a little wider and fainter), then the hand itself.
	for pass_i in 2:
		var grow := 0.012 if pass_i == 0 else 0.0
		var c := Color(col.r, col.g, col.b, col.a * (0.35 if pass_i == 0 else 1.0))
		var g := grow * u
		# Forearm from the top-left, wrist, palm.
		draw_colored_polygon(PackedVector2Array([pt.call(-0.02, -0.06) + Vector2(-g, -g),
			pt.call(0.17, -0.06) + Vector2(g, -g), pt.call(0.31, 0.08) + Vector2(g, 0),
			pt.call(0.21, 0.145) + Vector2(-g, g)]), c)
		draw_colored_polygon(PackedVector2Array([pt.call(0.2, 0.055) + Vector2(-g, -g),
			pt.call(0.41, 0.055) + Vector2(g, -g), pt.call(0.43, 0.155) + Vector2(g, g),
			pt.call(0.22, 0.17) + Vector2(-g, g)]), c)
		# Four fingers pointing ahead, slightly fanned, and the thumb.
		var fingers := [[0.068, 0.17], [0.093, 0.19], [0.118, 0.18], [0.143, 0.15]]
		for f in fingers:
			var a: Vector2 = pt.call(0.4, f[0])
			var b: Vector2 = pt.call(0.4 + f[1], f[0] + 0.006)
			var w := 0.024 * u + g * 2.0
			draw_line(a, b, c, w)
			draw_circle(b, w * 0.5, c)
		var t0: Vector2 = pt.call(0.27, 0.15)
		var t1: Vector2 = pt.call(0.34, 0.215)
		draw_line(t0, t1, c, 0.028 * u + g * 2.0)
		draw_circle(t1, 0.014 * u + g, c)
	# Sunlight catching the edge of the fingers.
	for f in [0.068, 0.093, 0.118, 0.143]:
		draw_line(pt.call(0.42, f - 0.012), pt.call(0.55, f - 0.009), Color(1, 0.9, 0.7, 0.25 * amt), 2.0)


## Near an unsearched bin: a magnifier above it; next to it (where the
## button would search) the button picture too: [button] -> magnifier.
func _draw_bin_hint() -> void:
	if main == null or main.player == null or mode != "" or GameState.modal != "":
		return
	var pl = main.player
	var h: Dictionary = main.bin_hint(pl.position)
	if h.is_empty():
		return
	# With a hand item and someone close, the button punches instead.
	var reach: bool = h["reach"] and (pl.hand_item == null or main.nearest_npc_distance(pl.position) > 2.5)
	var p := Vector3(h["x"], 1.55, -7.5)
	if main.camera.is_position_behind(p):
		return
	var sp: Vector2 = main.camera.unproject_position(p)
	var bob := sin(Time.get_ticks_msec() / 250.0) * 2.0
	if reach:
		draw_rect(Rect2(sp - Vector2(36, 15), Vector2(72, 30)), Color(0, 0, 0, 0.4))
		_hint_button(sp + Vector2(-16, 0), false, 1.0)
		_hint_action(sp + Vector2(18, bob * 0.5), "SEARCH", 1.0)
	else:
		_hint_action(sp + Vector2(0, bob), "SEARCH", 0.6)


## The action button: a space bar on a keyboard, the big round button on
## a touch screen. `hold`: a little clock next to it (keep it pressed).
func _hint_button(c: Vector2, hold: bool, a: float) -> void:
	var w := Color(1, 1, 1, a)
	var bc := c - Vector2(6, 0) if hold else c
	if DisplayServer.is_touchscreen_available():
		draw_circle(bc, 10.0, Color(0.15, 0.15, 0.18, 0.8 * a))
		draw_arc(bc, 10.0, 0.0, TAU, 24, w, 2.0, true)
	else:
		var r := Rect2(bc - Vector2(14, 6), Vector2(28, 12))
		draw_rect(r, Color(0.15, 0.15, 0.18, 0.8 * a))
		draw_rect(r, w, false, 2.0)
	if hold:
		var cc := c + Vector2(13, -6)
		draw_circle(cc, 6.5, Color(0.15, 0.15, 0.18, 0.9 * a))
		draw_arc(cc, 6.0, -PI * 0.5, PI, 16, Color(1, 0.85, 0.3, a), 2.0, true)
		draw_line(cc, cc + Vector2(0, -4), w, 1.5)
		draw_line(cc, cc + Vector2(3, 0), w, 1.5)


func _hint_arrow(c: Vector2, a: float) -> void:
	var w := Color(1, 1, 1, a)
	draw_line(c - Vector2(7, 0), c + Vector2(4, 0), w, 2.5)
	draw_colored_polygon(PackedVector2Array([c + Vector2(9, 0), c + Vector2(3, -5), c + Vector2(3, 5)]), w)


func _hint_action(c: Vector2, act: String, a: float) -> void:
	var w := Color(1, 1, 1, a)
	match act:
		"ACT_DRINK":
			# Bottle tipped up to drink, with a couple of drops.
			draw_set_transform(c, -0.7, Vector2.ONE)
			draw_rect(Rect2(Vector2(-4, -2), Vector2(8, 13)), Color(0.3, 0.75, 0.35, a))
			draw_rect(Rect2(Vector2(-2, -9), Vector2(4, 8)), Color(0.3, 0.75, 0.35, a))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_circle(c + Vector2(-9, -8), 1.8, Color(1, 0.8, 0.3, a))
			draw_circle(c + Vector2(-11, -3), 1.5, Color(1, 0.8, 0.3, a))
		"ACT_EAT":
			var col := Color(0.85, 0.4, 0.3, a)
			draw_circle(c + Vector2(-7, 0), 4.0, col)
			draw_circle(c + Vector2(7, 0), 4.0, col)
			draw_rect(Rect2(c + Vector2(-7, -4), Vector2(14, 8)), col)
			# A bite out of one end.
			draw_circle(c + Vector2(11, -2), 2.5, Color(0.1, 0.1, 0.1, 0.6 * a))
		"SEARCH":
			# Magnifying glass.
			draw_circle(c + Vector2(-2, -2), 7.0, Color(0.6, 0.8, 1.0, 0.35 * a))
			draw_arc(c + Vector2(-2, -2), 7.0, 0.0, TAU, 20, w, 2.5, true)
			draw_line(c + Vector2(3, 3), c + Vector2(9, 9), w, 3.5)
		"ACT_THROW":
			# Dotted arc with an arrow head, a bottle at the start.
			for k in 6:
				var t := float(k) / 5.0
				var pt := c + Vector2(lerpf(-11, 10, t), 5.0 - sin(PI * t) * 12.0)
				draw_circle(pt, 1.6, w)
			draw_colored_polygon(PackedVector2Array([c + Vector2(13, 7), c + Vector2(7, 6), c + Vector2(11, 1)]), w)
			draw_rect(Rect2(c + Vector2(-15, 2), Vector2(5, 8)), Color(0.3, 0.75, 0.35, a))
		_:
			# Fist: knuckles to the front.
			var skin := Color(0.96, 0.8, 0.68, a)
			draw_rect(Rect2(c + Vector2(-8, -6), Vector2(16, 13)), skin)
			draw_circle(c + Vector2(8, -2), 3.5, skin)
			for k in 3:
				draw_line(c + Vector2(-4 + k * 4, -6), c + Vector2(-4 + k * 4, -1), Color(0.55, 0.35, 0.25, a), 1.5)
			draw_rect(Rect2(c + Vector2(-8, -6), Vector2(16, 13)), Color(0.55, 0.35, 0.25, a), false, 1.5)


func delta_draw() -> float:
	return get_process_delta_time()


## A small heart above the head: red = health left, light pink = used up by
## punching too fast. The pink part grows smoothly so it looks like the
## heart drains. Shown for a moment after each too-fast punch and while
## exhausted.
func _draw_head_heart(dt: float) -> void:
	if main == null or main.player == null:
		return
	_shown_strain = lerpf(_shown_strain, GameState.strain, 1.0 - exp(-8.0 * dt))
	if GameState.exhausted:
		_head_heart_t = maxf(_head_heart_t, 0.5)
	_head_heart_t = maxf(0.0, _head_heart_t - dt)
	if _head_heart_t <= 0.0:
		return
	var p: Vector3 = main.player.global_position + Vector3(0, 2.5, 0)
	if main.camera.is_position_behind(p):
		return
	var sp: Vector2 = main.camera.unproject_position(p)
	var a := clampf(_head_heart_t / 0.4, 0.0, 1.0)
	var hp := maxf(GameState.health, 0.001)
	var size := 34.0
	if GameState.exhausted:
		size += 4.0 * absf(sin(Time.get_ticks_msec() / 160.0))
	modulate.a = 1.0
	draw_circle(sp, size * 0.62, Color(0, 0, 0, 0.25 * a))
	# Here the heart is "full" = current health; pink = share used up.
	_draw_heart(sp, size, 1.0, clampf(_shown_strain / hp, 0.0, 1.0))


func _draw_charge() -> void:
	if main == null or main.player == null:
		return
	var c: float = main.player.throw_charge()
	var pc: float = main.player.punch_charge()
	if c < 0.0 and pc < 0.0:
		return
	var p: Vector3 = main.player.global_position + Vector3(0, 2.3, 0)
	if main.camera.is_position_behind(p):
		return
	var sp: Vector2 = main.camera.unproject_position(p)
	if c < 0.0:
		# Charging a punch with an empty hand: just the ring, no aim arrow.
		draw_arc(sp, 16.0, -PI * 0.5, -PI * 0.5 + TAU * pc, 32, Color(1, 0.55, 0.3), 5.0, true)
		return
	draw_arc(sp, 16.0, -PI * 0.5, -PI * 0.5 + TAU * c, 32, Color(1, 0.9, 0.3), 5.0, true)
	# Aim arrow on the ground in the throw direction.
	var a: Vector2 = main.player.aim
	var base: Vector3 = main.player.global_position + Vector3(0, 0.15, 0)
	var tip3 := base + Vector3(a.x, 0, a.y) * (1.2 + c * 1.5)
	var b2: Vector2 = main.camera.unproject_position(base)
	var t2: Vector2 = main.camera.unproject_position(tip3)
	var dir2 := (t2 - b2).normalized()
	draw_line(b2, t2, Color(1, 0.9, 0.3), 4.0, true)
	draw_colored_polygon(PackedVector2Array([t2 + dir2 * 12.0, t2 + dir2.orthogonal() * 8.0,
		t2 - dir2.orthogonal() * 8.0]), Color(1, 0.9, 0.3))


func _draw_headline(vs: Vector2, font: Font) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, clampf(card_time * 2.0, 0.0, 0.75)))
	var w := minf(vs.x * 0.8, 820.0)
	var h := minf(vs.y * 0.8, 480.0)
	var r := Rect2((vs - Vector2(w, h)) * 0.5, Vector2(w, h))
	draw_rect(r, Color(0.97, 0.95, 0.87))
	# Masthead (fictional local paper).
	draw_rect(Rect2(r.position, Vector2(w, 64)), Color(0.85, 0.1, 0.12))
	draw_string(font, r.position + Vector2(0, 46), tr("PAPER_NAME"), HORIZONTAL_ALIGNMENT_CENTER, w, 38, Color.WHITE)
	# Headline.
	draw_multiline_string(font, r.position + Vector2(30, 130), card_title.to_upper(), HORIZONTAL_ALIGNMENT_CENTER,
		w - 60, 44, 4, Color(0.08, 0.08, 0.08))
	_draw_photo(Rect2(r.position + Vector2(w * 0.5 - 110, 200), Vector2(220, maxf(h - 330, 60))))
	draw_line(r.position + Vector2(30, h - 110), r.position + Vector2(w - 30, h - 110), Color(0.2, 0.2, 0.2), 2.0)
	draw_string(font, r.position + Vector2(0, h - 60), card_sub, HORIZONTAL_ALIGNMENT_CENTER, w, 34, Color(0.1, 0.1, 0.1))
	# "Press to play again" as an icon: the action button with a play arrow.
	if card_time > 1.0:
		var bc := r.position + Vector2(w - 50, h - 50)
		draw_circle(bc, 24.0, Color(0.85, 0.1, 0.12))
		draw_colored_polygon(PackedVector2Array([bc + Vector2(-7, -11), bc + Vector2(12, 0), bc + Vector2(-7, 11)]), Color.WHITE)


## Placeholder "news photo": the character's silhouette in a grey frame.
func _draw_photo(r: Rect2) -> void:
	draw_rect(r, Color(0.55, 0.55, 0.55))
	draw_rect(r, Color(0.15, 0.15, 0.15), false, 3.0)
	var c := r.get_center()
	var s := r.size.y / 160.0
	draw_circle(c + Vector2(0, -42) * s, 16.0 * s, Color(0.2, 0.2, 0.22))
	draw_rect(Rect2(c + Vector2(-24, -24) * s, Vector2(48, 60) * s), Color(0.2, 0.2, 0.22))
	draw_rect(Rect2(c + Vector2(-20, 36) * s, Vector2(16, 40) * s), Color(0.2, 0.2, 0.22))
	draw_rect(Rect2(c + Vector2(4, 36) * s, Vector2(16, 40) * s), Color(0.2, 0.2, 0.22))
	# Bottle in hand.
	draw_rect(Rect2(c + Vector2(28, -6) * s, Vector2(10, 26) * s), Color(0.18, 0.42, 0.2))


## Heavy drinking makes the character forget what they were looking for.
func _forgotten(id: String) -> bool:
	var p := GameState.promille
	if p <= GameState.PROMILLE_DRUNK:
		return false
	var level := 1 if p < 1.9 else (2 if p < 2.4 else 3)
	return (LostItems.IDS.find(id) % 3) < level


## Today's search list at the top centre: "Find:" and the item icons
## (grey = still missing, coloured = found).
func _draw_lost_list(vs: Vector2) -> void:
	if _today.is_empty():
		return
	var font := get_theme_default_font()
	var size := 44.0
	var gap := 12.0
	var label := tr("FIND")
	var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var icons_w := _today.size() * size + (_today.size() - 1) * gap
	var w := label_w + 16.0 + icons_w + 36.0
	var r := Rect2(Vector2((vs.x - w) * 0.5, 10), Vector2(w, size + 16))
	draw_rect(r, Color(0, 0, 0, 0.45))
	var ty := r.get_center().y + 9
	draw_string_outline(font, Vector2(r.position.x + 18, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color.BLACK)
	draw_string(font, Vector2(r.position.x + 18, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.9, 0.4))
	var x := r.position.x + 18 + label_w + 16 + size * 0.5
	for id in _today:
		var c := Vector2(x, r.get_center().y)
		draw_circle(c, size * 0.55, Color(1, 1, 1, 0.15))
		var m := "own"
		if GameState.is_lost(id):
			m = "blob" if _forgotten(id) else "lost"
		LostItems.draw_icon(self, id, c, size, m)
		if m == "own":
			# Found: a green tick.
			draw_polyline(PackedVector2Array([c + Vector2(6, 10), c + Vector2(12, 16), c + Vector2(22, 2)]),
				Color(0.3, 0.95, 0.3), 4.0, true)
		x += size + gap


## Morning: a thought bubble above the character's head with the things
## that are missing (crossed out). Fades during the last metre of walking.
func _draw_pocket_check(vs: Vector2) -> void:
	var head: Vector3 = main.player.global_position + Vector3(0, 2.3, 0)
	if main.camera.is_position_behind(head):
		return
	var a := clampf((BUBBLE_WALK - _bubble_walked) / 1.0, 0.0, 1.0)
	var anchor: Vector2 = main.camera.unproject_position(head)
	var size := 46.0
	var gap := 12.0
	var w := _bubble_items.size() * size + (_bubble_items.size() - 1) * gap + 36.0
	var h := size + 30.0
	var center := anchor + Vector2(30, -h * 0.5 - 46)
	center.x = clampf(center.x, w * 0.5 + 8, vs.x - w * 0.5 - 8)
	center.y = maxf(center.y, h * 0.5 + 8)
	var white := Color(1, 1, 1, 0.92 * a)
	var edge := Color(0.2, 0.2, 0.25, 0.8 * a)
	# Small trailing bubbles from the head.
	draw_circle(anchor + Vector2(6, -10), 5.0, white)
	draw_circle(anchor + Vector2(14, -26), 8.0, white)
	# Cloud: rounded body made of overlapping circles.
	var r := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	var bumps := maxi(3, int(w / 34.0))
	for i in bumps + 1:
		var x := lerpf(r.position.x + h * 0.3, r.end.x - h * 0.3, float(i) / bumps)
		draw_circle(Vector2(x, r.position.y + h * 0.3), h * 0.32, edge)
		draw_circle(Vector2(x, r.end.y - h * 0.3), h * 0.32, edge)
	draw_rect(r.grow(-2.0), edge)
	for i in bumps + 1:
		var x := lerpf(r.position.x + h * 0.3, r.end.x - h * 0.3, float(i) / bumps)
		draw_circle(Vector2(x, r.position.y + h * 0.3), h * 0.32 - 2.0, white)
		draw_circle(Vector2(x, r.end.y - h * 0.3), h * 0.32 - 2.0, white)
	draw_rect(r.grow(-4.0), white)
	for i in _bubble_items.size():
		var id: String = _bubble_items[i]
		var c := Vector2(r.position.x + 18 + size * 0.5 + i * (size + gap), center.y)
		LostItems.draw_icon(self, id, c, size, "own")
		var red := Color(0.9, 0.1, 0.1, a)
		draw_line(c - Vector2(size, size) * 0.38, c + Vector2(size, size) * 0.38, red, 4.0, true)
		draw_line(c + Vector2(-size, size) * 0.38, c + Vector2(size, -size) * 0.38, red, 4.0, true)
