extends CanvasLayer
## F1 = help: what the game is about and the controls (the game waits
## while it is open). Gamepad: Back / Select.
##
## Debug tools are hidden: open the help and press F12 to switch them on
## (or off). Only then do these work, and small buttons for them appear
## on the screen:
##   F5 = health full, F6 = alcohol +0.1 per mille, F7 = money +100 EUR,
##   F8 = phone battery +25 %, F9 = no hunger, cold or tiredness.

const DEBUG_PROMILLE_STEP := 0.1
## Lines of controls in the help (HELP_KEY_1 ... in the translations).
const HELP_KEY_LINES := 7

var debug_on := false
var _help: PanelContainer
var _debug_line: Label
var _buttons: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_help()
	_buttons = VBoxContainer.new()
	_buttons.position = Vector2(12, 130)
	_buttons.visible = false
	add_child(_buttons)
	_button("F5 HP", _fill_health)
	_button("F6 +‰", _fill_alcohol)
	_button("F7 €", _add_money)
	_button("F8 akku", _charge_phone)
	_button("F9 virkeä", _refresh)


func _build_help() -> void:
	_help = PanelContainer.new()
	_help.visible = false
	_help.set_anchors_preset(Control.PRESET_CENTER)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	_help.add_theme_stylebox_override("panel", sb)
	add_child(_help)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_help.add_child(box)
	_label(box, tr("HELP_TITLE"), 30, Color(1, 0.85, 0.35))
	_label(box, tr("HELP_GOAL"), 19, Color(0.95, 0.95, 0.95), 560)
	var keys: Array = []
	for i in range(1, HELP_KEY_LINES + 1):
		keys.append(tr("HELP_KEY_%d" % i))
	_label(box, "\n".join(keys), 18, Color(0.85, 0.88, 0.95), 560)
	_label(box, tr("HELP_CLOSE"), 15, Color(0.6, 0.6, 0.65))
	_debug_line = _label(box, tr("HELP_DEBUG"), 15, Color(1, 0.5, 0.4), 560)
	_debug_line.visible = false


func _label(parent: Control, text: String, size: int, col: Color, width := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if width > 0:
		l.custom_minimum_size = Vector2(width, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(86, 34)
	b.modulate = Color(1, 1, 1, 0.6)
	b.pressed.connect(cb)
	_buttons.add_child(b)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("help"):
		_toggle_help()
	if _help.visible:
		# Keep it in the middle whatever the window size.
		var vs := get_viewport().get_visible_rect().size
		_help.position = (vs - _help.size) * 0.5


func _toggle_help() -> void:
	if _help.visible:
		_help.visible = false
		if GameState.modal == "help":
			GameState.modal = ""
	elif GameState.modal == "" and not GameState.over:
		_help.visible = true
		GameState.modal = "help"


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.physical_keycode
	if _help.visible:
		if key == KEY_ESCAPE:
			_toggle_help()
		elif key == KEY_F12:
			debug_on = not debug_on
			_debug_line.visible = debug_on
			_buttons.visible = debug_on
		return
	if not debug_on:
		return
	match key:
		KEY_F5:
			_fill_health()
		KEY_F6:
			_fill_alcohol()
		KEY_F7:
			_add_money()
		KEY_F8:
			_charge_phone()
		KEY_F9:
			_refresh()


func _fill_health() -> void:
	GameState.health = 100.0


func _fill_alcohol() -> void:
	GameState.promille += DEBUG_PROMILLE_STEP


func _add_money() -> void:
	GameState.money += 100


func _charge_phone() -> void:
	GameState.battery = minf(100.0, GameState.battery + 25.0)


func _refresh() -> void:
	GameState.hunger = 0.0
	GameState.cold = 0.0
	GameState.tired = 0.0
