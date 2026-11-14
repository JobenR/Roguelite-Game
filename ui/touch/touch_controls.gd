extends Control
## On-screen controls. Turns touches into InputMap actions with
## Input.action_press / action_release, so gameplay code never sees touch
## events. Shown on touch devices and in editor runs (mouse emulates touch).
##
## Left thumb: floating move stick. Right thumb: FIRE is also an aim stick:
## hold to fire, drag to aim. BOMB, PULSE, pause and debug are plain buttons.

const STICK_RADIUS := 46.0     # thumb travel for full speed; smaller = more sensitive
const STICK_DEADZONE := 0.08
const STICK_CURVE := 0.65      # below 1 boosts small movements
const STICK_ZONE := 0.5        # left fraction of the screen that starts the stick
const AIM_RADIUS := 44.0
const AIM_DEADZONE := 0.3

const MOVE_ACTIONS: Array[String] = ["move_right", "move_left", "move_down", "move_up"]
const AIM_ACTIONS: Array[String] = ["aim_right", "aim_left", "aim_down", "aim_up"]

var _stick_touch: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_vec: Vector2 = Vector2.ZERO
var _aim_origin: Vector2 = Vector2.ZERO
var _aim_vec: Vector2 = Vector2.ZERO
var _buttons: Array[Dictionary] = []
var _pressing: Dictionary = {}  # action -> true while this UI holds it


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("editor")
	set_process_input(visible)
	# offset is measured from the bottom-right (or top-right) corner.
	_buttons = [
		_button("fire", "FIRE", 70.0, Vector2(-110, -110), false),
		_button("secondary", "BOMB", 46.0, Vector2(-260, -70), false),
		_button("pulse", "PULSE", 46.0, Vector2(-80, -260), false),
		_button("dash", "DASH", 40.0, Vector2(-235, -185), false),
		_button("pause", "II", 24.0, Vector2(-30, 140), true),
		_button("debug_toggle", "DBG", 24.0, Vector2(-30, 80), true),
	]
	Events.secondary_charge_changed.connect(_set_charge.bind("secondary"))
	Events.pulse_charge_changed.connect(_set_charge.bind("pulse"))
	Events.dash_charge_changed.connect(_set_charge.bind("dash"))
	Events.upgrade_applied.connect(func(_id: String) -> void: queue_redraw())


func _button(action: String, label: String, radius: float, offset: Vector2, top: bool) -> Dictionary:
	return {"action": action, "label": label, "radius": radius, "offset": offset, "top": top, "ready": true, "charge": 1.0, "touch": -1}


func _set_charge(ratio: float, action: String) -> void:
	for button in _buttons:
		if button["action"] == action:
			button["charge"] = ratio
			button["ready"] = ratio >= 1.0
	queue_redraw()


## DASH only exists once its upgrade is owned.
func _is_hidden(button: Dictionary) -> bool:
	return button["action"] == "dash" and Upgrades.bonus("dash") <= 0.0


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
	elif event is InputEventScreenDrag:
		var pos: Vector2 = event.position - global_position
		if event.index == _stick_touch:
			_set_stick((pos - _stick_origin) / STICK_RADIUS)
		elif event.index == _buttons[0]["touch"]:
			_set_aim((pos - _aim_origin) / AIM_RADIUS)


func _touch_down(index: int, pos: Vector2) -> void:
	for button in _buttons:
		if _is_hidden(button):
			continue
		var radius: float = button["radius"]
		if pos.distance_to(_button_center(button)) <= radius * 1.25:
			button["touch"] = index
			Input.action_press(button["action"])
			if button["action"] == "fire":
				_aim_origin = pos
				_set_aim(Vector2.ZERO)
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
			if button["action"] == "fire":
				_set_aim(Vector2.ZERO)
			queue_redraw()


func _set_stick(vec: Vector2) -> void:
	var length := minf(vec.length(), 1.0)
	if length < STICK_DEADZONE:
		_stick_vec = Vector2.ZERO
	else:
		# Curve the response so a small push already moves quickly.
		_stick_vec = vec.normalized() * pow(length, STICK_CURVE)
	_feed(MOVE_ACTIONS, _stick_vec, 0.01)
	queue_redraw()


func _set_aim(vec: Vector2) -> void:
	_aim_vec = vec.limit_length(1.0)
	_feed(AIM_ACTIONS, _aim_vec, AIM_DEADZONE)
	queue_redraw()


## Feeds a 2D vector into four directional actions (right, left, down, up).
func _feed(actions: Array[String], vec: Vector2, deadzone: float) -> void:
	var strengths: Array[float] = [vec.x, -vec.x, vec.y, -vec.y]
	var live := vec.length() > deadzone
	for i in 4:
		var action := actions[i]
		var press := live and strengths[i] > 0.0
		if press:
			Input.action_press(action, strengths[i])
		elif _pressing.get(action, false):
			# Release only what this UI pressed, so keyboard input is untouched.
			Input.action_release(action)
		_pressing[action] = press


func _notification(what: int) -> void:
	# Pausing stops this node, so drop every held action first.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_PAUSED:
		_release_all()


func _release_all() -> void:
	_stick_touch = -1
	for action: String in _pressing:
		if _pressing[action]:
			Input.action_release(action)
	_pressing.clear()
	_stick_vec = Vector2.ZERO
	_aim_vec = Vector2.ZERO
	for button in _buttons:
		if button["touch"] != -1:
			button["touch"] = -1
			Input.action_release(button["action"])
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Move stick: shown where the thumb landed, or a faint hint at rest.
	var base := _stick_origin if _stick_touch != -1 else Vector2(150.0, size.y - 150.0)
	var alpha := 0.35 if _stick_touch != -1 else 0.15
	draw_circle(base, STICK_RADIUS + 26.0, Color(0, 0, 0, alpha))
	draw_arc(base, STICK_RADIUS + 26.0, 0.0, TAU, 48, Color(1, 1, 1, alpha + 0.2), 3.0)
	draw_circle(base + _stick_vec * STICK_RADIUS, 30.0, Color(1, 1, 1, alpha + 0.25))

	for button in _buttons:
		if _is_hidden(button):
			continue
		var center := _button_center(button)
		var radius: float = button["radius"]
		var pressed: bool = button["touch"] != -1
		var dim := 1.0 if button["ready"] else 0.4
		draw_circle(center, radius, Color(0, 0, 0, (0.55 if pressed else 0.3) * dim))
		draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.6 * dim), 3.0)
		var charge: float = button["charge"]
		if charge < 1.0:
			draw_arc(center, radius - 6.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, Color(0.35, 0.6, 1.0, 0.9), 6.0)
		if button["action"] == "fire" and pressed and _aim_vec.length() > AIM_DEADZONE:
			# Aim knob: shows which way the drag is pointing.
			draw_circle(center + _aim_vec * radius * 0.75, 20.0, Color(1, 1, 1, 0.75))
			continue
		var text: String = button["label"]
		var font_size := 22 if radius > 40.0 else 13
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, center + Vector2(-text_size.x * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.9 * dim))
