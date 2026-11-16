extends Control
## Pause screen, toggled with the "pause" action. Runs while the tree is paused.

var _levelup: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", Sumi.paper())
	center.add_child(sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	sheet.add_child(box)

	var heading := Label.new()
	heading.text = "Paused"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.title(heading, 54, Sumi.SEAL)
	box.add_child(heading)

	var help := Label.new()
	help.text = "FIRE: hold to shoot, drag to aim.\nBOMB: a lobbed blast that recharges.\nDELUGE: your Ultimate. Charges slowly from kills; floods the ground and blasts everything back.\nITEM: uses a saved item such as a Lasso."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.body(help, 19, Sumi.FADED)
	box.add_child(help)
	box.add_child(_make_button("Resume", _resume))
	box.add_child(_make_button("Restart run", _restart))
	box.add_child(_make_button("Quit to menu", _quit))


func setup(levelup: Control) -> void:
	_levelup = levelup


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280.0, 66.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Sumi.ink_button(button, 28)
	button.pressed.connect(callback)
	return button


func _process(_delta: float) -> void:
	if not Input.is_action_just_pressed("pause"):
		return
	if visible:
		_resume()
	elif GameState.is_playing() and not (_levelup != null and _levelup.is_open):
		visible = true
		Engine.time_scale = 1.0
		get_tree().paused = true


func _resume() -> void:
	visible = false
	get_tree().paused = false


func _quit() -> void:
	visible = false
	get_tree().paused = false
	GameState.finish_run()
	get_tree().change_scene_to_file("res://menus/title.tscn")


func _restart() -> void:
	visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()
