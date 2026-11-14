extends Control
## Level-up screen. Pauses the game and offers upgrade cards. Cards are dealt
## face-up with a staggered reveal; rarer cards have a coloured banner and a
## shimmering border. Picks that arrive while it is open are queued.

const INPUT_GUARD := 0.55  # seconds before cards accept input, so a thumb
                           # already on the screen cannot pick by accident
const CATEGORY_COLORS := {"weapon": Color("#f97316"), "stat": Color("#22c55e"), "ink": Color("#3b82f6")}
const RARITY_COLORS := {"common": Color("#3b362f"), "rare": Color("#1e3a8a"), "epic": Color("#6b21a8"), "legendary": Color("#c9962a")}

var is_open: bool = false

var _queue: Array[String] = []  # titles of card picks waiting to be shown
var _title: Label
var _row: HBoxContainer
var _guard_left: float = 0.0
var _reroll: Button
var _banish: Button
var _rerolls_left: int = 0
var _banishes_left: int = 0
var _banishing: bool = false
var _base_title: String = ""
var _shimmer: Array[Dictionary] = []  # borders that pulse on rare cards


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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.title(_title, 44, Sumi.PAPER)
	box.add_child(_title)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 18)
	box.add_child(_row)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	box.add_child(buttons)
	_reroll = _small_button(_on_reroll)
	_banish = _small_button(_on_banish_pressed)
	buttons.add_child(_reroll)
	buttons.add_child(_banish)

	Events.level_up.connect(_on_level_up)
	Events.bonus_card.connect(_enqueue)
	Events.player_died.connect(func() -> void:
		_queue.clear()
		_close())


func _small_button(callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(220.0, 52.0)
	Sumi.ink_button(button, 24)
	button.pressed.connect(callback)
	return button


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
	_base_title = _queue.pop_front()
	_rerolls_left = int(Upgrades.bonus("reroll"))
	_banishes_left = int(Upgrades.bonus("banish"))
	_banishing = false
	if not _deal():
		_queue.clear()
		_close()
		return
	is_open = true
	visible = true
	Engine.time_scale = 1.0  # in case the bomb's slow motion was active
	get_tree().paused = true


## Deals a fresh hand of cards. Returns false when every upgrade is maxed.
func _deal() -> bool:
	var count := 3 + int(Upgrades.bonus("extra_cards"))
	var choices := Upgrades.roll_choices(count)
	if choices.is_empty():
		return false
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_shimmer.clear()
	var width := 300.0 if choices.size() <= 3 else 264.0
	for i in choices.size():
		_row.add_child(_make_card(choices[i], width, i))
	_guard_left = INPUT_GUARD
	_refresh_buttons()
	return true


func _refresh_buttons() -> void:
	_title.text = "TAP A CARD TO BANISH IT" if _banishing else _base_title
	_reroll.visible = _rerolls_left > 0
	_reroll.text = "Reroll (%d left)" % _rerolls_left
	_banish.visible = _banishes_left > 0
	_banish.text = "Cancel banish" if _banishing else "Banish (%d left)" % _banishes_left


func _on_reroll() -> void:
	if is_open and _rerolls_left > 0 and _guard_left <= 0.0:
		_rerolls_left -= 1
		_banishing = false
		_deal()


func _on_banish_pressed() -> void:
	if is_open and _banishes_left > 0 and _guard_left <= 0.0:
		_banishing = not _banishing
		_refresh_buttons()


func _make_card(id: String, width: float, order: int) -> Button:
	var def: Dictionary = Upgrades.defs().get(id, {})
	var level := Upgrades.level_of(id)
	var max_level := int(def.get("max_level", 1))
	var rarity := String(def.get("rarity", "common"))
	var accent: Color = CATEGORY_COLORS.get(String(def.get("category", "")), Color.WHITE)
	var rare_color: Color = RARITY_COLORS.get(rarity, Color.GRAY)
	var fancy := rarity == "epic" or rarity == "legendary"

	var card := Button.new()
	card.custom_minimum_size = Vector2(width, 430.0)
	card.disabled = true
	card.clip_contents = true
	card.pressed.connect(_choose.bind(id))
	# The border shows rarity; legendary and epic borders shimmer.
	var styles: Array[StyleBoxFlat] = []
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Sumi.PAPER if state != "pressed" else Sumi.PAPER_SHADE
		style.border_color = rare_color if state != "focus" else Sumi.SEAL
		style.set_border_width_all((9 if fancy else 6) + (3 if state in ["hover", "focus"] else 0))
		style.set_corner_radius_all(6)
		if fancy:
			style.shadow_color = Color(rare_color, 0.55)
			style.shadow_size = 14
		card.add_theme_stylebox_override(state, style)
		if state != "focus":
			styles.append(style)
	if fancy:
		_shimmer.append({"styles": styles, "color": rare_color, "phase": order * 0.7})

	var face := VBoxContainer.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_constant_override("separation", 6)
	card.add_child(face)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 14.0
	face.offset_right = -14.0
	face.offset_top = 12.0
	face.offset_bottom = -12.0

	# Banner: rarity, and whether this is a brand-new card or a level-up.
	var banner := Label.new()
	var tag := "NEW WEAPON" if level == 0 and String(def.get("set", "")) == "arsenal" else ("NEW" if level == 0 else "LEVEL UP")
	banner.text = "%s   %s" % [rarity.to_upper(), tag]
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_font_size_override("font_size", 15)
	banner.add_theme_color_override("font_color", Sumi.PAPER)
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = rare_color
	banner_style.set_corner_radius_all(3)
	banner_style.content_margin_top = 3
	banner_style.content_margin_bottom = 3
	banner.add_theme_stylebox_override("normal", banner_style)
	face.add_child(banner)

	var icon := UpgradeIcon.new()
	icon.icon_id = String(def.get("icon", id))
	icon.badge = String(def.get("badge", ""))
	icon.tint = accent
	icon.custom_minimum_size = Vector2(0.0, 132.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(icon)
	var name_label := _card_label(String(def.get("name", id)), 27, Sumi.INK)
	name_label.add_theme_font_override("font", Sumi.TITLE_FONT)
	face.add_child(name_label)
	# Level pips: filled for owned levels, a ring for the one on offer.
	var pips := ""
	for i in max_level:
		pips += "● " if i < level else ("◉ " if i == level else "○ ")
	face.add_child(_card_label(pips.strip_edges(), 17, Sumi.SEAL))
	face.add_child(_card_label(String(def.get("desc", "")), 15, Sumi.INK))
	if level == 0 and bool(def.get("first_level_double", false)):
		face.add_child(_card_label("First level counts double", 14, Color("#15803d")))
	# What this pick builds toward: a synergy it completes, a partner card to
	# look for, and progress on its set bonus.
	var ready_synergy := Upgrades.synergy_hint(id)
	if ready_synergy != "":
		face.add_child(_card_label("COMPLETES SYNERGY: " + ready_synergy, 15, Color("#b45309")))
	else:
		var partner := Upgrades.partner_hint(id)
		if partner != "":
			face.add_child(_card_label("Synergy: " + partner, 13, Sumi.FADED))
	var set_text := Upgrades.set_hint(id)
	if set_text != "":
		face.add_child(_card_label(set_text, 13, Color("#0f766e")))

	# Reveal: cards fade and slide in one after another.
	card.modulate.a = 0.0
	var tween := card.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(0.09 * order)
	tween.tween_property(card, "modulate:a", 1.0, 0.18)
	var slide := face.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Slide by animating the offsets: setting position on an anchored control
	# before layout would overwrite its margins.
	face.offset_top = 58.0
	face.offset_bottom = 34.0
	slide.tween_interval(0.09 * order)
	slide.set_parallel(true)
	slide.tween_property(face, "offset_top", 12.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.09 * order)
	slide.tween_property(face, "offset_bottom", -12.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.09 * order)
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
	if not is_open:
		return
	# Shimmer: rare borders pulse between their colour and white.
	var time := Time.get_ticks_msec() * 0.004
	for entry in _shimmer:
		var base: Color = entry["color"]
		var glow := base.lerp(Sumi.PAPER, 0.3 + 0.3 * sin(time + float(entry["phase"])))
		for style: StyleBoxFlat in entry["styles"]:
			style.border_color = glow
	if _guard_left <= 0.0:
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
	if _banishing:
		# Banish: this card is gone for the rest of the run; deal again.
		Upgrades.banish(id)
		_banishes_left -= 1
		_banishing = false
		if not _deal():
			_close()
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
