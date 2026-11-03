extends Control
## Full-screen overlays that freeze the world: the phone and the shop
## counter (kiosk / bar). Drawn with shapes and icons, very little text.

const LostItems = preload("res://scripts/lost_items.gd")
const CityMap = preload("res://scripts/city_map.gd")

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


# --- Phone ------------------------------------------------------------------

func _draw_phone(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.45))
	var h := minf(vs.y * 0.9, 560.0)
	var w := h * 0.56
	var body := Rect2((vs - Vector2(w, h)) * 0.5, Vector2(w, h))
	draw_rect(body, Color(0.08, 0.08, 0.1))
	var scr := body.grow(-12.0)
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
	var na := CityMap.A_STREETS.size()
	var nb := CityMap.B_STREETS.size()
	# Grid coords: u along A streets (towards NE), v across them (towards SE).
	var ne := Vector2(1, -1).normalized()
	var se := Vector2(1, 1).normalized()
	var span := float(maxi(na, nb))
	var scale := minf(r.size.x, r.size.y - 30) / (span * 1.45)
	var center := r.get_center() + Vector2(0, 14)
	var mid := Vector2((nb - 1) * 0.5, (na - 1) * 0.5)
	var to_screen := func(u: float, v: float) -> Vector2:
		return center + (ne * (u - mid.x) + se * (v - mid.y)) * scale
	# Sea on the NW side (beyond Rantakatu).
	var sea := PackedVector2Array([to_screen.call(-1.0, -0.4), to_screen.call(float(nb), -0.4),
		to_screen.call(float(nb), -2.0), to_screen.call(-1.0, -2.0)])
	draw_colored_polygon(sea, Color(0.6, 0.78, 0.92))
	for i in na:
		draw_line(to_screen.call(0.0, float(i)), to_screen.call(nb - 1.0, float(i)), Color(0.6, 0.6, 0.62), 3.0)
	for j in nb:
		draw_line(to_screen.call(float(j), 0.0), to_screen.call(float(j), na - 1.0), Color(0.6, 0.6, 0.62), 3.0)
	# Home: a little house at the home door's position.
	var hs: Vector3i = GameState.home_seg
	var hf := clampf((GameState.home_x + 16.0) / 32.0, 0.0, 1.0)
	var hp: Vector2 = to_screen.call(hs.z + hf, float(hs.y)) if hs.x == 0 else to_screen.call(float(hs.y), hs.z + hf)
	var house := Color(0.15, 0.55, 0.3)
	draw_rect(Rect2(hp + Vector2(-7, -4), Vector2(14, 11)), house)
	draw_colored_polygon(PackedVector2Array([hp + Vector2(-10, -3), hp + Vector2(0, -13), hp + Vector2(10, -3)]), house)
	draw_rect(Rect2(hp + Vector2(-2, 1), Vector2(4, 6)), Color(0.93, 0.92, 0.88))
	# Where am I.
	var seg: Vector3i = main.segment
	var f := clampf((main.player.position.x + 16.0) / 32.0, 0.0, 1.0)
	var pos: Vector2
	if seg.x == 0:
		pos = to_screen.call(seg.z + f, float(seg.y))
	else:
		pos = to_screen.call(float(seg.y), seg.z + f)
	var pulse := 7.0 + sin(Time.get_ticks_msec() / 150.0) * 2.0
	draw_circle(pos, pulse + 4.0, Color(0.2, 0.5, 1.0, 0.3))
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
	var top := Color(0.85, 0.15, 0.15) if main.shop_type == "kiosk" else Color(0.35, 0.12, 0.4)
	draw_rect(r, Color(0.97, 0.95, 0.88))
	draw_rect(Rect2(r.position, Vector2(w, 34)), top)
	var key := "SIGN_KIOSK" if main.shop_type == "kiosk" else "SIGN_BAR"
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
