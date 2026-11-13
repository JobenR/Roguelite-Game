extends Control
## Shown when the run ends: time survived, kills, and a restart button.

var _stats: Label


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := Label.new()
	title.text = "THE INK RUNS DRY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)

	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_theme_font_size_override("font_size", 28)
	box.add_child(_stats)

	var restart := Button.new()
	restart.text = "Restart"
	restart.custom_minimum_size = Vector2(260.0, 72.0)
	restart.add_theme_font_size_override("font_size", 28)
	restart.pressed.connect(_restart)
	box.add_child(restart)

	Events.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	_stats.text = "Survived %s\nKills %d" % [GameState.format_time(GameState.run_time), GameState.kills]
	visible = true


func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("restart"):
		_restart()


func _restart() -> void:
	get_tree().reload_current_scene()
