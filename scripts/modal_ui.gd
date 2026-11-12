extends Control
## Full-screen overlays that freeze the world: the phone and the shop
## counter (kiosk / bar). Drawn with shapes and icons, very little text.

const LostItems = preload("res://scripts/lost_items.gd")
const CityMap = preload("res://scripts/city_map.gd")
const BlockBuilder = preload("res://scripts/block_builder.gd")

var main


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main == null:
		return
	var vs := get_viewport_rect().size
	match GameState.modal:
		"phone":
			_draw_phone(vs)
		"shop":
			_draw_shop(vs)
		"breath":
			_draw_breathalyser(vs)


## Breath test: a hand-held breathalyser; the reading climbs to the real
## per mille, then turns green (OK) or red (over the limit).
func _draw_breathalyser(vs: Vector2) -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.35))
	var h := minf(vs.y * 0.6, 360.0)
	var w := h * 0.5
	var body := Rect2(Vector2((vs.x - w) * 0.5, (vs.y - h) * 0.5), Vector2(w, h))
	# Mouthpiece on top, then the body.
	draw_rect(Rect2(Vector2(body.get_center().x - w * 0.08, body.position.y - h * 0.18), Vector2(w * 0.16, h * 0.2)),
		Color(0.92, 0.92, 0.95))
	draw_rect(body, Color(0.95, 0.75, 0.1))
	draw_rect(body, Color(0.2, 0.2, 0.2), false, 3.0)
	var scr := Rect2(body.position + Vector2(w * 0.1, h * 0.12), Vector2(w * 0.8, h * 0.28))
	var t: float = main.breath_progress()
	var reading := GameState.promille * clampf(t / 0.7, 0.0, 1.0)
	var done := t >= 0.75
	var over := GameState.promille > GameState.CHECKPOINT_LIMIT
	var bg := Color(0.15, 0.2, 0.15)
	if done:
		bg = Color(0.85, 0.15, 0.12) if over else Color(0.2, 0.7, 0.3)
	draw_rect(scr, bg)
	var txt := ("%.2f ‰" % reading).replace(".", ",")
	draw_string(font, Vector2(scr.position.x, scr.get_center().y + 14), txt, HORIZONTAL_ALIGNMENT_CENTER, scr.size.x,
		int(h * 0.11), Color(0.7, 1.0, 0.7) if not done else Color.WHITE)
	# Blowing: little puffs into the mouthpiece until the reading is done.
	if not done:
		for i in 3:
			var ph := fmod(t * 4.0 + i * 0.33, 1.0)
			draw_circle(Vector2(body.get_center().x + (i - 1) * 14, body.position.y - h * 0.22 - ph * 30.0),
				5.0 + ph * 4.0, Color(1, 1, 1, 0.6 * (1.0 - ph)))
	else:
		var c := Vector2(body.get_center().x, body.position.y + h * 0.65)
		if over:
			# Handcuffs: two rings and a chain.
			draw_arc(c + Vector2(-22, 0), 16.0, 0, TAU, 24, Color(0.2, 0.2, 0.22), 5.0, true)
			draw_arc(c + Vector2(22, 0), 16.0, 0, TAU, 24, Color(0.2, 0.2, 0.22), 5.0, true)
			draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), Color(0.2, 0.2, 0.22), 4.0)
		else:
			draw_line(c + Vector2(-20, 0), c + Vector2(-5, 15), Color(0.1, 0.5, 0.2), 7.0)
			draw_line(c + Vector2(-5, 15), c + Vector2(22, -16), Color(0.1, 0.5, 0.2), 7.0)


# --- Phone ------------------------------------------------------------------

## Size of the phone held sideways on touch screens (before scaling up).
const PHONE_WIDE := Vector2(600, 338)


func _draw_phone(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.45))
	var body: Rect2
	var scr: Rect2
	var wide := DisplayServer.is_touchscreen_available()
	if wide:
		# On a phone the game's phone is held sideways and scaled up to
		# nearly the full screen height, text and icons with it (a
		# portrait phone on a landscape phone screen was tiny).
		var k := minf(vs.y * 0.96 / PHONE_WIDE.y, vs.x * 0.86 / (PHONE_WIDE.x + 90.0))
		draw_set_transform(vs * 0.5, 0.0, Vector2(k, k))
		body = Rect2(-PHONE_WIDE * 0.5, PHONE_WIDE)
		draw_rect(body, Color(0.08, 0.08, 0.1))
		scr = body.grow(-10.0)
		scr.position.x += 18.0
		scr.size.x -= 36.0
	else:
		var h := minf(vs.y * 0.9, 560.0)
		var w := h * 0.56
		body = Rect2((vs - Vector2(w, h)) * 0.5, Vector2(w, h))
		draw_rect(body, Color(0.08, 0.08, 0.1))
		scr = body.grow(-12.0)
		scr.position.y += 18.0
		scr.size.y -= 36.0
	draw_rect(scr, Color(0.95, 0.95, 0.97))
	# Status bar: battery and page dots.
	_draw_battery(Vector2(scr.end.x - 46, scr.position.y + 8), GameState.battery)
	for i in 3:
		var c := Vector2(scr.get_center().x + (i - 1) * 16, scr.end.y - 12)
		draw_circle(c, 4.0, Color(0.2, 0.2, 0.25) if i == main.phone_page else Color(0.75, 0.75, 0.8))
	if main.phone_dead_t > 0.0:
		_draw_dead_battery(scr)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var content := Rect2(scr.position + Vector2(8, 30), scr.size - Vector2(16, 56))
	match main.phone_page:
		0:
			_draw_messages(content)
		1:
			_draw_photo(content)
		2:
			_draw_map(content)
	# Arrows hint that the views scroll sideways.
	var mid := body.get_center().y
	_arrow(Vector2(body.position.x - 22, mid), -1)
	_arrow(Vector2(body.end.x + 22, mid), 1)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Dark screen with a big empty battery blinking in red.
func _draw_dead_battery(scr: Rect2) -> void:
	draw_rect(scr, Color(0.03, 0.03, 0.04))
	if int(main.phone_dead_t * 4.0) % 2 == 1:
		return
	var c := scr.get_center()
	var w := scr.size.x * 0.45
	var h := w * 0.45
	var red := Color(0.95, 0.15, 0.15)
	draw_rect(Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h)), red, false, 5.0)
	draw_rect(Rect2(c + Vector2(w * 0.5, -h * 0.18), Vector2(w * 0.08, h * 0.36)), red)
	draw_rect(Rect2(c + Vector2(-w * 0.5 + 8, -h * 0.5 + 8), Vector2(w * 0.08, h - 16)), red)


func _draw_battery(p: Vector2, pct: float) -> void:
	draw_rect(Rect2(p, Vector2(34, 14)), Color(0.2, 0.2, 0.2), false, 2.0)
	draw_rect(Rect2(p + Vector2(34, 4), Vector2(3, 6)), Color(0.2, 0.2, 0.2))
	var col := Color(0.85, 0.15, 0.15) if pct < 10.0 else Color(0.2, 0.7, 0.3)
	draw_rect(Rect2(p + Vector2(2, 2), Vector2(30.0 * clampf(pct / 100.0, 0.0, 1.0), 10)), col)


func _arrow(c: Vector2, dir: int) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(dir * 10, 0), c + Vector2(-dir * 6, -10),
		c + Vector2(-dir * 6, 10)]), Color(1, 1, 1, 0.7))


## Messages: only the beginnings are visible, like a chat list. Each row is
## an avatar, an icon and the start of a street name.
func _draw_messages(r: Rect2) -> void:
	var font := get_theme_default_font()
	if main.ex_call_available():
		# The temptation: her picture, a pulsing call button and a heart.
		var row := Rect2(r.position, Vector2(r.size.x, 58))
		draw_rect(row, Color(1.0, 0.85, 0.88))
		var av := Vector2(r.position.x + 22, r.position.y + 29)
		draw_circle(av, 18.0, Color(0.8, 0.1, 0.12))
		draw_circle(av + Vector2(0, -3), 9.0, Color(0.95, 0.8, 0.7))
		draw_rect(Rect2(av + Vector2(-9, -14), Vector2(18, 6)), Color(0.2, 0.12, 0.08))
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
		var cb := Vector2(r.end.x - 30, r.position.y + 29)
		draw_circle(cb, 16.0 + 3.0 * pulse, Color(0.2, 0.75, 0.3))
		draw_line(cb + Vector2(-6, -5), cb + Vector2(6, 5), Color.WHITE, 4.0)
		draw_string(font, Vector2(r.position.x + 50, r.position.y + 37), "♥?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
			Color(0.8, 0.1, 0.2))
		r = Rect2(r.position + Vector2(0, 62), r.size - Vector2(0, 62))
	if GameState.phone_msgs.is_empty():
		_draw_envelope(r.get_center(), 60.0, Color(0.7, 0.7, 0.75))
		return
	var y := r.position.y
	var row_h := 58.0
	for m in GameState.phone_msgs:
		if y + row_h > r.end.y:
			break
		var street: String = m["street"]
		var avatar := Color.from_hsv(float(hash(street) % 360) / 360.0, 0.5, 0.85)
		draw_circle(Vector2(r.position.x + 22, y + row_h * 0.5), 18.0, avatar)
		var icon: String = m["icon"]
		var ic := Vector2(r.position.x + 66, y + row_h * 0.5)
		if icon == "":
			_draw_beer_icon(ic, 30.0)
		elif icon == "task_food":
			_draw_product("food", ic, 40.0)
		elif icon == "task_bottle":
			_draw_product("bottle", ic, 40.0)
		else:
			LostItems.draw_icon(self, icon, ic, 34.0, "own")
		var start := street.substr(0, mini(street.length(), 7)) + "…"
		draw_string(font, Vector2(r.position.x + 92, y + row_h * 0.5 + 7), start, HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - 96, 20, Color(0.25, 0.25, 0.3))
		draw_line(Vector2(r.position.x, y + row_h), Vector2(r.end.x, y + row_h), Color(0.85, 0.85, 0.88), 1.0)
		y += row_h


func _draw_envelope(c: Vector2, s: float, col: Color) -> void:
	draw_rect(Rect2(c - Vector2(s, s * 0.65) * 0.5, Vector2(s, s * 0.65)), col, false, 3.0)
	draw_polyline(PackedVector2Array([c + Vector2(-s, -s * 0.65) * 0.5, c + Vector2(0, s * 0.05),
		c + Vector2(s, -s * 0.65) * 0.5]), col, 3.0)


func _draw_beer_icon(c: Vector2, s: float) -> void:
	draw_rect(Rect2(c - Vector2(s * 0.3, s * 0.35), Vector2(s * 0.6, s * 0.75)), Color(0.95, 0.7, 0.2))
	draw_rect(Rect2(c - Vector2(s * 0.32, s * 0.5), Vector2(s * 0.64, s * 0.18)), Color(1, 1, 1))
	draw_arc(c + Vector2(s * 0.38, 0), s * 0.15, -PI * 0.5, PI * 0.5, 10, Color(0.95, 0.7, 0.2), 3.0)


## Yesterday's photo: the place (a street sign is visible) and the lost
## thing lying there, plus the character with something conveniently
## blurry in front.
func _draw_photo(r: Rect2) -> void:
	var p: Dictionary = GameState.phone_photo
	if p.is_empty():
		draw_rect(r, Color(0.85, 0.85, 0.88))
		var c := r.get_center()
		draw_rect(Rect2(c - Vector2(30, 20), Vector2(60, 40)), Color(0.6, 0.6, 0.65), false, 3.0)
		draw_arc(c, 12.0, 0, TAU, 20, Color(0.6, 0.6, 0.65), 3.0)
		draw_line(c - Vector2(40, 30), c + Vector2(40, 30), Color(0.85, 0.2, 0.2), 4.0)
		return
	var seg: Vector3i = p["seg"]
	var rng := RandomNumberGenerator.new()
	rng.seed = CityMap.seed_of(seg)
	var ground_y := r.position.y + r.size.y * 0.72
	draw_rect(Rect2(r.position, Vector2(r.size.x, ground_y - r.position.y)), Color(0.55, 0.72, 0.9))
	var x := r.position.x
	while x < r.end.x:
		var bw := rng.randf_range(50.0, 90.0)
		var bh := rng.randf_range(r.size.y * 0.35, r.size.y * 0.6)
		var col := Color.from_hsv(rng.randf_range(0.05, 0.15), 0.35, rng.randf_range(0.7, 0.95))
		draw_rect(Rect2(Vector2(x, ground_y - bh), Vector2(minf(bw, r.end.x - x), bh)), col)
		x += bw
	draw_rect(Rect2(Vector2(r.position.x, ground_y), Vector2(r.size.x, r.end.y - ground_y)), Color(0.55, 0.53, 0.5))
	# Street sign.
	var font := get_theme_default_font()
	var street: String = p["street"]
	var sw := minf(r.size.x - 20, street.length() * 11.0 + 16)
	var sp := Vector2(r.position.x + 10, ground_y - 120)
	draw_line(sp + Vector2(sw * 0.5, 22), sp + Vector2(sw * 0.5, 120), Color(0.3, 0.3, 0.33), 4.0)
	draw_rect(Rect2(sp, Vector2(sw, 24)), Color(0.1, 0.3, 0.7))
	draw_string(font, sp + Vector2(0, 18), street, HORIZONTAL_ALIGNMENT_CENTER, sw, 16, Color.WHITE)
	# The lost thing on the ground.
	LostItems.draw_icon(self, p["id"], Vector2(r.position.x + r.size.x * 0.3, ground_y + 26), 40.0, "own")
	# The character posing, with a "lucky" blurry thing in front.
	var hc := Vector2(r.position.x + r.size.x * 0.7, ground_y - 10)
	var dark := Color(0.25, 0.22, 0.25)
	draw_circle(hc + Vector2(0, -78), 13.0, Color(0.95, 0.8, 0.68))
	draw_rect(Rect2(hc + Vector2(-16, -64), Vector2(32, 44)), Color(0.95, 0.8, 0.68))
	draw_rect(Rect2(hc + Vector2(-14, -20), Vector2(11, 30)), dark)
	draw_rect(Rect2(hc + Vector2(3, -20), Vector2(11, 30)), dark)
	draw_line(hc + Vector2(16, -60), hc + Vector2(34, -86), Color(0.95, 0.8, 0.68), 7.0)
	for i in 6:
		draw_circle(hc + Vector2(-4 + i * 2, -34 + (i % 2) * 4), 18.0 - i, Color(0.4, 0.75, 0.4, 0.35))


## Map: the city grid seen from above (north up), with the character's
## current position. Uses the most battery.
func _draw_map(r: Rect2) -> void:
	var font := get_theme_default_font()
	draw_rect(r, Color(0.93, 0.92, 0.88))
	var na := CityMap.streets(0).size()
	var nb := CityMap.streets(1).size()
	# Grid coords: u along A streets, v across them (screen directions from
	# the city's data; north up).
	var ne: Vector2 = CityMap.data()["map_u"]
	var se: Vector2 = CityMap.data()["map_v"]
	var span := float(maxi(na, nb))
	var scale := minf(r.size.x, r.size.y - 30) / (span * 1.45)
	var center := r.get_center() + Vector2(0, 14)
	var mid := Vector2((nb - 1) * 0.5, (na - 1) * 0.5)
	var to_screen := func(u: float, v: float) -> Vector2:
		return center + (ne * (u - mid.x) + se * (v - mid.y)) * scale
	# The sea beyond the shore street.
	var sea := PackedVector2Array([to_screen.call(-1.0, -0.4), to_screen.call(float(nb), -0.4),
		to_screen.call(float(nb), -2.0), to_screen.call(-1.0, -2.0)])
	draw_colored_polygon(sea, Color(0.6, 0.78, 0.92))
	for i in na:
		draw_line(to_screen.call(0.0, float(i)), to_screen.call(nb - 1.0, float(i)), Color(0.6, 0.6, 0.62), 3.0)
	for j in nb:
		draw_line(to_screen.call(float(j), 0.0), to_screen.call(float(j), na - 1.0), Color(0.6, 0.6, 0.62), 3.0)
	# Roadworks: the closed block striped red and white, with a red cross.
	for cs in CityMap.closed:
		var ca: Vector2
		var cb: Vector2
		if cs.x == 0:
			ca = to_screen.call(float(cs.z), float(cs.y))
			cb = to_screen.call(cs.z + 1.0, float(cs.y))
		else:
			ca = to_screen.call(float(cs.y), float(cs.z))
			cb = to_screen.call(float(cs.y), cs.z + 1.0)
		var parts := 6
		for k in parts:
			var p0: Vector2 = ca.lerp(cb, float(k) / parts)
			var p1: Vector2 = ca.lerp(cb, float(k + 1) / parts)
			draw_line(p0, p1, Color(0.85, 0.12, 0.1) if k % 2 == 0 else Color(1, 1, 1), 6.0)
		var cm: Vector2 = (ca + cb) * 0.5
		draw_line(cm + Vector2(-6, -6), cm + Vector2(6, 6), Color(0.8, 0.05, 0.05), 3.0)
		draw_line(cm + Vector2(-6, 6), cm + Vector2(6, -6), Color(0.8, 0.05, 0.05), 3.0)
	# The pal's task: a little speech bubble on their block.
	var tk: Dictionary = GameState.task
	if not tk.is_empty() and not tk["done"]:
		var ts: Vector3i = tk["seg"]
		var tf := clampf((float(tk["x"]) + 16.0) / 32.0, 0.0, 1.0)
		var tc: Vector2 = to_screen.call(ts.z + tf, float(ts.y)) if ts.x == 0 else to_screen.call(float(ts.y), ts.z + tf)
		draw_circle(tc + Vector2(0, -12), 9.0, Color(1, 1, 1, 0.95))
		draw_colored_polygon(PackedVector2Array([tc + Vector2(-3, -5), tc + Vector2(3, -5), tc]), Color(1, 1, 1, 0.95))
		draw_circle(tc + Vector2(0, -12), 4.0, Color(0.78, 0.32, 0.25) if tk["want"] == "food" else Color(0.2, 0.5, 0.25))
	# Breath test checkpoint: a blinking blue dot in the middle of the block.
	for ks in GameState.checkpoint_segs:
		var kc: Vector2 = to_screen.call(ks.z + 0.5, float(ks.y)) if ks.x == 0 else to_screen.call(float(ks.y), ks.z + 0.5)
		var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
		draw_circle(kc, 8.0, Color(0.15, 0.35, 1.0, 0.5 + 0.5 * blink))
		draw_circle(kc, 4.0, Color(1, 1, 1, 0.9))
	# Home: a little house at the home door's position.
	var hs: Vector3i = GameState.home_seg
	var hf := clampf((GameState.home_x + 16.0) / 32.0, 0.0, 1.0)
	var hp: Vector2 = to_screen.call(hs.z + hf, float(hs.y)) if hs.x == 0 else to_screen.call(float(hs.y), hs.z + hf)
	var house := Color(0.15, 0.55, 0.3)
	draw_rect(Rect2(hp + Vector2(-7, -4), Vector2(14, 11)), house)
	draw_colored_polygon(PackedVector2Array([hp + Vector2(-10, -3), hp + Vector2(0, -13), hp + Vector2(10, -3)]), house)
	draw_rect(Rect2(hp + Vector2(-2, 1), Vector2(4, 6)), Color(0.93, 0.92, 0.88))
	# Hints: the block where a lost thing lies, highlighted in orange, with
	# its icon in the middle.
	for h in GameState.phone_map_hints:
		if not GameState.is_lost(h["id"]):
			continue
		var hs2: Vector3i = h["seg"]
		var a: Vector2
		var b: Vector2
		if hs2.x == 0:
			a = to_screen.call(float(hs2.z), float(hs2.y))
			b = to_screen.call(hs2.z + 1.0, float(hs2.y))
		else:
			a = to_screen.call(float(hs2.y), float(hs2.z))
			b = to_screen.call(float(hs2.y), hs2.z + 1.0)
		var hint_a := 0.6 + 0.25 * sin(Time.get_ticks_msec() / 260.0)
		draw_line(a, b, Color(0.95, 0.55, 0.15, hint_a), 9.0)
		draw_circle(a, 4.5, Color(0.95, 0.55, 0.15, hint_a))
		draw_circle(b, 4.5, Color(0.95, 0.55, 0.15, hint_a))
		var hint_c := (a + b) * 0.5
		# Small: half the old size, on a thin light disc so the streets
		# and the orange block stay readable.
		draw_circle(hint_c, 6.5, Color(1, 1, 1, 0.75))
		LostItems.draw_icon(self, h["id"], hint_c, 10.0, "own")
	# Where am I.
	var seg: Vector3i = main.segment
	var f := clampf((main.player.position.x + 16.0) / 32.0, 0.0, 1.0)
	var pos: Vector2
	if seg.x == 0:
		pos = to_screen.call(seg.z + f, float(seg.y))
	else:
		pos = to_screen.call(float(seg.y), seg.z + f)
	var pulse := 7.0 + sin(Time.get_ticks_msec() / 150.0) * 2.0
	# Heading: which way along the street the character is going (facing),
	# a blue arrow out of the dot and a faint "view cone".
	var ahead: Vector2
	if seg.x == 0:
		ahead = to_screen.call(seg.z + f + 0.1, float(seg.y))
	else:
		ahead = to_screen.call(float(seg.y), seg.z + f + 0.1)
	var hd: Vector2 = (ahead - pos).normalized() * float(main.player.facing)
	var side := hd.orthogonal()
	draw_colored_polygon(PackedVector2Array([pos, pos + hd * 34.0 + side * 16.0, pos + hd * 34.0 - side * 16.0]),
		Color(0.2, 0.5, 1.0, 0.18))
	draw_circle(pos, pulse + 4.0, Color(0.2, 0.5, 1.0, 0.3))
	draw_colored_polygon(PackedVector2Array([pos + hd * 22.0, pos + hd * 10.0 + side * 7.0, pos + hd * 10.0 - side * 7.0]),
		Color(0.15, 0.4, 0.95))
	draw_circle(pos, 6.0, Color(0.15, 0.4, 0.95))
	draw_string(font, r.position + Vector2(0, 22), CityMap.street_name(seg), HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x, 20, Color(0.2, 0.2, 0.25))
	# North arrow.
	var nc := Vector2(r.end.x - 18, r.position.y + 44)
	draw_colored_polygon(PackedVector2Array([nc + Vector2(0, -12), nc + Vector2(7, 8), nc + Vector2(-7, 8)]),
		Color(0.8, 0.2, 0.2))


# --- Shop counter --------------------------------------------------------------

func _draw_shop(vs: Vector2) -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.45))
	var opts: Array = main.shop_options()
	var cell := 130.0
	var w := opts.size() * cell + 40.0
	var r := Rect2(Vector2((vs.x - w) * 0.5, vs.y * 0.35), Vector2(w, 190))
	var top: Color = BlockBuilder.SHOP_COLORS.get(main.shop_type, Color(0.35, 0.12, 0.4))
	draw_rect(r, Color(0.97, 0.95, 0.88))
	draw_rect(Rect2(r.position, Vector2(w, 34)), top)
	var key: String = BlockBuilder.SHOP_SIGNS.get(main.shop_type, "SIGN_BAR")
	draw_string(font, r.position + Vector2(0, 25), tr(key), HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color.WHITE)
	for i in opts.size():
		var o: Dictionary = opts[i]
		var c := Vector2(r.position.x + 20 + cell * (i + 0.5), r.position.y + 100)
		if i == main.shop_sel:
			draw_rect(Rect2(c - Vector2(cell * 0.45, 52), Vector2(cell * 0.9, 120)), Color(1.0, 0.85, 0.3, 0.5))
		_draw_product(o["kind"], c, 56.0)
		if o["price"] > 0:
			draw_string(font, c + Vector2(-cell * 0.5, 58), "%d €" % o["price"], HORIZONTAL_ALIGNMENT_CENTER, cell, 22, Color(0.15, 0.15, 0.15))
		else:
			# Costs time, not money: a clock.
			var cc := c + Vector2(0, 50)
			draw_arc(cc, 11.0, 0, TAU, 24, Color(0.15, 0.15, 0.15), 2.5, true)
			draw_line(cc, cc + Vector2(0, -8), Color(0.15, 0.15, 0.15), 2.5)
			draw_line(cc, cc + Vector2(6, 0), Color(0.15, 0.15, 0.15), 2.5)
	# Why buying failed: the missing thing, crossed out.
	if main.shop_flash != "" and main.shop_flash_t > 0.0:
		var fc := Vector2(r.get_center().x, r.end.y + 50)
		if main.shop_flash == "money":
			draw_circle(fc, 24.0, Color(0.95, 0.75, 0.2))
			draw_string(font, fc + Vector2(-24, 8), "€", HORIZONTAL_ALIGNMENT_CENTER, 48, 22, Color(0.45, 0.3, 0.05))
		else:
			LostItems.draw_icon(self, main.shop_flash, fc, 56.0, "lost")
		draw_line(fc - Vector2(28, 28), fc + Vector2(28, 28), Color(0.9, 0.1, 0.1), 6.0)
		draw_line(fc + Vector2(-28, 28), fc + Vector2(28, -28), Color(0.9, 0.1, 0.1), 6.0)
	# Down = leave.
	var dc := Vector2(r.get_center().x, r.end.y + 110)
	draw_colored_polygon(PackedVector2Array([dc + Vector2(0, 12), dc + Vector2(-12, -6), dc + Vector2(12, -6)]),
		Color(1, 1, 1, 0.7))


func _draw_product(kind: String, c: Vector2, s: float) -> void:
	match kind:
		"bottle":
			draw_rect(Rect2(c + Vector2(-s * 0.16, -s * 0.15), Vector2(s * 0.32, s * 0.6)), Color(0.18, 0.45, 0.2))
			draw_rect(Rect2(c + Vector2(-s * 0.07, -s * 0.45), Vector2(s * 0.14, s * 0.32)), Color(0.18, 0.45, 0.2))
		"food":
			draw_circle(c + Vector2(-s * 0.3, 0), s * 0.13, Color(0.78, 0.32, 0.25))
			draw_circle(c + Vector2(s * 0.3, 0), s * 0.13, Color(0.78, 0.32, 0.25))
			draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.13), Vector2(s * 0.6, s * 0.26)), Color(0.78, 0.32, 0.25))
		"charge":
			draw_rect(Rect2(c + Vector2(-s * 0.2, -s * 0.1), Vector2(s * 0.4, s * 0.35)), Color(0.9, 0.9, 0.9))
			draw_rect(Rect2(c + Vector2(-s * 0.13, -s * 0.32), Vector2(s * 0.06, s * 0.22)), Color(0.6, 0.6, 0.6))
			draw_rect(Rect2(c + Vector2(s * 0.07, -s * 0.32), Vector2(s * 0.06, s * 0.22)), Color(0.6, 0.6, 0.6))
			draw_line(c + Vector2(0, s * 0.25), c + Vector2(0, s * 0.45), Color(0.2, 0.2, 0.2), 4.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.05, -s * 0.05), c + Vector2(-s * 0.08, s * 0.1),
				c + Vector2(0, s * 0.1), c + Vector2(-s * 0.05, s * 0.22), c + Vector2(s * 0.08, s * 0.05),
				c + Vector2(0, s * 0.05)]), Color(0.95, 0.75, 0.1))
		"pint":
			_draw_beer_icon(c, s)
		"flower":
			draw_line(c + Vector2(0, s * 0.45), c + Vector2(0, -s * 0.1), Color(0.2, 0.55, 0.2), 4.0)
			draw_circle(c + Vector2(-s * 0.1, s * 0.15), s * 0.08, Color(0.25, 0.6, 0.25))
			draw_circle(c + Vector2(0, -s * 0.2), s * 0.17, Color(0.85, 0.08, 0.15))
			draw_arc(c + Vector2(0, -s * 0.2), s * 0.09, 0, TAU, 12, Color(0.6, 0.02, 0.08), 2.0)
		"plaster":
			# A plaster, slightly tilted, with the pad in the middle.
			var ax := Vector2(cos(-0.5), sin(-0.5))
			var ay := ax.orthogonal()
			var pts := PackedVector2Array()
			for v in [Vector2(-0.45, -0.15), Vector2(0.45, -0.15), Vector2(0.45, 0.15), Vector2(-0.45, 0.15)]:
				pts.append(c + (ax * v.x + ay * v.y) * s)
			draw_colored_polygon(pts, Color(0.93, 0.78, 0.62))
			var pad := PackedVector2Array()
			for v in [Vector2(-0.14, -0.12), Vector2(0.14, -0.12), Vector2(0.14, 0.12), Vector2(-0.14, 0.12)]:
				pad.append(c + (ax * v.x + ay * v.y) * s)
			draw_colored_polygon(pad, Color(0.98, 0.95, 0.9))
		"painkiller":
			# A medicine box: green with a white cross.
			draw_rect(Rect2(c + Vector2(-s * 0.35, -s * 0.25), Vector2(s * 0.7, s * 0.5)), Color(0.2, 0.6, 0.4))
			draw_rect(Rect2(c + Vector2(-s * 0.06, -s * 0.18), Vector2(s * 0.12, s * 0.36)), Color.WHITE)
			draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.06), Vector2(s * 0.36, s * 0.12)), Color.WHITE)
		"energy":
			draw_rect(Rect2(c + Vector2(-s * 0.16, -s * 0.4), Vector2(s * 0.32, s * 0.8)), Color(0.1, 0.1, 0.12))
			draw_rect(Rect2(c + Vector2(-s * 0.16, -s * 0.1), Vector2(s * 0.32, s * 0.22)), Color(0.4, 0.95, 0.2))
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.04, -s * 0.32), c + Vector2(-s * 0.08, -s * 0.12),
				c + Vector2(0, -s * 0.12), c + Vector2(-s * 0.04, s * 0.02), c + Vector2(s * 0.08, -s * 0.18),
				c + Vector2(0, -s * 0.18)]), Color(0.95, 0.85, 0.1))
