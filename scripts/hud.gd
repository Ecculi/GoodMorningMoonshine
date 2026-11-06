extends Control

const LostItems = preload("res://scripts/lost_items.gd")
const BuildInfo = preload("res://scripts/build_info.gd")
const Npc = preload("res://scripts/npc.gd")
## The version and build time show small at the bottom of the screen at
## start, until the player first moves (then they fade out quickly).
var _version_a := 1.0
var _version_fading := false
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
	_death_photo = null
	_death_caption = ""


## Morning: the character pats their pockets; missing things are crossed out.
func show_pocket_check() -> void:
	_today = GameState.lost.duplicate()
	_bubble_items = _today
	_bubble_on = not _today.is_empty()
	_bubble_walked = 0.0
	if main != null and main.player != null:
		_bubble_last = main.player.position


## A short thought bubble, e.g. "my phone is missing" (gone after ~2 m).
## Phone held upright: the game is made for a wide screen, so ask to turn
## the phone (the game keeps running underneath).
func _draw_rotate_prompt(vs: Vector2, font: Font) -> void:
	if vs.x >= vs.y:
		return
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.75))
	var c := vs * 0.5 + Vector2(0, -60)
	var t := Time.get_ticks_msec() / 1000.0
	# A phone turning from upright to sideways.
	var ang := -PI * 0.5 * smoothstep(0.2, 0.8, fmod(t, 2.0) / 2.0)
	var hw := 34.0
	var hh := 60.0
	var pts := PackedVector2Array()
	for p in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]:
		pts.append(c + p.rotated(ang))
	draw_colored_polygon(pts, Color(0.9, 0.9, 0.95))
	var inner := PackedVector2Array()
	for p in [Vector2(-hw + 6, -hh + 10), Vector2(hw - 6, -hh + 10), Vector2(hw - 6, hh - 14), Vector2(-hw + 6, hh - 14)]:
		inner.append(c + p.rotated(ang))
	draw_colored_polygon(inner, Color(0.3, 0.55, 0.9))
	draw_arc(c, 95.0, -PI * 0.5, -PI * 0.15, 20, Color(1, 0.85, 0.3), 5.0, true)
	var text := tr("ROTATE_PHONE")
	draw_multiline_string(font, Vector2(20, c.y + 140), text, HORIZONTAL_ALIGNMENT_CENTER, vs.x - 40, 34, -1, Color.WHITE)


## Version and build time small at the bottom of the screen when the game
## starts (out of the way of the city intro); gone as soon as the player
## moves (it stays in the F1 help).
func _draw_version(vs: Vector2, font: Font) -> void:
	if _version_a <= 0.0:
		return
	if GameState.moving:
		_version_fading = true
	if _version_fading:
		_version_a = maxf(0.0, _version_a - get_process_delta_time() * 3.0)
	var a := _version_a
	var text := BuildInfo.text()
	var p := Vector2(0, vs.y - 18)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 16, 5, Color(0, 0, 0, 0.7 * a))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 16, Color(1, 1, 1, 0.75 * a))


## New game: the city's name big in the middle of the screen (with the
## version under it) until the player starts moving.
var _city_name := ""
var _city_a := 0.0
var _city_fading := false


func show_city(n: String) -> void:
	_city_name = n
	_city_a = 1.0
	_city_fading = false


func _draw_city(vs: Vector2, font: Font) -> void:
	if _city_a <= 0.0 or _city_name == "":
		return
	if GameState.moving:
		_city_fading = true
	if _city_fading:
		_city_a = maxf(0.0, _city_a - get_process_delta_time() * 1.5)
	var a := _city_a
	var y := vs.y * 0.34
	draw_string_outline(font, Vector2(0, y), _city_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 72, 14,
		Color(0, 0, 0, 0.8 * a))
	draw_string(font, Vector2(0, y), _city_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 72, Color(1, 0.9, 0.5, a))
	var sub := tr("CITY_SUB")
	draw_string_outline(font, Vector2(0, y + 40), sub, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 22, 6, Color(0, 0, 0, 0.8 * a))
	draw_string(font, Vector2(0, y + 40), sub, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 22, Color(1, 1, 1, 0.9 * a))
	# What to do, in three short lines with pictures.
	var lines := [["SEARCH", tr("INTRO_1")], ["THERMO", tr("INTRO_2")], ["ACT_DRINK", tr("INTRO_3")], ["HOME", tr("INTRO_4")]]
	var bw := 0.0
	for ln in lines:
		bw = maxf(bw, font.get_string_size(ln[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x)
	var box := Rect2(Vector2((vs.x - bw - 70) * 0.5, y + 62), Vector2(bw + 70, lines.size() * 32 + 14))
	draw_rect(box, Color(0, 0, 0, 0.5 * a))
	for i in lines.size():
		var ic := box.position + Vector2(28, 24 + i * 32)
		var kind: String = lines[i][0]
		if kind == "THERMO":
			draw_rect(Rect2(ic + Vector2(-14, -4), Vector2(28, 8)), Color(0.1, 0.1, 0.15, a))
			draw_rect(Rect2(ic + Vector2(-14, -4), Vector2(20, 8)), Color(1, 0.4, 0.15, a))
			draw_rect(Rect2(ic + Vector2(-14, -4), Vector2(28, 8)), Color(1, 1, 1, 0.6 * a), false, 1.0)
		elif kind == "HOME":
			var hcol := Color(0.25, 0.8, 0.4, a)
			draw_rect(Rect2(ic + Vector2(-9, -3), Vector2(18, 12)), hcol)
			draw_colored_polygon(PackedVector2Array([ic + Vector2(-12, -2), ic + Vector2(0, -13), ic + Vector2(12, -2)]), hcol)
		else:
			_hint_action(ic, kind, a)
		draw_string(font, ic + Vector2(26, 7), lines[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1, 1, 1, a))


## A lost thing was just found: shown big in the middle of the screen.
const FOUND_TIME := 2.4
var _found_id := ""
var _found_t := 0.0


func show_found(id: String) -> void:
	_found_id = id
	_found_t = FOUND_TIME


## Gull droppings on the "view": white splats that fade bit by bit.
const SPLAT_TIME := 7.0
var _splats: Array = []


func splat() -> void:
	var vs := get_viewport_rect().size
	_splats.append({
		"pos": Vector2(randf_range(vs.x * 0.15, vs.x * 0.85), randf_range(vs.y * 0.1, vs.y * 0.7)),
		"size": randf_range(75.0, 143.0), "t": SPLAT_TIME, "seed": randi(),
	})
	if _splats.size() >= 3:
		GameState.unlock("SPLATS3")


func _draw_splats() -> void:
	var dt := get_process_delta_time()
	for sp in _splats.duplicate():
		sp["t"] -= dt
		if sp["t"] <= 0.0:
			_splats.erase(sp)
			continue
		# Holds for a moment, then fades slowly.
		var a := clampf(sp["t"] / (SPLAT_TIME * 0.7), 0.0, 1.0)
		var r := RandomNumberGenerator.new()
		r.seed = sp["seed"]
		var c: Vector2 = sp["pos"]
		var s: float = sp["size"]
		var col := Color(0.96, 0.96, 0.9, 0.85 * a)
		var shade := Color(0.82, 0.84, 0.72, 0.8 * a)
		draw_circle(c, s * 0.42, shade)
		draw_circle(c, s * 0.36, col)
		# Splashes round the edge and a couple of runs down.
		for i in 9:
			var d := Vector2.from_angle(r.randf() * TAU)
			draw_circle(c + d * s * r.randf_range(0.35, 0.65), s * r.randf_range(0.06, 0.15), col)
		for i in 2:
			var x0 := c.x + r.randf_range(-0.25, 0.25) * s
			var ln := s * r.randf_range(0.4, 0.9) * (1.0 - a * 0.3 + 0.3)
			draw_line(Vector2(x0, c.y), Vector2(x0, c.y + ln), col, s * 0.09)
			draw_circle(Vector2(x0, c.y + ln), s * 0.07, col)
		# A greyish-green centre.
		draw_circle(c + Vector2(s * 0.06, -s * 0.04), s * 0.12, Color(0.45, 0.5, 0.35, 0.7 * a))


## Achievement unlocked: a banner slides in at the bottom left for a few
## seconds (a trophy and the name). Several queue up.
const ACH_TIME := 4.0
var _ach_queue: Array = []
var _ach_t := 0.0


func show_achievement(id: String) -> void:
	_ach_queue.append(id)


func _draw_achievement(vs: Vector2, font: Font) -> void:
	if _ach_queue.is_empty():
		return
	_ach_t += get_process_delta_time()
	if _ach_t >= ACH_TIME:
		_ach_t = 0.0
		_ach_queue.pop_front()
		return
	var id: String = _ach_queue[0]
	var slide := clampf(_ach_t / 0.3, 0.0, 1.0) * clampf((ACH_TIME - _ach_t) / 0.3, 0.0, 1.0)
	var name_text := tr("ACH_" + id)
	var w := maxf(font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x, 160.0) + 90.0
	var r := Rect2(Vector2(lerpf(-w, 16.0, slide), vs.y - 250.0), Vector2(w, 64))
	draw_rect(r, Color(0.08, 0.08, 0.1, 0.88))
	draw_rect(r, Color(1, 0.8, 0.25), false, 2.0)
	# Trophy.
	var c := r.position + Vector2(34, 32)
	var gold := Color(1, 0.8, 0.25)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-13, -16), c + Vector2(13, -16), c + Vector2(8, 2),
		c + Vector2(-8, 2)]), gold)
	draw_arc(c + Vector2(-13, -9), 6.0, PI * 0.5, PI * 1.5, 10, gold, 3.0)
	draw_arc(c + Vector2(13, -9), 6.0, -PI * 0.5, PI * 0.5, 10, gold, 3.0)
	draw_rect(Rect2(c + Vector2(-3, 2), Vector2(6, 8)), gold)
	draw_rect(Rect2(c + Vector2(-10, 10), Vector2(20, 5)), gold)
	draw_string(font, r.position + Vector2(66, 24), tr("ACH_UNLOCKED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(1, 0.8, 0.35))
	draw_string(font, r.position + Vector2(66, 50), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


## Something lost during the day joins the find list.
func add_today(id: String) -> void:
	if not _today.has(id):
		_today.append(id)


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


var _was_hungover := false


func _process(delta: float) -> void:
	_hurt = maxf(0.0, _hurt - delta)
	# Just slipped under 0.5 per mille: a red warning above the head too.
	var hung := GameState.hangover_drain() > 0.0 and not GameState.over
	if hung and not _was_hungover and main != null and main.player != null:
		main.popup("‰!", main.player.position + Vector3(0, 2.5, 0), Color(1, 0.25, 0.2))
		flash_hurt()
	_was_hungover = hung
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
	# Very wide screens: black bars at the sides (the playing area is
	# limited to about 2.6:1); the HUD stays on top.
	if main != null and main.play_left > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(main.play_left, vs.y)), Color.BLACK)
		draw_rect(Rect2(Vector2(main.play_right, 0), Vector2(vs.x - main.play_right, vs.y)), Color.BLACK)
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
	_draw_hangover_warning()
	_draw_trip(vs)
	_draw_splats()
	_draw_police_vision()
	_draw_offscreen_lost(vs)
	_draw_coin(Vector2(186, 46), GameState.money, font)
	_draw_phone_icon(vs, font)
	_draw_charge()
	_draw_shading_hand(vs)
	_draw_hand_hint(font)
	_draw_bin_hint()
	_draw_home_hint(vs, font)
	_draw_trade_hint()
	_draw_found(vs)
	_draw_version(vs, font)
	_draw_city(vs, font)
	_draw_rotate_prompt(vs, font)
	_draw_achievement(vs, font)
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


## Debug tools on: each police officer's vision cone on the ground (red
## when the player is inside it). Players never see it.
func _draw_police_vision() -> void:
	if main == null or main.debug_tools == null or not main.debug_tools.debug_on or main.player == null:
		return
	var cam: Camera3D = main.camera
	var sight: float = main.police_sight()
	for n in main.npcs:
		if n.role != "police" or n.is_down():
			continue
		var a: float = n.view_angle()
		var pts := PackedVector2Array()
		var origin := Vector3(n.position.x, 0.05, n.position.z)
		if cam.is_position_behind(origin):
			continue
		pts.append(cam.unproject_position(origin))
		var ok := true
		var steps := 12
		for i in steps + 1:
			var b: float = a - Npc.VISION_HALF_ANGLE + 2.0 * Npc.VISION_HALF_ANGLE * i / steps
			var w := origin + Vector3(cos(b), 0.0, -sin(b)) * sight
			if cam.is_position_behind(w):
				ok = false
				break
			pts.append(cam.unproject_position(w))
		if not ok:
			continue
		var seen: bool = n.sees(main.player.position, sight)
		var col := Color(1, 0.2, 0.2, 0.28) if seen else Color(0.3, 0.6, 1.0, 0.2)
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, Color(col.r, col.g, col.b, 0.7), 1.5, true)


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


## A lost thing in this block but out of view: an arrow at that edge of
## the screen with the thing's icon, pointing the way.
func _draw_offscreen_lost(vs: Vector2) -> void:
	if main == null or mode != "" or GameState.modal != "":
		return
	for ln in main.lost_nodes:
		if not is_instance_valid(ln):
			continue
		var p: Vector3 = ln.global_position + Vector3(0, 0.3, 0)
		if main.camera.is_position_behind(p):
			continue
		var sp: Vector2 = main.camera.unproject_position(p)
		var pl_l: float = main.play_left
		var pl_r: float = main.play_right
		if sp.x >= pl_l and sp.x <= pl_r:
			continue
		var side := 1.0 if sp.x > pl_r else -1.0
		var y := clampf(sp.y, 120.0, vs.y - 60.0)
		var tip := Vector2(pl_r - 14.0 if side > 0.0 else pl_l + 14.0, y)
		var bob := sin(Time.get_ticks_msec() / 180.0) * 4.0 * side
		tip.x += bob
		var back := tip - Vector2(side * 22.0, 0)
		draw_colored_polygon(PackedVector2Array([tip, back + Vector2(0, -14), back + Vector2(0, 14)]),
			Color(1, 0.6, 0.15, 0.9))
		var ic := back - Vector2(side * 28.0, 0)
		draw_circle(ic, 22.0, Color(1, 1, 1, 0.85))
		LostItems.draw_icon(self, ln.id, ic, 30.0, "own")


## After a punk's pills: rainbow colours wash over the view in slow
## waves, with soft rings breathing out from the middle.
func _draw_trip(vs: Vector2) -> void:
	var k := GameState.trip_amount()
	if k <= 0.0 or mode != "":
		return
	var t := Time.get_ticks_msec() / 1000.0
	var bands := 6
	for i in bands:
		var h := fmod(t * 0.08 + float(i) / float(bands), 1.0)
		var y0 := vs.y * float(i) / float(bands) + sin(t * 1.3 + float(i)) * 18.0
		draw_rect(Rect2(Vector2(0, y0), Vector2(vs.x, vs.y / float(bands) + 24.0)),
			Color.from_hsv(h, 0.7, 1.0, 0.1 * k))
	var c := vs * 0.5
	for i in 3:
		var ph := fmod(t * 0.35 + float(i) / 3.0, 1.0)
		var r := ph * vs.length() * 0.6
		draw_arc(c, r, 0.0, TAU, 64, Color.from_hsv(fmod(t * 0.2 + ph, 1.0), 0.6, 1.0, 0.18 * k * (1.0 - ph)), 14.0, true)


## Hangover (under 0.5 per mille) drains health: make the link plain.
## The bottle blinks red, a red arrow pulses from the bottle into the
## heart, and red drops fall from the heart; all faster the soberer.
func _draw_hangover_warning() -> void:
	var drain := GameState.hangover_drain()
	if drain <= 0.0 or mode != "":
		return
	var k := clampf(drain / GameState.HANGOVER_DRAIN_MAX, 0.25, 1.0)
	var t := Time.get_ticks_msec() / 1000.0
	var blink := 0.5 + 0.5 * sin(t * (5.0 + 6.0 * k))
	var red := Color(1.0, 0.15, 0.15)
	# Bottle outline blinking red.
	var bo := Vector2(118, 10)
	var pts := PackedVector2Array()
	for p in [Vector2(-7, 0), Vector2(7, 0), Vector2(7, 20), Vector2(22, 36), Vector2(22, 100),
			Vector2(-22, 100), Vector2(-22, 36), Vector2(-7, 20), Vector2(-7, 0)]:
		pts.append(bo + Vector2(22, 0) + p)
	draw_polyline(pts, Color(red.r, red.g, red.b, 0.4 + 0.6 * blink), 4.0, true)
	# Arrow from the bottle into the heart.
	var a0 := Vector2(112, 52)
	var a1 := Vector2(84, 52)
	var ac := Color(red.r, red.g, red.b, 0.5 + 0.5 * blink)
	draw_line(a0, a1 + Vector2(6, 0), ac, 4.0)
	draw_colored_polygon(PackedVector2Array([a1, a1 + Vector2(9, -7), a1 + Vector2(9, 7)]), ac)
	# Red glow round the heart and drops falling from it.
	draw_arc(Vector2(46, 46), 36.0, 0.0, TAU, 40, Color(red.r, red.g, red.b, 0.25 + 0.45 * blink), 3.0, true)
	for i in 3:
		var ph := fmod(t * (0.8 + 1.2 * k) + i / 3.0, 1.0)
		var dp := Vector2(40 + i * 6, 72 + ph * 30)
		draw_circle(dp, 3.5 * (1.0 - ph * 0.5), Color(0.85, 0.05, 0.1, 1.0 - ph))


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


## Dazzled by the sun: the player's own hand comes down into view and
## lies flat across the top of the screen like a visor, covering nearly
## its whole width: forearm in from the left edge, palm, and the fingers
## stretched out to the right, dark against the light. Thin bright lines
## of sun leak between the fingers and along the lower edge.
func _draw_shading_hand(vs: Vector2) -> void:
	if main == null or mode != "" or GameState.modal != "":
		return
	var amt: float = main.shade_amount()
	if amt <= 0.01:
		return
	var W := vs.x
	var H := vs.y
	# Slides down from above the screen as the glare grows.
	var oy := lerpf(-H * 0.26, 0.0, amt)
	var pt := func(x: float, y: float) -> Vector2:
		return Vector2(x * W, oy + y * H)
	var col := Color(0.3, 0.22, 0.19, 0.97 * amt)
	var soft := Color(col.r, col.g, col.b, col.a * 0.35)
	var g := 0.008 * H
	for pass_i in 2:
		var c := soft if pass_i == 0 else col
		var e := g if pass_i == 0 else 0.0
		# Forearm from the left edge, wrist, palm (up to the screen top).
		draw_colored_polygon(PackedVector2Array([pt.call(-0.02, -0.05) + Vector2(-e, -e),
			pt.call(0.24, -0.05) + Vector2(e, -e), pt.call(0.25, 0.125) + Vector2(e, e),
			pt.call(-0.02, 0.15) + Vector2(-e, e)]), c)
		draw_colored_polygon(PackedVector2Array([pt.call(0.22, -0.05) + Vector2(-e, -e),
			pt.call(0.56, -0.05) + Vector2(e, -e), pt.call(0.57, 0.175) + Vector2(e, e),
			pt.call(0.24, 0.17) + Vector2(-e, e)]), c)
		draw_circle(pt.call(0.56, 0.06), 0.11 * H + e, c)
		# Four fingers flat to the right, a hair apart, middle one longest.
		var fingers := [[0.02, 0.86], [0.065, 0.93], [0.11, 0.9], [0.155, 0.8]]
		var fw := 0.044 * H + e * 2.0
		for f in fingers:
			var a: Vector2 = pt.call(0.52, f[0])
			var b: Vector2 = pt.call(f[1], f[0] + 0.004)
			draw_line(a, b, c, fw)
			draw_circle(b, fw * 0.5, c)
		# Thumb tucked under the palm.
		var t0: Vector2 = pt.call(0.3, 0.16)
		var t1: Vector2 = pt.call(0.44, 0.215)
		draw_line(t0, t1, c, 0.05 * H + e * 2.0)
		draw_circle(t1, 0.025 * H + e, c)
	# Sun leaking between the fingers and along the lower edge.
	var leak := Color(1, 0.92, 0.72, 0.35 * amt)
	for y in [0.0425, 0.0875, 0.1325]:
		draw_line(pt.call(0.6, y), pt.call(0.82, y + 0.003), leak, 1.5)
	draw_line(pt.call(0.25, 0.178), pt.call(0.56, 0.182), Color(1, 0.92, 0.72, 0.2 * amt), 2.0)


## Found a lost thing: its icon pops up big in the middle with a green
## tick and a burst of rays, then shrinks away towards the find list at
## the top.
func _draw_found(vs: Vector2) -> void:
	if _found_t <= 0.0 or _found_id == "":
		return
	_found_t = maxf(0.0, _found_t - delta_draw_found())
	var k := 1.0 - _found_t / FOUND_TIME  # 0 -> 1
	# Pop in (overshoot), hold, then fly up to the list and fade.
	var pop := minf(k / 0.12, 1.0)
	var sc := pop * (1.0 + 0.25 * sin(pop * PI))
	var c := Vector2(vs.x * 0.5, vs.y * 0.38)
	var a := 1.0
	if k > 0.75:
		var f := (k - 0.75) / 0.25
		c = c.lerp(Vector2(vs.x * 0.5, 40), f)
		sc *= lerpf(1.0, 0.4, f)
		a = 1.0 - f
	var r := 70.0 * sc
	# Rays.
	for i in 12:
		var ang := TAU * float(i) / 12.0 + k * 1.5
		var d := Vector2.from_angle(ang)
		draw_line(c + d * r * 1.15, c + d * r * 1.6, Color(1, 0.9, 0.4, 0.8 * a), 5.0)
	draw_circle(c, r, Color(1, 1, 1, 0.92 * a))
	draw_arc(c, r, 0.0, TAU, 48, Color(0.3, 0.85, 0.35, a), 6.0, true)
	LostItems.draw_icon(self, _found_id, c, 90.0 * sc, "own")
	# Green tick at the lower right.
	var tc := c + Vector2(r * 0.62, r * 0.62)
	draw_circle(tc, 22.0 * sc, Color(0.25, 0.75, 0.3, a))
	draw_polyline(PackedVector2Array([tc + Vector2(-10, 0) * sc, tc + Vector2(-3, 8) * sc, tc + Vector2(11, -8) * sc]),
		Color(1, 1, 1, a), 5.0 * sc, true)


var _found_last_ms := 0


func delta_draw_found() -> float:
	var now := Time.get_ticks_msec()
	var d := 0.0 if _found_last_ms == 0 else float(now - _found_last_ms) / 1000.0
	_found_last_ms = now
	return minf(d, 0.1)


## Next to a beggar or a street drunk: what the button does there.
##   beggar: [button] -> coin -> "?" (a tip)
##   drunk:  [button] -> coin / sausage -> bottle (a sip)
func _draw_trade_hint() -> void:
	if main == null or main.player == null or mode != "" or GameState.modal != "":
		return
	var n = main.trader_near(main.player.position, 1.6)
	if n == null or n.trades_left <= 0:
		return
	var p: Vector3 = n.position + Vector3(0, 1.5 if n.model.sitting else 2.5, 0)
	if main.camera.is_position_behind(p):
		return
	var sp: Vector2 = main.camera.unproject_position(p)
	draw_rect(Rect2(sp - Vector2(58, 15), Vector2(116, 30)), Color(0, 0, 0, 0.4))
	_hint_button(sp + Vector2(-38, 0), false, 1.0)
	_hint_arrow(sp + Vector2(-8, 0), 1.0)
	# A coin.
	var cc := sp + Vector2(14, 0)
	draw_circle(cc, 9.0, Color(0.95, 0.75, 0.2))
	draw_arc(cc, 9.0, 0.0, TAU, 20, Color(0.5, 0.35, 0.05), 1.5, true)
	if n.role == "beggar":
		var font := get_theme_default_font()
		draw_string_outline(font, sp + Vector2(28, 8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color.BLACK)
		draw_string(font, sp + Vector2(28, 8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	else:
		_hint_action(sp + Vector2(40, 0), "ACT_DRINK", 1.0)


## Home: in the home block a pulsing green house and "Koti" float above
## the door; the first time each day the player gets close, "Löysit
## kotiin!" pops up in the middle; right at the door: [button] -> bed.
var _home_seen_day := -1
var _home_flash_t := 0.0
## The day the player was last away from the door. The welcome only pops
## up after leaving, so it does not show when the day starts at home.
var _home_left_day := -1


func _draw_home_hint(vs: Vector2, font: Font) -> void:
	if main == null or main.player == null or mode != "" or GameState.modal != "":
		return
	if main.segment != GameState.home_seg:
		_home_left_day = GameState.day
		return
	var pl = main.player
	var dx: float = absf(pl.position.x - GameState.home_x)
	var t := Time.get_ticks_msec() / 1000.0
	if dx >= 4.0:
		_home_left_day = GameState.day
	# Arrived: a big welcome once a day (not when the day starts at home).
	if dx < 4.0 and _home_seen_day != GameState.day and _home_left_day == GameState.day:
		_home_seen_day = GameState.day
		_home_flash_t = 2.5
	if _home_flash_t > 0.0:
		_home_flash_t -= get_process_delta_time()
		var a := clampf(_home_flash_t / 0.6, 0.0, 1.0)
		var msg := tr("HOME_FOUND")
		draw_string_outline(font, Vector2(0, vs.y * 0.3), msg, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 54, 12,
			Color(0, 0, 0, 0.8 * a))
		draw_string(font, Vector2(0, vs.y * 0.3), msg, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 54, Color(0.5, 1.0, 0.55, a))
	# The house above the door.
	var p := Vector3(GameState.home_x, 3.0, -7.4)
	if main.camera.is_position_behind(p):
		return
	var sp: Vector2 = main.camera.unproject_position(p)
	var k := 1.0 + 0.1 * sin(t * 4.0)
	var house := Color(0.3, 0.9, 0.45)
	draw_circle(sp, 30.0 * k, Color(0.2, 0.9, 0.4, 0.25))
	draw_rect(Rect2(sp + Vector2(-13, -4) * k, Vector2(26, 20) * k), house)
	draw_colored_polygon(PackedVector2Array([sp + Vector2(-18, -3) * k, sp + Vector2(0, -21) * k,
		sp + Vector2(18, -3) * k]), house)
	draw_rect(Rect2(sp + Vector2(-4, 5) * k, Vector2(8, 11) * k), Color(0.1, 0.1, 0.1, 0.8))
	var lbl := tr("HOME_LABEL")
	draw_string_outline(font, sp + Vector2(-60, 38), lbl, HORIZONTAL_ALIGNMENT_CENTER, 120, 22, 6, Color.BLACK)
	draw_string(font, sp + Vector2(-60, 38), lbl, HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Color(0.6, 1.0, 0.65))
	# Right at the door: the button goes to bed.
	if dx <= 0.9 and pl.position.z <= -6.0:
		var c := sp + Vector2(0, 68)
		draw_rect(Rect2(c - Vector2(46, 15), Vector2(92, 30)), Color(0, 0, 0, 0.45))
		_hint_button(c + Vector2(-24, 0), false, 1.0)
		_hint_arrow(c + Vector2(6, 0), 1.0)
		# A little bed.
		var b := c + Vector2(28, 2)
		draw_rect(Rect2(b + Vector2(-11, -2), Vector2(22, 7)), Color(0.85, 0.85, 0.95))
		draw_rect(Rect2(b + Vector2(-11, -6), Vector2(7, 5)), Color(1, 1, 1))
		draw_rect(Rect2(b + Vector2(-12, 5), Vector2(3, 5)), Color(0.5, 0.35, 0.2))
		draw_rect(Rect2(b + Vector2(9, 5), Vector2(3, 5)), Color(0.5, 0.35, 0.2))
	elif dx < 4.0 and pl.position.z > -6.0:
		# Close but out on the street: an arrow towards the door.
		var ac := sp + Vector2(0, 62 + sin(t * 6.0) * 4.0)
		draw_colored_polygon(PackedVector2Array([ac + Vector2(0, -10), ac + Vector2(-9, 4), ac + Vector2(9, 4)]),
			Color(0.6, 1.0, 0.65))


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
	var w := minf(vs.x * 0.85, 900.0)
	var h := minf(vs.y * 0.9, 620.0)
	var r := Rect2((vs - Vector2(w, h)) * 0.5, Vector2(w, h))
	draw_rect(r, Color(0.97, 0.95, 0.87))
	# Masthead (fictional local paper).
	draw_rect(Rect2(r.position, Vector2(w, 64)), Color(0.85, 0.1, 0.12))
	draw_string(font, r.position + Vector2(0, 46), tr("PAPER_NAME"), HORIZONTAL_ALIGNMENT_CENTER, w, 38, Color.WHITE)
	# Headline: as big as fits on two lines.
	var title := card_title.to_upper()
	var tw := w - 60.0
	var fs := 40
	while fs > 20:
		var th := font.get_multiline_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, tw, fs).y
		if th <= font.get_height(fs) * 2.05:
			break
		fs -= 2
	var head_top := r.position.y + 76.0
	var head_h := font.get_multiline_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, tw, fs).y
	draw_multiline_string(font, Vector2(r.position.x + 30, head_top + font.get_ascent(fs)), title,
		HORIZONTAL_ALIGNMENT_CENTER, tw, fs, -1, Color(0.08, 0.08, 0.08))
	# Bottom: a rule and the score; the photo and caption fit in between.
	var rule_y := r.end.y - 66.0
	var ph_top := head_top + head_h + 14.0
	var ph_h := maxf(rule_y - 30.0 - ph_top, 60.0)
	var ph := Rect2(Vector2(r.position.x + 30, ph_top), Vector2(ph_h * 480.0 / 330.0, ph_h))
	if ph.size.x > w * 0.6:
		ph.size = Vector2(w * 0.6, w * 0.6 * 330.0 / 480.0)
	_draw_photo(ph)
	draw_string(font, Vector2(ph.position.x, ph.end.y + 18), tr("PHOTO_CREDIT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.35, 0.35, 0.35))
	if _death_caption != "":
		var cx := ph.end.x + 22
		draw_multiline_string(font, Vector2(cx, ph.position.y + font.get_ascent(20)), _death_caption,
			HORIZONTAL_ALIGNMENT_LEFT, r.end.x - cx - 26, 20, -1, Color(0.15, 0.15, 0.15))
	draw_line(Vector2(r.position.x + 30, rule_y), Vector2(r.end.x - 30, rule_y), Color(0.2, 0.2, 0.2), 2.0)
	draw_string(font, Vector2(r.position.x, r.end.y - 22), card_sub, HORIZONTAL_ALIGNMENT_CENTER, w, 30,
		Color(0.1, 0.1, 0.1))
	# "Press to play again" as an icon: the action button with a play arrow.
	if card_time > 1.0:
		var bc := r.position + Vector2(w - 50, h - 50)
		draw_circle(bc, 24.0, Color(0.85, 0.1, 0.12))
		draw_colored_polygon(PackedVector2Array([bc + Vector2(-7, -11), bc + Vector2(12, 0), bc + Vector2(-7, 11)]), Color.WHITE)


## The death photo and its caption (set before the card shows).
var _death_photo: Texture2D = null
var _death_caption := ""


func set_death_photo(tex: Texture2D, caption: String) -> void:
	_death_photo = tex
	_death_caption = caption


## Placeholder "news photo": the character's silhouette in a grey frame.
func _draw_photo(r: Rect2) -> void:
	if _death_photo != null:
		draw_texture_rect(_death_photo, r, false)
		draw_rect(r, Color(0.15, 0.15, 0.15), false, 3.0)
		return
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
	# Everything found: now find the way home (pulsing house + text).
	var all_found := true
	for id in _today:
		if GameState.is_lost(id):
			all_found = false
	if all_found:
		var text := tr("GO_HOME")
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var bw := tw + 90.0
		var br := Rect2(Vector2((vs.x - bw) * 0.5, 10), Vector2(bw, 60))
		draw_rect(br, Color(0, 0, 0, 0.45))
		var hc := Vector2(br.position.x + 34, br.get_center().y + 2)
		var k := 1.0 + 0.08 * sin(Time.get_ticks_msec() / 200.0)
		var house := Color(0.25, 0.8, 0.4)
		draw_rect(Rect2(hc + Vector2(-13, -6) * k, Vector2(26, 20) * k), house)
		draw_colored_polygon(PackedVector2Array([hc + Vector2(-18, -5) * k, hc + Vector2(0, -22) * k,
			hc + Vector2(18, -5) * k]), house)
		draw_rect(Rect2(hc + Vector2(-4, 3) * k, Vector2(8, 11) * k), Color(0.1, 0.1, 0.1, 0.8))
		var tp := Vector2(br.position.x + 64, br.get_center().y + 9)
		draw_string_outline(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color.BLACK)
		draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.6, 1.0, 0.65))
		return
	var size := 44.0
	var gap := 12.0
	var label := tr("FIND")
	var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var icons_w := _today.size() * size + (_today.size() - 1) * gap
	# The warmest thing still missing gives the word (Cold ... Burning!).
	var hottest := 0.0
	for id in _today:
		if GameState.is_lost(id):
			hottest = maxf(hottest, warmth(id))
	var word := tr(_warm_key(hottest))
	var word_w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var w := label_w + 16.0 + icons_w + 26.0 + word_w + 26.0
	var r := Rect2(Vector2((vs.x - w) * 0.5, 10), Vector2(w, size + 30))
	draw_rect(r, Color(0, 0, 0, 0.45))
	var ty := r.position.y + 8 + size * 0.5 + 9
	draw_string_outline(font, Vector2(r.position.x + 18, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color.BLACK)
	draw_string(font, Vector2(r.position.x + 18, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.9, 0.4))
	var x := r.position.x + 18 + label_w + 16 + size * 0.5
	for id in _today:
		var c := Vector2(x, r.position.y + 8 + size * 0.5)
		draw_circle(c, size * 0.55, Color(1, 1, 1, 0.15))
		# Hot or cold: the nearer the thing, the warmer and faster the glow
		# behind its icon, and the fuller and redder the thermometer under it.
		if GameState.is_lost(id) and GameState.placements.has(id):
			var warm := warmth(id)
			var bar := Rect2(c + Vector2(-size * 0.45, size * 0.5 + 6), Vector2(size * 0.9, 7))
			draw_rect(bar, Color(0.1, 0.1, 0.15, 0.85))
			var fill := maxf(warm, 0.08)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)),
				Color(0.3, 0.55, 1.0).lerp(Color(1.0, 0.2, 0.1), warm))
			draw_rect(bar, Color(1, 1, 1, 0.5), false, 1.0)
			if warm > 0.0:
				var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * lerpf(2.0, 12.0, warm))
				var wc := Color(1.0, lerpf(0.7, 0.2, warm), 0.1, (0.25 + 0.5 * pulse) * warm)
				draw_circle(c, size * (0.6 + 0.12 * pulse * warm), wc)
		var m := "own"
		if GameState.is_lost(id):
			m = "blob" if _forgotten(id) else "lost"
		LostItems.draw_icon(self, id, c, size, m)
		if m == "own":
			# Found: a green tick.
			draw_polyline(PackedVector2Array([c + Vector2(6, 10), c + Vector2(12, 16), c + Vector2(22, 2)]),
				Color(0.3, 0.95, 0.3), 4.0, true)
		x += size + gap
	# The word for the warmest missing thing.
	var word_col := Color(0.55, 0.75, 1.0).lerp(Color(1.0, 0.35, 0.2), hottest)
	var wp := Vector2(r.end.x - word_w - 22, ty)
	draw_string_outline(font, wp, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color.BLACK)
	draw_string(font, wp, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, word_col)


## How near a missing thing is, 0 (cold: over 2 blocks away) .. 1 (right
## here). Within the same block by metres, otherwise by blocks.
func warmth(id: String) -> float:
	if main == null or not GameState.placements.has(id):
		return 0.0
	var pl: Array = GameState.placements[id]
	if pl[0] == main.segment:
		var pos: Vector3 = pl[1]
		var d := Vector2(pos.x - main.player.position.x, pos.z - main.player.position.z).length()
		return lerpf(0.75, 1.0, 1.0 - clampf(d / 20.0, 0.0, 1.0))
	var bd: float = GameState.seg_distance(main.segment, pl[0])
	return clampf(0.75 - (bd - 0.5) * 0.3, 0.0, 0.6)


func _warm_key(w: float) -> String:
	if w >= 0.9:
		return "WARM_5"
	if w >= 0.72:
		return "WARM_4"
	if w >= 0.4:
		return "WARM_3"
	if w > 0.1:
		return "WARM_2"
	return "WARM_1"


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
