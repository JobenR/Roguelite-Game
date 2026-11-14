extends Control
## The ink choice shown before a run. Each ink is a colour and a play style
## (data/inks.json). Picking a different ink reloads the mode, because the
## page, the player and every weapon are tinted when they are set up.

var _row: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.04, 0.03, 0.82)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var heading := Label.new()
	heading.text = "Choose your ink"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.title(heading, 52, Sumi.PAPER)
	box.add_child(heading)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 14)
	box.add_child(_row)


## Shows the choice if one is due; otherwise the run simply starts.
func offer() -> void:
	if not GameState.pick_ink:
		return
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for id: String in DataDB.inks:
		_row.add_child(_make_card(id))
	visible = true
	get_tree().paused = true
	for card: Button in _row.get_children():
		if card.get_meta("ink") == GameState.ink_id:
			card.grab_focus()


func _make_card(id: String) -> Button:
	var def: Dictionary = DataDB.inks[id]
	var color := Color(String(def.get("color", "#1a4df2")))
	var card := Button.new()
	card.set_meta("ink", id)
	card.custom_minimum_size = Vector2(222.0, 380.0)
	card.clip_contents = true
	card.pressed.connect(_choose.bind(id))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Sumi.PAPER_SHADE if state == "pressed" else Sumi.PAPER
		style.border_color = color if state in ["hover", "focus"] else Sumi.INK
		style.set_border_width_all(8 if state in ["hover", "focus"] else 5)
		style.set_corner_radius_all(6)
		card.add_theme_stylebox_override(state, style)

	var face := VBoxContainer.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_constant_override("separation", 8)
	card.add_child(face)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 14.0
	face.offset_right = -14.0
	face.offset_top = 14.0
	face.offset_bottom = -14.0

	var swatch := InkSwatch.new()
	swatch.color = color
	swatch.light = Color(String(def.get("light", "#4d8fff")))
	swatch.custom_minimum_size = Vector2(0.0, 130.0)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(swatch)
	var name_label := _label(String(def.get("name", id)), 34, color.darkened(0.15))
	name_label.add_theme_font_override("font", Sumi.TITLE_FONT)
	face.add_child(name_label)
	face.add_child(_label(String(def.get("tagline", "")).to_upper(), 14, Sumi.SEAL))
	face.add_child(_label(String(def.get("desc", "")), 15, Sumi.INK))
	return card


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _choose(id: String) -> void:
	GameState.pick_ink = false
	visible = false
	get_tree().paused = false
	if id != GameState.ink_id:
		GameState.set_ink(id)
		get_tree().reload_current_scene()


## A splat of the ink, drawn in code, as the card's picture.
class InkSwatch:
	extends Control

	var color: Color = Color.BLUE
	var light: Color = Color.CYAN

	func _draw() -> void:
		var c := size * 0.5
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(color.to_html())
		# Bleed halo, lumpy core, a streak, and droplets.
		for i in 4:
			draw_circle(c, 62.0 - i * 6.0, Color(color, 0.06 + 0.03 * i))
		for i in 7:
			draw_circle(c + Vector2(rng.randf_range(-16, 16), rng.randf_range(-12, 12)), rng.randf_range(22.0, 34.0), color)
		var dir := Vector2.from_angle(rng.randf_range(-0.6, 0.6))
		for i in 4:
			draw_circle(c + dir * (34.0 + i * 15.0), 13.0 - i * 2.6, color)
		for i in 12:
			draw_circle(c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(44.0, 80.0), rng.randf_range(2.0, 6.0), color)
		draw_circle(c + Vector2(-10, -8), 12.0, Color(light, 0.55))
