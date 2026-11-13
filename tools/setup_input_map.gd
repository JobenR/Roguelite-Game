extends SceneTree
## Writes the InputMap actions into project.godot. Re-run after editing:
##   godot --headless --script res://tools/setup_input_map.gd
## (Actions can also be edited by hand in Project Settings > Input Map.)


func _init() -> void:
	_action("move_left", [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("move_right", [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("move_up", [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action("move_down", [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action("aim_left", [_key(KEY_LEFT), _axis(JOY_AXIS_RIGHT_X, -1.0)])
	_action("aim_right", [_key(KEY_RIGHT), _axis(JOY_AXIS_RIGHT_X, 1.0)])
	_action("aim_up", [_key(KEY_UP), _axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_action("aim_down", [_key(KEY_DOWN), _axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_action("fire", [_key(KEY_SPACE), _button(JOY_BUTTON_A), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_action("secondary", [_key(KEY_E), _button(JOY_BUTTON_X)])
	_action("pulse", [_key(KEY_Q), _button(JOY_BUTTON_Y)])
	_action("pause", [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])
	_action("restart", [_key(KEY_R), _button(JOY_BUTTON_BACK)])
	_action("debug_toggle", [_key(KEY_F3)])
	_action("debug_spawn", [_key(KEY_F2)])
	var err := ProjectSettings.save()
	print("Input map saved, error code: ", err)
	quit()


func _action(action: String, events: Array) -> void:
	ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	return event


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event
