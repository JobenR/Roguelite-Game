extends Control
## Level-up screen. Pauses the game and offers up to three upgrade cards.
## Level-ups that arrive while it is open are queued.

const INPUT_GUARD := 0.45  # seconds before cards accept input, so a thumb
                           # already on the screen cannot pick by accident

var is_open: bool = false

var _pending: int = 0
var _title: Label
var _row: HBoxContainer
var _guard_left: float = 0.0


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
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	box.add_child(_title)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 24)
	box.add_child(_row)

	Events.level_up.connect(_on_level_up)
	Events.player_died.connect(_close)


func _on_level_up(_level: int) -> void:
	_pending += 1
	if not is_open:
		_open_next()


func _open_next() -> void:
	var choices := Upgrades.roll_choices(3)
	if choices.is_empty() or not GameState.is_playing():
		_pending = 0
		_close()
		return
	_pending -= 1
	for child in _row.get_children():
		child.queue_free()
	_title.text = "LEVEL %d: CHOOSE AN UPGRADE" % (GameState.level - _pending)
	for id in choices:
		_row.add_child(_make_card(id))
	is_open = true
	visible = true
	_guard_left = INPUT_GUARD
	get_tree().paused = true


func _make_card(id: String) -> Button:
	var def: Dictionary = DataDB.upgrades.get("upgrades", {}).get(id, {})
	var level := Upgrades.level_of(id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(300.0, 320.0)
	card.disabled = true
	card.pressed.connect(_choose.bind(id))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	card.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	box.add_child(_card_label(String(def.get("name", id)), 28, Color.WHITE))
	var level_text := "NEW" if level == 0 else "Level %d > %d" % [level, level + 1]
	box.add_child(_card_label(level_text, 18, Color("#9db8ff")))
	box.add_child(_card_label(String(def.get("desc", "")), 22, Color("#e6e6e6")))
	var hint := Upgrades.synergy_hint(id)
	if hint != "":
		box.add_child(_card_label("Unlocks synergy: " + hint, 20, Color("#f2b01e")))
	return card


func _card_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _process(delta: float) -> void:
	if not is_open or _guard_left <= 0.0:
		return
	_guard_left -= delta
	if _guard_left <= 0.0:
		for card: Button in _row.get_children():
			card.disabled = false
		if _row.get_child_count() > 0:
			(_row.get_child(0) as Button).grab_focus()


func _choose(id: String) -> void:
	if not is_open:
		return
	Upgrades.apply(id)
	if _pending > 0:
		_open_next()
	else:
		_close()


func _close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
