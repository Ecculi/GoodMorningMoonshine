extends CanvasLayer
## On-screen d-pad and action button. Shown only on touch screens.
## TouchScreenButton supports multitouch and feeds the same input actions
## as the keyboard.

const DPAD_RADIUS := 46
const ACTION_RADIUS := 72
const PHONE_RADIUS := 36

var _buttons := {}


func _ready() -> void:
	layer = 11
	_add("move_left", DPAD_RADIUS, Vector2.LEFT)
	_add("move_right", DPAD_RADIUS, Vector2.RIGHT)
	_add("move_up", DPAD_RADIUS, Vector2.UP)
	_add("move_down", DPAD_RADIUS, Vector2.DOWN)
	_add("action", ACTION_RADIUS, Vector2.ZERO)
	_add("phone", PHONE_RADIUS, Vector2.ZERO, true)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	var c := Vector2(160, s.y - 160)
	_place("move_left", c + Vector2(-100, 0))
	_place("move_right", c + Vector2(100, 0))
	_place("move_up", c + Vector2(0, -100))
	_place("move_down", c + Vector2(0, 100))
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
