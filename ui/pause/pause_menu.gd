extends Control
## Pause screen, toggled with the "pause" action. Runs while the tree is paused.

var _levelup: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)
	var help := Label.new()
	help.text = "GLYPHS\nClose a shape with your trail, then PULSE it.\nCircle: Maelstrom pulls enemies in and grinds them.\nTriangle: Spike Burst fires a beam from each corner.\nSquare: Fortress turns it to permanent ink and shelters you.\nThe bigger the shape, the stronger the effect."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 20)
	help.add_theme_color_override("font_color", Color("#fbd34d"))
	box.add_child(help)
	box.add_child(_make_button("Resume", _resume))
	box.add_child(_make_button("Restart run", _restart))


func setup(levelup: Control) -> void:
	_levelup = levelup


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260.0, 72.0)
	button.add_theme_font_size_override("font_size", 28)
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


func _restart() -> void:
	visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()
