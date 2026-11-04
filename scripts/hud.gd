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


## Quick fade from black when the view changes to another block.
func fade_in() -> void:
	_fade = 1.0
	_fade_speed = 4.0


## Knocked out: the screen goes black and slowly comes back.
func blackout(seconds: float) -> void:
	_fade = 1.0
	_fade_speed = 1.0 / maxf(seconds, 0.1)


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
	_draw_charge()
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


func _draw_charge() -> void:
	if main == null or main.player == null:
		return
	var c: float = main.player.throw_charge()
	if c < 0.0:
		return
	var p: Vector3 = main.player.global_position + Vector3(0, 2.3, 0)
	if main.camera.is_position_behind(p):
		return
	var sp: Vector2 = main.camera.unproject_position(p)
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
	var level := 1 if p < 2.6 else (2 if p < 3.1 else 3)
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
