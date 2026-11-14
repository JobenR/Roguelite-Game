extends Control
## Shown when the run ends: time survived, level, kills, and a restart button.

var _stats: Label


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.65)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", Sumi.paper())
	center.add_child(sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	sheet.add_child(box)

	var heading := Label.new()
	heading.text = "The ink runs dry"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.title(heading, 56, Sumi.SEAL)
	box.add_child(heading)

	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.title(_stats, 30)
	box.add_child(_stats)

	var restart := Button.new()
	restart.text = "Begin again"
	restart.custom_minimum_size = Vector2(280.0, 70.0)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Sumi.ink_button(restart, 30)
	restart.pressed.connect(_restart)
	box.add_child(restart)

	Events.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	_stats.text = "Survived %s\nLevel %d\nKills %d" % [GameState.format_time(GameState.run_time), GameState.level, GameState.kills]
	visible = true


func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("restart"):
		_restart()


func _restart() -> void:
	get_tree().reload_current_scene()
