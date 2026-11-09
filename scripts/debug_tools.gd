extends CanvasLayer
## F1 = help: what the game is about and the controls (the game waits
## while it is open). Gamepad: Back / Select.
## F2 = the list of achievements (got ones ticked).
## F3 = the high scores on this device (with the debug tools on, F3 is the
## storm switch instead).
##
## Debug tools are hidden: open the help and press F12 to switch them on
## (or off). Only then do these work, and small buttons for them appear
## on the screen:
##   F5 = health full, F6 = alcohol +0.1 per mille, F7 = money +100 EUR,
##   F8 = phone battery +25 %, F9 = no hunger, cold or tiredness,
##   F10 = skip to the next day (as if slept at home),
##   F11 = new game in the next city (Oulu -> Raahe -> ...),
##   F4 = roadworks: close the next block ahead (and the street is rebuilt),
##   F3 = storm on / off (the street is rebuilt).
## While they are on, the police vision cones are drawn on the street.

const DEBUG_PROMILLE_STEP := 0.1
const BuildInfo = preload("res://scripts/build_info.gd")
const CityMap = preload("res://scripts/city_map.gd")
## Lines of controls in the help (HELP_KEY_1 ... in the translations).
const HELP_KEY_LINES := 3

var debug_on := false
var _help: PanelContainer
var _debug_line: Label
var _buttons: VBoxContainer
var _ach: PanelContainer
var _ach_title: Label
var _ach_grid: GridContainer
var _scores: PanelContainer
var _scores_grid: GridContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_help()
	_build_achievements()
	_build_scores()
	_buttons = VBoxContainer.new()
	_buttons.position = Vector2(12, 130)
	_buttons.visible = false
	add_child(_buttons)
	_button("F5 HP", _fill_health)
	_button("F6 +‰", _fill_alcohol)
	_button("F7 €", _add_money)
	_button("F8 akku", _charge_phone)
	_button("F9 virkeä", _refresh)
	_button("F10 päivä+", _next_day)
	_button("F11 kaupunki", _next_city)
	_button("F4 tietyö", _roadworks)
	_button("F3 myrsky", _storm)


func _build_help() -> void:
	_help = _panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_help.add_child(box)
	_label(box, tr("HELP_TITLE"), 30, Color(1, 0.85, 0.35))
	_label(box, tr("HELP_GOAL"), 18, Color(0.95, 0.95, 0.95), 480)
	var keys: Array = []
	for i in range(1, HELP_KEY_LINES + 1):
		keys.append(tr("HELP_KEY_%d" % i))
	_label(box, "\n".join(keys), 17, Color(0.85, 0.88, 0.95), 480)
	_label(box, tr("HELP_CLOSE"), 15, Color(0.6, 0.6, 0.65))
	_label(box, BuildInfo.text(), 13, Color(0.5, 0.5, 0.55))
	_debug_line = _label(box, tr("HELP_DEBUG"), 15, Color(1, 0.5, 0.4), 560)
	_debug_line.visible = false


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	return p


func _build_achievements() -> void:
	_ach = _panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_ach.add_child(box)
	_ach_title = _label(box, "", 26, Color(1, 0.85, 0.35))
	_ach_grid = GridContainer.new()
	_ach_grid.columns = 2
	_ach_grid.add_theme_constant_override("h_separation", 24)
	_ach_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_ach_grid)
	_label(box, tr("HELP_CLOSE"), 15, Color(0.6, 0.6, 0.65))


func _build_scores() -> void:
	_scores = _panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_scores.add_child(box)
	_label(box, tr("HISCORES"), 26, Color(1, 0.85, 0.35))
	_scores_grid = GridContainer.new()
	_scores_grid.columns = 5
	_scores_grid.add_theme_constant_override("h_separation", 18)
	_scores_grid.add_theme_constant_override("v_separation", 4)
	box.add_child(_scores_grid)
	_label(box, tr("HELP_CLOSE"), 15, Color(0.6, 0.6, 0.65))


func _refresh_scores() -> void:
	for c in _scores_grid.get_children():
		c.queue_free()
	if GameState.scores.is_empty():
		_label(_scores_grid, "–", 16, Color(0.6, 0.6, 0.65))
	for i in GameState.scores.size():
		var e: Dictionary = GameState.scores[i]
		var col := Color(0.95, 0.9, 0.6) if i == 0 else Color(0.9, 0.9, 0.92)
		_label(_scores_grid, "%d." % (i + 1), 16, col)
		_label(_scores_grid, str(e.get("score", 0)), 16, col)
		_label(_scores_grid, tr("DAY_N") % e.get("day", 1), 16, col)
		_label(_scores_grid, tr(str(e.get("headline", ""))), 14, Color(0.75, 0.75, 0.8), 320)
		_label(_scores_grid, str(e.get("date", "")), 14, Color(0.6, 0.6, 0.65))


func _toggle_scores() -> void:
	if _scores.visible:
		_scores.visible = false
		if GameState.modal == "help":
			GameState.modal = ""
		return
	if _help.visible:
		_help.visible = false
	elif GameState.modal != "" or GameState.over:
		return
	_refresh_scores()
	_scores.visible = true
	GameState.modal = "help"


## Fills the list: got ones bright with a tick, the rest grey.
func _refresh_achievements() -> void:
	for c in _ach_grid.get_children():
		c.queue_free()
	# Not yet done: only the name shows (no spoilers), except one random
	# one each time the list opens, whose description shows in white.
	var todo: Array = []
	for id in GameState.ACHIEVEMENTS:
		if not GameState.achieved.has(id):
			todo.append(id)
	var hint_id: String = todo[randi() % todo.size()] if not todo.is_empty() else ""
	var got := 0
	for id in GameState.ACHIEVEMENTS:
		var have: bool = GameState.achieved.has(id)
		if have:
			got += 1
			_label(_ach_grid, "✔ " + tr("ACH_" + id) + " – " + tr("ACH_%s_DESC" % id), 14,
				Color(0.95, 0.9, 0.6), 360)
		elif id == hint_id:
			_label(_ach_grid, "○ " + tr("ACH_" + id) + " – " + tr("ACH_%s_DESC" % id), 14, Color.WHITE, 360)
		else:
			_label(_ach_grid, "○ " + tr("ACH_" + id), 14, Color(0.55, 0.55, 0.6), 360)
	_ach_title.text = tr("ACH_LIST") % [got, GameState.ACHIEVEMENTS.size()]


func _toggle_achievements() -> void:
	if _ach.visible:
		_ach.visible = false
		if GameState.modal == "help":
			GameState.modal = ""
		return
	if _help.visible:
		_help.visible = false
	elif GameState.modal != "" or GameState.over:
		return
	_refresh_achievements()
	_ach.visible = true
	GameState.modal = "help"


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
		if _ach.visible:
			_toggle_achievements()
		if _scores.visible:
			_toggle_scores()
		_toggle_help()
	# Keep the open panel in the middle whatever the window size.
	var vs := get_viewport().get_visible_rect().size
	for p in [_help, _ach, _scores]:
		if p.visible:
			p.position = (vs - p.size) * 0.5


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
	if key == KEY_F2:
		if _scores.visible:
			_toggle_scores()
		_toggle_achievements()
		return
	if key == KEY_F3 and not debug_on:
		if _ach.visible:
			_toggle_achievements()
		_toggle_scores()
		return
	if _scores.visible:
		if key == KEY_ESCAPE:
			_toggle_scores()
		return
	if _ach.visible:
		if key == KEY_ESCAPE:
			_toggle_achievements()
		return
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
		KEY_F10:
			_next_day()
		KEY_F11:
			_next_city()
		KEY_F4:
			_roadworks()
		KEY_F3:
			_storm()


func _fill_health() -> void:
	GameState.health = 100.0


func _fill_alcohol() -> void:
	GameState.promille += DEBUG_PROMILLE_STEP


func _add_money() -> void:
	GameState.money += 100


func _charge_phone() -> void:
	GameState.battery = minf(100.0, GameState.battery + 25.0)


## New game in the next city (main.gd is this node's parent).
func _next_city() -> void:
	var main = get_parent()
	if main == null or not main.has_method("_new_game"):
		return
	GameState.forced_city = (CityMap.city + 1) % CityMap.CITIES.size()
	if GameState.modal == "help":
		GameState.modal = ""
	main.hud.hide_card()
	main._new_game()


## Close the block ahead (or behind, at the end of the map) for roadworks.
func _roadworks() -> void:
	var main = get_parent()
	if main == null or not main.has_method("_enter_block"):
		return
	var f: int = main.player.facing
	var seg: Vector3i = main.segment
	var target := CityMap.next_along(seg, f)
	if not CityMap.is_open(target):
		target = CityMap.next_along(seg, -f)
	if not CityMap.is_open(target):
		return
	CityMap.closed.append(target)
	main._enter_block(seg, main.player.position, f)


## Storm on / off; a storm brings rain (or at least clouds).
func _storm() -> void:
	var main = get_parent()
	if main == null or not main.has_method("_enter_block"):
		return
	GameState.storm = not GameState.storm
	if GameState.storm and (GameState.weather == "sunny" or GameState.weather == "snow"):
		GameState.weather = "rain"
	main._enter_block(main.segment, main.player.position, main.player.facing)


func _next_day() -> void:
	GameState.debug_next_day()


func _refresh() -> void:
	GameState.hunger = 0.0
	GameState.cold = 0.0
	GameState.tired = 0.0
