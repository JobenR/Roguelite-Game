extends Control
## Level-up screen. Pauses the game and offers up to three upgrade cards.
## Level-ups that arrive while it is open are queued.

const INPUT_GUARD := 0.45  # seconds before cards accept input, so a thumb
                           # already on the screen cannot pick by accident

var is_open: bool = false

var _queue: Array[String] = []  # titles of card picks waiting to be shown
var _title: Label
var _row: HBoxContainer
var _guard_left: float = 0.0
var _reroll: Button
var _rerolls_left: int = 0


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

	_reroll = Button.new()
	_reroll.custom_minimum_size = Vector2(240.0, 60.0)
	_reroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll.add_theme_font_size_override("font_size", 24)
	_reroll.pressed.connect(_on_reroll)
	box.add_child(_reroll)

	Events.level_up.connect(_on_level_up)
	Events.bonus_card.connect(_enqueue)
	Events.player_died.connect(func() -> void:
		_queue.clear()
		_close())


func _on_level_up(level: int) -> void:
	_enqueue("LEVEL %d: CHOOSE AN UPGRADE" % level)


func _enqueue(title: String) -> void:
	_queue.append(title)
	if not is_open:
		_open_next()


func _open_next() -> void:
	if not GameState.is_playing() or _queue.is_empty():
		_queue.clear()
		_close()
		return
	_title.text = _queue.pop_front()
	_rerolls_left = int(Upgrades.bonus("reroll"))
	if not _deal():
		_queue.clear()
		_close()
		return
	is_open = true
	visible = true
	get_tree().paused = true


## Deals a fresh hand of cards. Returns false when every upgrade is maxed.
func _deal() -> bool:
	var choices := Upgrades.roll_choices(3)
	if choices.is_empty():
		return false
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for id in choices:
		_row.add_child(_make_card(id))
	_guard_left = INPUT_GUARD
	_reroll.visible = _rerolls_left > 0
	_reroll.text = "Reroll (%d left)" % _rerolls_left
	return true


func _on_reroll() -> void:
	if is_open and _rerolls_left > 0 and _guard_left <= 0.0:
		_rerolls_left -= 1
		_deal()


const CATEGORY_COLORS := {"weapon": Color("#f97316"), "stat": Color("#22c55e"), "ink": Color("#3b82f6")}


func _make_card(id: String) -> Button:
	var def: Dictionary = DataDB.upgrades.get("upgrades", {}).get(id, {})
	var level := Upgrades.level_of(id)
	var max_level := int(def.get("max_level", 1))
	var accent: Color = CATEGORY_COLORS.get(String(def.get("category", "")), Color.WHITE)
	var card := Button.new()
	card.custom_minimum_size = Vector2(300.0, 400.0)
	card.disabled = true
	card.pressed.connect(_choose.bind(id))
	# Cards are colour-coded by category: orange weapon, green stat, blue ink.
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#f6f1e3") if state != "pressed" else Color("#e6dcc0")
		style.border_color = accent if state != "focus" else Color.WHITE
		style.set_border_width_all(8 if state in ["hover", "focus"] else 5)
		style.set_corner_radius_all(18)
		card.add_theme_stylebox_override(state, style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	card.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var icon := UpgradeIcon.new()
	icon.icon_id = String(def.get("icon", id))
	icon.tint = accent
	icon.custom_minimum_size = Vector2(0.0, 170.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	box.add_child(_card_label(String(def.get("name", id)), 26, Color("#1c1917")))
	# Level pips: filled for owned levels, a ring for the one on offer.
	var pips := ""
	for i in max_level:
		pips += "● " if i < level else ("◉ " if i == level else "○ ")
	box.add_child(_card_label(pips.strip_edges(), 20, accent.darkened(0.2)))
	box.add_child(_card_label(String(def.get("desc", "")), 17, Color("#44403c")))
	var hint := Upgrades.synergy_hint(id)
	if hint != "":
		box.add_child(_card_label("Synergy: " + hint, 17, Color("#b45309")))
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
	if not _queue.is_empty():
		_open_next()
	else:
		_close()


func _close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
