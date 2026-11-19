extends Control
## The end of a run. On death, or on beating the final boss, the page you
## fought over is framed as a painting beside the run's numbers and the Seals
## earned. After a win you may keep playing or bank the run.

var _ink: InkSystem
var _heading: Label
var _ink_line: Label
var _stats: Label
var _seals: Label
var _caption: Label
var _picture_slot: VBoxContainer
var _primary: Button
var _secondary: Button
var _victory: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

	# Right: heading, numbers, Seals, buttons.
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	columns.add_child(box)
	_heading = Label.new()
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.title(_heading, 50, Sumi.SEAL)
	box.add_child(_heading)
	_ink_line = Label.new()
	_ink_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.body(_ink_line, 18, Sumi.FADED)
	box.add_child(_ink_line)
	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.title(_stats, 27)
	box.add_child(_stats)
	_seals = Label.new()
	_seals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.title(_seals, 26, Sumi.SEAL)
	box.add_child(_seals)
	_primary = _button(64.0, 28, _on_primary)
	box.add_child(_primary)
	_secondary = _button(54.0, 24, _on_secondary)
	box.add_child(_secondary)

	Events.player_died.connect(_on_player_died)
	Events.final_boss_defeated.connect(_on_victory)
	Events.level_won.connect(_on_level_won)
	Events.level_lost.connect(_on_level_lost)


var paint: PaintSystem = null
var reclaim: ReclaimSystem = null
var _stars: int = 0


func setup(ink: InkSystem) -> void:
	_ink = ink


func _button(height: float, font_size: int, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(280.0, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Sumi.ink_button(button, font_size)
	button.pressed.connect(callback)
	return button


func _on_player_died() -> void:
	_victory = false
	_heading.text = "The ink runs dry"
	_primary.text = "Begin again"
	_secondary.text = "Menu"
	GameState.finish_run()
	_seals.text = _reward_text()
	_show()


## Reclaim: the page is yours. Stars, then on to the next page.
func _on_level_won(stars: int) -> void:
	_victory = true
	_stars = stars
	get_tree().paused = true
	GameState.finish_run()
	_heading.text = "Page reclaimed"
	var more := GameState.reclaim_level + 1 < ReclaimSystem.level_count()
	_primary.text = "Next page" if more else "Menu"
	_secondary.text = "Menu"
	_seals.text = _reward_text()
	_show()


## Reclaim: the horde's ink took the page first.
func _on_level_lost() -> void:
	_victory = false
	_stars = 0
	_heading.text = "The page is lost"
	_primary.text = "Try again"
	_secondary.text = "Menu"
	GameState.finish_run()
	_seals.text = _reward_text()
	_show()


func _on_victory() -> void:
	if reclaim != null:
		return   # a page is won by the race, not by a boss
	_victory = true
	get_tree().paused = true
	_heading.text = "The page is yours"
	_primary.text = "Keep going"
	_secondary.text = "Finish and bank Seals"
	_seals.text = "%d Seals so far" % GameState.seals_earned()
	_show()


func _show() -> void:
	var mine := 0
	var theirs := 0
	if _ink != null and _ink.grid != null:
		mine = int(round(_ink.ownership() * 100.0))
		theirs = int(round(_ink.smudge_share() * 100.0))
		for child in _picture_slot.get_children():
			_picture_slot.remove_child(child)
			if child != _caption:
				child.queue_free()
		_picture_slot.add_child(_ink.make_painting(480.0))
		_picture_slot.add_child(_caption)
	var ink_name := String(DataDB.inks.get(GameState.ink_id, {}).get("name", "Blue"))
	_caption.text = "\"%s\"\nYour ink %d%%   Smudge %d%%   Bare paper %d%%" % [_title_for(ink_name, mine, theirs), mine, theirs, maxi(0, 100 - mine - theirs)]
	_ink_line.text = "%s ink" % ink_name
	if reclaim != null:
		var mine_now := int(round(_ink.ownership() * 100.0))
		var theirs_now := int(round(_ink.enemy_share() * 100.0))
		_caption.text = "\"%s\"\nYour ground %d%%   Enemy ink %d%%" % [String(reclaim.level.get("name", "")), mine_now, theirs_now]
		if _victory:
			_ink_line.text = "%d of 3 stars" % _stars
			_stats.text = "Cleared in %s (par %s)\nSources destroyed %d of %d\nKills %d" % [GameState.format_time(GameState.run_time),
					GameState.format_time(float(reclaim.level.get("par_seconds", 300.0))), reclaim.destroyed, reclaim.sources.size(), GameState.kills]
		else:
			_ink_line.text = "Lost on page %d" % (reclaim.level_index + 1)
	if paint != null:
		# Masterpiece: the picture, how much of it is right, and the stars.
		var right := int(_ink.grid.accuracy() * 100.0)
		_caption.text = "\"%s\"\nPainted correctly %d%%" % [String(paint.picture.get("name", "")), right]
		if _victory:
			_ink_line.text = "%d of 3 stars   %d%% correct" % [paint.stars(), right]
		else:
			_ink_line.text = "%d%% correct. Beat the final boss to earn stars." % right
	_stats.text = "Survived %s\nLevel %d\nKills %d" % [GameState.format_time(GameState.run_time), GameState.level, GameState.kills]
	visible = true
	_primary.grab_focus()


## What the run paid: Seals, Gold Leaf, character XP and any levels gained.
func _reward_text() -> String:
	var reward: Dictionary = GameState.last_reward
	var text := "+%d Seals" % int(reward.get("seals", 0))
	if int(reward.get("gold", 0)) > 0:
		text += "   +%d Gold Leaf" % int(reward["gold"])
	text += "\n+%d character XP" % int(reward.get("char_xp", 0))
	var levels := int(reward.get("levels", 0))
	if levels > 0:
		text += "\nLEVEL UP: now level %d, +%d skill point%s" % [SaveData.char_level(), levels, "" if levels == 1 else "s"]
	return text


## A name for the painting, from how the page was shared.
func _title_for(ink_name: String, mine: int, theirs: int) -> String:
	if mine + theirs < 6:
		return "First marks"
	if mine >= 60:
		return "The page is mine"
	if mine >= theirs * 2:
		return "%s ascendant" % ink_name
	if theirs >= mine * 2:
		return "Lost in the grey"
	if mine + theirs >= 70:
		return "No paper left unspoken"
	return "%s against the grey" % ink_name


func _on_primary() -> void:
	if reclaim != null and _victory:
		get_tree().paused = false
		if GameState.reclaim_level + 1 < ReclaimSystem.level_count():
			GameState.reclaim_level += 1
			get_tree().reload_current_scene()
		else:
			_on_secondary()
		return
	if _victory:
		# Keep going: the run continues as an endless one.
		visible = false
		get_tree().paused = false
	else:
		get_tree().paused = false
		get_tree().reload_current_scene()


func _on_secondary() -> void:
	GameState.finish_run()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menus/title.tscn")


func _process(_delta: float) -> void:
	if visible and not _victory and Input.is_action_just_pressed("restart"):
		_on_primary()
