extends Control
## The title screen: start a run, choose and unlock inks, buy permanent
## boosts with Seals, and change settings. Built in code with the Sumi look.

enum View { HOME, INKS, BOOSTS, SETTINGS, MODES }

var _view: View = View.HOME
var _body: VBoxContainer
var _seals: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Engine.time_scale = 1.0
	Audio.refresh_music()
	Audio.set_heavy(false, true)

	var backdrop := Backdrop.new()
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var safe := MarginContainer.new()
	safe.set_script(load("res://ui/common/safe_area.gd"))
	add_child(safe)
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)

	_seals = Label.new()
	Sumi.title(_seals, 30, Sumi.SEAL)
	frame.add_child(_seals)
	_seals.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	_seals.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var center := CenterContainer.new()
	frame.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	center.add_child(_body)
	_show(View.HOME)


func _show(view: View) -> void:
	_view = view
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_seals.text = "%d Seals" % SaveData.seals()
	match view:
		View.HOME:
			_build_home()
		View.INKS:
			_build_inks()
		View.BOOSTS:
			_build_boosts()
		View.SETTINGS:
			_build_settings()
		View.MODES:
			_build_modes()


func _heading(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.title(label, size, color)
	return label


func _button(text: String, callback: Callable, width: float = 320.0, height: float = 64.0, font_size: int = 30) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Sumi.ink_button(button, font_size)
	button.pressed.connect(callback)
	return button


func _build_home() -> void:
	_body.add_child(_heading("Blotline", 120, Sumi.INK))
	var ink_name := String(DataDB.inks.get(GameState.ink_id, {}).get("name", "Blue"))
	var record := float(SaveData.data.get("best_time", 0.0))
	var line := "%s ink" % ink_name
	if record > 0.0:
		line += "   Best %s   Wins %d" % [GameState.format_time(record), int(SaveData.data.get("wins", 0))]
	var sub := _heading(line, 24, Sumi.FADED)
	_body.add_child(sub)
	var play := _button("Begin", _show.bind(View.MODES), 360.0, 80.0, 40)
	_body.add_child(play)
	_body.add_child(_button("Inks", _show.bind(View.INKS)))
	_body.add_child(_button("Boosts", _show.bind(View.BOOSTS)))
	_body.add_child(_button("Settings", _show.bind(View.SETTINGS)))
	play.grab_focus()


func _build_modes() -> void:
	_body.add_child(_heading("Choose a page", 52, Sumi.INK))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_body.add_child(row)
	for id: String in DataDB.modes:
		var def: Dictionary = DataDB.modes[id]
		var card := Button.new()
		card.custom_minimum_size = Vector2(380.0, 300.0)
		card.clip_contents = true
		Sumi.ink_button(card)
		card.pressed.connect(_start.bind(id))
		var face := VBoxContainer.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.alignment = BoxContainer.ALIGNMENT_CENTER
		face.add_theme_constant_override("separation", 14)
		card.add_child(face)
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.offset_left = 22.0
		face.offset_right = -22.0
		var name_label := _card_text(String(def.get("name", id)), 44, Sumi.SEAL if def.has("burn") else Sumi.INK)
		name_label.add_theme_font_override("font", Sumi.TITLE_FONT)
		face.add_child(name_label)
		face.add_child(_card_text(String(def.get("desc", "")), 18, Sumi.INK))
		row.add_child(card)
		if id == GameState.mode_id:
			card.grab_focus()
	_body.add_child(_button("Back", _show.bind(View.HOME), 240.0, 56.0, 26))


func _start(mode_id: String) -> void:
	GameState.mode_id = mode_id
	get_tree().change_scene_to_file("res://modes/survival.tscn")


func _build_inks() -> void:
	_body.add_child(_heading("Choose your ink", 52, Sumi.INK))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	for id: String in DataDB.inks:
		row.add_child(_ink_card(id))
	_body.add_child(_button("Back", _show.bind(View.HOME), 240.0, 56.0, 26))


func _ink_card(id: String) -> Button:
	var def: Dictionary = DataDB.inks[id]
	var owned := SaveData.has_ink(id)
	var chosen := id == GameState.ink_id
	var cost := SaveData.ink_cost(id)
	var color := Color(String(def.get("color", "#1a4df2")))
	var card := Button.new()
	card.custom_minimum_size = Vector2(222.0, 400.0)
	card.clip_contents = true
	card.pressed.connect(_pick_ink.bind(id))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Sumi.PAPER_SHADE if state == "pressed" else Sumi.PAPER
		style.border_color = color if (chosen or state in ["hover", "focus"]) else Sumi.INK
		style.set_border_width_all(9 if chosen else (7 if state in ["hover", "focus"] else 5))
		style.set_corner_radius_all(6)
		card.add_theme_stylebox_override(state, style)

	var face := VBoxContainer.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_constant_override("separation", 6)
	card.add_child(face)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 14.0
	face.offset_right = -14.0
	face.offset_top = 14.0
	face.offset_bottom = -12.0

	var swatch := InkSwatch.new()
	swatch.color = color
	swatch.light = Color(String(def.get("light", "#4d8fff")))
	swatch.dimmed = not owned
	swatch.custom_minimum_size = Vector2(0.0, 124.0)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(swatch)
	var name_label := _card_text(String(def.get("name", id)), 32, color.darkened(0.15) if owned else Sumi.FADED)
	name_label.add_theme_font_override("font", Sumi.TITLE_FONT)
	face.add_child(name_label)
	face.add_child(_card_text(String(def.get("tagline", "")).to_upper(), 14, Sumi.SEAL))
	face.add_child(_card_text(String(def.get("desc", "")), 14, Sumi.INK))
	var status := "IN USE" if chosen else ("Tap to use" if owned else ("Unlock for %d Seals" % cost if SaveData.seals() >= cost else "Locked: %d Seals" % cost))
	var status_label := _card_text(status, 16, Sumi.SEAL if (chosen or not owned) else Sumi.FADED)
	status_label.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	face.add_child(status_label)
	return card


func _card_text(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _pick_ink(id: String) -> void:
	if not SaveData.has_ink(id):
		if not SaveData.unlock_ink(id):
			Audio.play("fizzle")
			return
		Audio.play("milestone")
	GameState.set_ink(id)
	SaveData.data["ink"] = id
	SaveData.save()
	_show(View.INKS)


func _build_boosts() -> void:
	_body.add_child(_heading("Boosts", 52, Sumi.INK))
	_body.add_child(_heading("Permanent, for every run. Bought with Seals.", 20, Sumi.FADED))
	var sheet := PanelContainer.new()
	var style := Sumi.paper(4)
	style.set_content_margin_all(18)
	sheet.add_theme_stylebox_override("panel", style)
	_body.add_child(sheet)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	sheet.add_child(list)
	var boosts: Dictionary = DataDB.meta.get("boosts", {})
	for id: String in boosts:
		var def: Dictionary = boosts[id]
		var level := SaveData.boost_level(id)
		var max_level := (def.get("costs", []) as Array).size()
		var cost := SaveData.boost_cost(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		list.add_child(row)
		var text := VBoxContainer.new()
		text.custom_minimum_size = Vector2(430.0, 0.0)
		row.add_child(text)
		var pips := ""
		for i in max_level:
			pips += "● " if i < level else "○ "
		var name_label := Label.new()
		name_label.text = "%s   %s" % [String(def.get("name", id)), pips.strip_edges()]
		Sumi.title(name_label, 26)
		text.add_child(name_label)
		var desc := Label.new()
		desc.text = String(def.get("desc", ""))
		Sumi.body(desc, 16, Sumi.FADED)
		text.add_child(desc)
		var buy := _button("Maxed" if cost < 0 else "%d Seals" % cost, _buy_boost.bind(id), 190.0, 54.0, 24)
		buy.disabled = cost < 0 or SaveData.seals() < cost
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(buy)
	_body.add_child(_button("Back", _show.bind(View.HOME), 240.0, 56.0, 26))


func _buy_boost(id: String) -> void:
	if SaveData.buy_boost(id):
		Audio.play("milestone")
	_show(View.BOOSTS)


func _build_settings() -> void:
	_body.add_child(_heading("Settings", 52, Sumi.INK))
	for entry: Array in [["sound", "Sound effects"], ["music", "Music"], ["vibration", "Vibration"]]:
		var key: String = entry[0]
		var on := SaveData.setting(key)
		_body.add_child(_button("%s: %s" % [entry[1], "on" if on else "off"], _toggle.bind(key), 380.0))
	_body.add_child(_button("Back", _show.bind(View.HOME), 240.0, 56.0, 26))


func _toggle(key: String) -> void:
	SaveData.set_setting(key, not SaveData.setting(key))
	Audio.refresh_music()
	_show(View.SETTINGS)


## Rice paper with a few splats of the chosen ink and a red seal.
class Backdrop:
	extends Control

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		draw_rect(Rect2(Vector2.ZERO, size), Sumi.PAPER)
		for i in 1400:
			var at := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			var length := rng.randf_range(6.0, 40.0)
			draw_line(at, at + Vector2(length, length * rng.randf_range(-0.25, 0.25)), Color("#b9a98a", rng.randf_range(0.12, 0.45)), rng.randf_range(1.0, 2.2))
		var ink := GameState.ink_color
		for corner: Vector2 in [Vector2(0.12, 0.2), Vector2(0.88, 0.78), Vector2(0.84, 0.18), Vector2(0.14, 0.82)]:
			var c := Vector2(corner.x * size.x, corner.y * size.y)
			for k in 4:
				draw_circle(c, 150.0 - k * 16.0, Color(ink, 0.04 + 0.02 * k))
			for k in 9:
				draw_circle(c + Vector2(rng.randf_range(-40, 40), rng.randf_range(-34, 34)), rng.randf_range(36.0, 70.0), Color(ink, 0.9))
			var dir := Vector2.from_angle(rng.randf() * TAU)
			for k in 5:
				draw_circle(c + dir * (80.0 + k * 34.0), 30.0 - k * 5.0, Color(ink, 0.9))
			for k in 16:
				draw_circle(c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(90.0, 210.0), rng.randf_range(3.0, 11.0), Color(ink, 0.9))
		for stroke in 4:
			draw_rect(Rect2(Vector2.ZERO, size).grow(-rng.randf_range(6.0, 16.0)), Color(Sumi.INK, rng.randf_range(0.35, 0.75)), false, rng.randf_range(5.0, 12.0))
