extends CanvasLayer
## Debug helpers (only in debug builds, e.g. when run from the editor):
## F1 = health full, F2 = alcohol +0.5 per mille per press (no limit),
## F3 = money +100 €. The same as small on-screen buttons for touch screens.

const DEBUG_PROMILLE_STEP := 0.5


func _ready() -> void:
	layer = 20
	if not OS.is_debug_build():
		queue_free()
		return
	var box := VBoxContainer.new()
	box.position = Vector2(12, 130)
	add_child(box)
	_button(box, "F1 HP", _fill_health)
	_button(box, "F2 +‰", _fill_alcohol)
	_button(box, "F3 €", _add_money)


func _button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(76, 34)
	b.modulate = Color(1, 1, 1, 0.6)
	b.pressed.connect(cb)
	parent.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1:
				_fill_health()
			KEY_F2:
				_fill_alcohol()
			KEY_F3:
				_add_money()


func _fill_health() -> void:
	GameState.health = 100.0


func _fill_alcohol() -> void:
	GameState.promille += DEBUG_PROMILLE_STEP


func _add_money() -> void:
	GameState.money += 100
