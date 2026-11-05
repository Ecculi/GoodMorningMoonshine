extends CanvasLayer
## On-screen controls, shown only on touch screens: a virtual stick on
## the left (slide the finger: near the centre walks, out at the edge
## runs), the action button and the phone button on the right.
## Everything feeds the same input actions as the keyboard.

const ACTION_RADIUS := 72
const PHONE_RADIUS := 36

var _buttons := {}
var _stick


## Floating virtual stick: the base appears where the finger lands (in
## the lower left area) and the knob follows the finger. Deflection sets
## the move actions' strength; at the edge (over RUN_AT) the character
## runs.
class Stick extends Node2D:
	const RADIUS := 80.0
	const DEAD := 0.2
	const RUN_AT := 0.85
	var home := Vector2(170, 500)
	var area := Rect2()
	var _touch := -1
	var _base := Vector2.ZERO
	var _knob := Vector2.ZERO

	func _ready() -> void:
		visible = DisplayServer.is_touchscreen_available()

	func _input(event: InputEvent) -> void:
		if not visible:
			return
		if event is InputEventScreenTouch:
			if event.pressed and _touch < 0 and area.has_point(event.position):
				_touch = event.index
				_base = event.position
				_knob = event.position
				_apply()
			elif not event.pressed and event.index == _touch:
				_touch = -1
				_knob = _base
				_apply()
		elif event is InputEventScreenDrag and event.index == _touch:
			_knob = event.position
			_apply()

	func _apply() -> void:
		var d := Vector2.ZERO
		if _touch >= 0:
			d = (_knob - _base) / RADIUS
			if d.length() > 1.0:
				d = d.normalized()
				_knob = _base + d * RADIUS
		var mag := d.length()
		if mag < DEAD:
			d = Vector2.ZERO
		_press("move_right", maxf(d.x, 0.0))
		_press("move_left", maxf(-d.x, 0.0))
		_press("move_down", maxf(d.y, 0.0))
		_press("move_up", maxf(-d.y, 0.0))
		GameState.stick_run = mag >= RUN_AT
		queue_redraw()

	func _press(action: String, strength: float) -> void:
		if strength > 0.0:
			Input.action_press(action, strength)
		else:
			Input.action_release(action)

	func _draw() -> void:
		var b := _base if _touch >= 0 else home
		var k := _knob if _touch >= 0 else home
		draw_circle(b, RADIUS, Color(0.1, 0.1, 0.12, 0.3))
		draw_arc(b, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0, true)
		# Run ring: past it the character runs.
		draw_arc(b, RADIUS * RUN_AT, 0.0, TAU, 48, Color(1, 0.85, 0.3, 0.35), 2.0, true)
		draw_circle(k, 30.0, Color(1, 1, 1, 0.45 if _touch >= 0 else 0.3))


func _ready() -> void:
	layer = 11
	_stick = Stick.new()
	add_child(_stick)
	_add("action", ACTION_RADIUS, Vector2.ZERO)
	_add("phone", PHONE_RADIUS, Vector2.ZERO, true)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	_stick.home = Vector2(170, s.y - 170)
	_stick.area = Rect2(Vector2(0, s.y * 0.3), Vector2(s.x * 0.45, s.y * 0.7))
	_place("action", Vector2(s.x - 170, s.y - 170))
	_place("phone", Vector2(s.x - 110, s.y - 320))


func _add(action: String, radius: int, arrow: Vector2, phone_icon := false) -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = _circle_texture(radius, Color(0.1, 0.1, 0.12, 0.35), arrow, phone_icon)
	b.texture_pressed = _circle_texture(radius, Color(1, 1, 1, 0.35), arrow, phone_icon)
	var shape := CircleShape2D.new()
	shape.radius = radius
	b.shape = shape
	b.shape_centered = true
	b.action = action
	b.passby_press = action.begins_with("move_")
	b.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	add_child(b)
	_buttons[action] = b


func _place(action: String, center: Vector2) -> void:
	var b: TouchScreenButton = _buttons[action]
	b.position = center - b.texture_normal.get_size() * 0.5


func _circle_texture(radius: int, col: Color, arrow: Vector2, phone_icon := false) -> ImageTexture:
	var size := radius * 2
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(radius, radius)
	var tri := PackedVector2Array()
	if arrow != Vector2.ZERO:
		var side := arrow.orthogonal()
		tri.append(c + arrow * radius * 0.5)
		tri.append(c - arrow * radius * 0.25 + side * radius * 0.4)
		tri.append(c - arrow * radius * 0.25 - side * radius * 0.4)
	for y in size:
		for x in size:
			var pt := Vector2(x + 0.5, y + 0.5)
			var d := pt.distance_to(c)
			if d > radius:
				continue
			var px := col
			if d > radius - 3.0:
				px = Color(1, 1, 1, 0.6)
			elif tri.size() == 3 and Geometry2D.is_point_in_polygon(pt, tri):
				px = Color(1, 1, 1, 0.8)
			elif phone_icon:
				# A little phone: rounded rectangle outline with a screen.
				var q := pt - c
				var body := absf(q.x) < radius * 0.32 and absf(q.y) < radius * 0.55
				var screen := absf(q.x) < radius * 0.22 and q.y > -radius * 0.42 and q.y < radius * 0.32
				if body and not screen:
					px = Color(1, 1, 1, 0.85)
			img.set_pixel(x, y, px)
	return ImageTexture.create_from_image(img)
