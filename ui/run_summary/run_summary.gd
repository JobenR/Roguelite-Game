extends Control
## Shown when the run ends. The page you fought over is framed as a painting,
## titled by how much of it is yours, beside the run's numbers.

var _ink: InkSystem
var _stats: Label
var _caption: Label
var _picture_slot: VBoxContainer


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.7)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", Sumi.paper())
	center.add_child(sheet)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 30)
	sheet.add_child(columns)

	# Left: the painting and its caption.
	_picture_slot = VBoxContainer.new()
	_picture_slot.add_theme_constant_override("separation", 8)
	columns.add_child(_picture_slot)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.body(_caption, 17, Sumi.FADED)

	# Right: heading, numbers, button.
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	columns.add_child(box)
	var heading := Label.new()
	heading.text = "The ink runs dry"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.title(heading, 50, Sumi.SEAL)
	box.add_child(heading)
	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.title(_stats, 28)
	box.add_child(_stats)
	var restart := Button.new()
	restart.text = "Begin again"
	restart.custom_minimum_size = Vector2(260.0, 66.0)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Sumi.ink_button(restart, 28)
	restart.pressed.connect(_restart)
	box.add_child(restart)

	Events.player_died.connect(_on_player_died)


func setup(ink: InkSystem) -> void:
	_ink = ink


func _on_player_died() -> void:
	var mine := 0
	var theirs := 0
	if _ink != null and _ink.grid != null:
		mine = int(round(_ink.ownership() * 100.0))
		theirs = int(round(_ink.smudge_share() * 100.0))
		for child in _picture_slot.get_children():
			_picture_slot.remove_child(child)
			if child != _caption:
				child.queue_free()
		_picture_slot.add_child(_ink.make_painting(500.0))
		_picture_slot.add_child(_caption)
	_caption.text = "\"%s\"\nYour ink %d%%   Smudge %d%%   Bare paper %d%%" % [_title_for(mine, theirs), mine, theirs, maxi(0, 100 - mine - theirs)]
	_stats.text = "Survived %s\nLevel %d\nKills %d" % [GameState.format_time(GameState.run_time), GameState.level, GameState.kills]
	visible = true


## A name for the painting, from how the page was shared.
func _title_for(mine: int, theirs: int) -> String:
	if mine + theirs < 6:
		return "First marks"
	if mine >= 60:
		return "The page is mine"
	if mine >= theirs * 2:
		return "Blue ascendant"
	if theirs >= mine * 2:
		return "Lost in the grey"
	if mine + theirs >= 70:
		return "No paper left unspoken"
	return "Blue against the grey"


func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("restart"):
		_restart()


func _restart() -> void:
	get_tree().reload_current_scene()
