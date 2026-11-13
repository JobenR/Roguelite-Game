extends Control
## On-screen controls. Turns touches into InputMap actions with
## Input.action_press / action_release, so gameplay code never sees touch
## events. Shown on touch devices and in editor runs (mouse emulates touch).

const STICK_RADIUS := 80.0
const STICK_DEADZONE := 0.15
const STICK_ZONE := 0.5  # left fraction of the screen that starts the stick

var _stick_touch: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_vec: Vector2 = Vector2.ZERO
var _buttons: Array[Dictionary] = []
var _stick_was_pressing: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("editor")
	set_process_input(visible)
	# offset is measured from the bottom-right (or top-right) corner.
	_buttons = [
		{"action": "fire", "label": "FIRE", "radius": 70.0, "offset": Vector2(-110, -110), "top": false, "ready": true, "touch": -1},
		{"action": "secondary", "label": "2ND", "radius": 46.0, "offset": Vector2(-260, -70), "top": false, "ready": false, "touch": -1},
		{"action": "pulse", "label": "PULSE", "radius": 46.0, "offset": Vector2(-80, -260), "top": false, "ready": false, "touch": -1},
		{"action": "debug_toggle", "label": "DBG", "radius": 24.0, "offset": Vector2(-30, 80), "top": true, "ready": true, "touch": -1},
	]


func _button_center(button: Dictionary) -> Vector2:
	var offset: Vector2 = button["offset"]
	if button["top"]:
		return Vector2(size.x + offset.x, offset.y)
	return size + offset


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position - global_position
		if event.pressed:
			_touch_down(event.index, pos)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag and event.index == _stick_touch:
		_set_stick((event.position - global_position - _stick_origin) / STICK_RADIUS)


func _touch_down(index: int, pos: Vector2) -> void:
	for button in _buttons:
		var radius: float = button["radius"]
		if pos.distance_to(_button_center(button)) <= radius * 1.25:
			button["touch"] = index
			Input.action_press(button["action"])
			queue_redraw()
			return
	if _stick_touch == -1 and pos.x < size.x * STICK_ZONE:
		_stick_touch = index
		_stick_origin = pos
		_set_stick(Vector2.ZERO)


func _touch_up(index: int) -> void:
	if index == _stick_touch:
		_stick_touch = -1
		_set_stick(Vector2.ZERO)
	for button in _buttons:
		if button["touch"] == index:
			button["touch"] = -1
			Input.action_release(button["action"])
			queue_redraw()


func _set_stick(vec: Vector2) -> void:
	_stick_vec = vec.limit_length(1.0)
	_feed("move_right", _stick_vec.x)
	_feed("move_left", -_stick_vec.x)
	_feed("move_down", _stick_vec.y)
	_feed("move_up", -_stick_vec.y)
	queue_redraw()


func _feed(action: String, strength: float) -> void:
	var press := strength > STICK_DEADZONE
	if press:
		Input.action_press(action, strength)
	elif _stick_was_pressing.get(action, false):
		# Release only what the stick pressed, so keyboard input is untouched.
		Input.action_release(action)
	_stick_was_pressing[action] = press


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		_release_all()


func _release_all() -> void:
	_stick_touch = -1
	for action: String in _stick_was_pressing:
		if _stick_was_pressing[action]:
			Input.action_release(action)
	_stick_was_pressing.clear()
	_stick_vec = Vector2.ZERO
	for button in _buttons:
		if button["touch"] != -1:
			button["touch"] = -1
			Input.action_release(button["action"])


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Joystick: shown where the thumb landed, or a faint hint at rest.
	var base := _stick_origin if _stick_touch != -1 else Vector2(150.0, size.y - 150.0)
	var alpha := 0.35 if _stick_touch != -1 else 0.15
	draw_circle(base, STICK_RADIUS, Color(0, 0, 0, alpha))
	draw_arc(base, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, alpha + 0.2), 3.0)
	draw_circle(base + _stick_vec * STICK_RADIUS, 32.0, Color(1, 1, 1, alpha + 0.25))

	for button in _buttons:
		var center := _button_center(button)
		var radius: float = button["radius"]
		var pressed: bool = button["touch"] != -1
		var dim := 1.0 if button["ready"] else 0.4
		draw_circle(center, radius, Color(0, 0, 0, (0.55 if pressed else 0.3) * dim))
		draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.6 * dim), 3.0)
		var text: String = button["label"]
		var font_size := 22 if radius > 40.0 else 13
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, center + Vector2(-text_size.x * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.9 * dim))
