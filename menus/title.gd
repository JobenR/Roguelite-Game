extends Control
## The title screen: start a run, grow the character (skills), choose and
## unlock inks, buy permanent boosts, visit the store, and change settings.
## Built in code with the Sumi look.

enum View { HOME, INKS, BOOSTS, SETTINGS, MODES, SKILLS, STORE, LEVELS }

var _view: View = View.HOME
var _body: VBoxContainer
var _wallet: Label
var _notice: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Engine.time_scale = 1.0
	DataDB.apply_mode_text("")   # a mode's reworded cards must not leak into the menu
	Audio.refresh_music()
	Audio.calm()

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

	_wallet = Label.new()
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Sumi.title(_wallet, 26, Sumi.SEAL)
	frame.add_child(_wallet)
	_wallet.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	_wallet.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var center := CenterContainer.new()
	frame.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	center.add_child(_body)

	var gift := SaveData.claim_daily()
	if gift > 0:
		_notice = "VIP daily gift: +%d Gold Leaf" % gift
	_show(View.HOME)


func _show(view: View) -> void:
	_view = view
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_wallet.text = "%d Seals\n%d Gold Leaf" % [SaveData.seals(), SaveData.gold()]
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
		View.SKILLS:
			_build_skills()
		View.STORE:
			_build_store()
		View.LEVELS:
			_build_levels()


func _heading(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Sumi.title(label, size, color)
	return label


func _button(text: String, callback: Callable, width: float = 300.0, height: float = 58.0, font_size: int = 28) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Sumi.ink_button(button, font_size)
	button.pressed.connect(callback)
	return button


func _back() -> Button:
	return _button("Back", _show.bind(View.HOME), 220.0, 52.0, 24)


func _card_text(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## A live picture of the player's drop as it will look in a run.
func _drop_preview(scale_by: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(170.0, 150.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var drop := ShapeVisual.new()
	holder.add_child(drop)
	drop.position = holder.custom_minimum_size * 0.5
	drop.scale = Vector2(scale_by, scale_by)
	drop.setup({
		"sides": 0, "color": GameState.ink_color.to_html(), "core": "#ffffff",
		"core_shape": String(SaveData.data.get("look", "square")),
		"tier": clampi((SaveData.char_level() - 1) / 4, 0, 5),
		"marks": (SaveData.data.get("skills", {}) as Dictionary).duplicate(),
	}, 16.0)
	return holder


func _build_home() -> void:
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 6)
	_body.add_child(top)
	top.add_child(_drop_preview(2.2))
	top.add_child(_heading("Blotline", 104, Sumi.INK))
	var ink_name := String(DataDB.inks.get(GameState.ink_id, {}).get("name", "Blue"))
	var line := "Level %d   %s ink" % [SaveData.char_level(), ink_name]
	if SaveData.is_vip():
		line = "VIP   " + line
	var record := float(SaveData.data.get("best_time", 0.0))
	if record > 0.0:
		line += "   Best %s   Wins %d" % [GameState.format_time(record), int(SaveData.data.get("wins", 0))]
	_body.add_child(_heading(line, 22, Sumi.FADED))
	if _notice != "":
		_body.add_child(_heading(_notice, 22, Sumi.GOLD.darkened(0.2)))
		_notice = ""
	var play := _button("Begin", _show.bind(View.MODES), 360.0, 76.0, 40)
	_body.add_child(play)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	_body.add_child(grid)
	var free := SaveData.skill_points_free()
	grid.add_child(_button("Skills" + (" (%d)" % free if free > 0 else ""), _show.bind(View.SKILLS), 250.0))
	grid.add_child(_button("Inks", _show.bind(View.INKS), 250.0))
	grid.add_child(_button("Boosts", _show.bind(View.BOOSTS), 250.0))
	grid.add_child(_button("Store", _show.bind(View.STORE), 250.0))
	_body.add_child(_button("Settings", _show.bind(View.SETTINGS), 250.0, 50.0, 24))
	play.grab_focus()


# --- Modes -------------------------------------------------------------------

func _build_modes() -> void:
	_body.add_child(_heading("Choose a page", 52, Sumi.INK))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_body.add_child(row)
	var count := DataDB.modes.size()
	var card_width := minf(380.0, (1120.0 - 20.0 * (count - 1)) / count)
	var tight := count > 3
	for id: String in DataDB.modes:
		var def: Dictionary = DataDB.modes[id]
		var card := Button.new()
		card.custom_minimum_size = Vector2(card_width, 340.0)
		card.clip_contents = true
		Sumi.ink_button(card)
		# Reclaim is a campaign: pick a page first.
		if def.has("reclaim"):
			card.pressed.connect(_show.bind(View.LEVELS))
		else:
			card.pressed.connect(_start.bind(id))
		var face := VBoxContainer.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.alignment = BoxContainer.ALIGNMENT_CENTER
		face.add_theme_constant_override("separation", 14)
		card.add_child(face)
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.offset_left = 22.0
		face.offset_right = -22.0
		var name_label := _card_text(String(def.get("name", id)), 34 if tight else 44, Sumi.SEAL if def.has("burn") or def.has("reclaim") else Sumi.INK)
		name_label.add_theme_font_override("font", Sumi.TITLE_FONT)
		face.add_child(name_label)
		face.add_child(_card_text(String(def.get("desc", "")), 15 if tight else 18, Sumi.INK))
		if def.has("reclaim"):
			var cleared := 0
			for i in ReclaimSystem.level_count():
				if ReclaimSystem.stars_of(i) > 0:
					cleared += 1
			face.add_child(_card_text("Pages cleared: %d of %d" % [cleared, ReclaimSystem.level_count()], 15 if tight else 18, Sumi.SEAL))
		if def.has("paint"):
			var next := PaintSystem.next_picture()
			var got := int((SaveData.data.get("pictures", {}) as Dictionary).get(next, 0))
			face.add_child(_card_text("Next: %s (%d/3 stars)" % [String(DataDB.pictures.get(next, {}).get("name", "")), got], 18, Sumi.SEAL))
		row.add_child(card)
		if id == (GameState.mode_id if GameState.mode_picked else "reclaim"):
			card.grab_focus()
	# Items that will be used in the run.
	var bring: Array[String] = []
	for id: String in ["page_wipe", "lasso", "revive"]:
		if SaveData.item_count(id) > 0:
			bring.append("%s x%d" % [String(DataDB.store.get("items", {}).get(id, {}).get("name", id)), SaveData.item_count(id)])
	if not bring.is_empty():
		_body.add_child(_heading("You carry: " + ", ".join(bring), 20, Sumi.FADED))
	if SaveData.item_count("head_start") > 0:
		var on := bool(SaveData.data.get("use_head_start", true))
		_body.add_child(_button("Head Start x%d: %s" % [SaveData.item_count("head_start"), "use one" if on else "save them"], func() -> void:
			SaveData.data["use_head_start"] = not on
			SaveData.save()
			_show(View.MODES), 380.0, 50.0, 22))
	_body.add_child(_back())


# --- Reclaim pages ---------------------------------------------------------

func _build_levels() -> void:
	_body.add_child(_heading("Reclaim: choose a page", 48, Sumi.INK))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body.add_child(grid)
	var focus: Button = null
	for i in ReclaimSystem.level_count():
		var page := ReclaimSystem.level_data(i)
		var open := ReclaimSystem.is_open(i)
		var stars := ReclaimSystem.stars_of(i)
		var button := Button.new()
		button.custom_minimum_size = Vector2(212.0, 118.0)
		button.clip_contents = true
		button.disabled = not open
		Sumi.ink_button(button, 20)
		button.text = "%d  %s\n%s" % [i + 1, String(page.get("name", "")), ("%d of 3 stars" % stars) if open else "Locked"]
		button.tooltip_text = String(page.get("blurb", ""))
		button.pressed.connect(_play_page.bind(i))
		grid.add_child(button)
		if focus == null and open and (stars == 0 or i == ReclaimSystem.level_count() - 1):
			focus = button
	_body.add_child(_heading("Clear a page to open the next. 1 star for winning, 1 under par time, 1 for destroying every source.", 17, Sumi.FADED))
	_body.add_child(_button("Back", _show.bind(View.MODES), 220.0, 50.0, 22))
	if focus != null:
		focus.grab_focus()


func _play_page(index: int) -> void:
	GameState.reclaim_level = index
	_start("reclaim")


func _start(mode_id: String) -> void:
	GameState.mode_picked = true
	GameState.mode_id = mode_id
	get_tree().change_scene_to_file("res://modes/survival.tscn")


# --- Skills ------------------------------------------------------------------

func _build_skills() -> void:
	var level := SaveData.char_level()
	var need := SaveData.char_xp_needed(level)
	var have := int(SaveData.data.get("char_xp", 0))
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 18)
	_body.add_child(top)
	top.add_child(_drop_preview(2.6))
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(info)
	info.add_child(_heading("Level %d" % level, 46, Sumi.INK))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(320.0, 14.0)
	bar.max_value = need
	bar.value = have
	Sumi.meter(bar, Sumi.GOLD)
	info.add_child(bar)
	info.add_child(_heading("%d / %d XP to next level" % [have, need], 18, Sumi.FADED))
	var free := SaveData.skill_points_free()
	info.add_child(_heading("%d skill point%s to spend" % [free, "" if free == 1 else "s"], 24, Sumi.SEAL if free > 0 else Sumi.FADED))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	var branches: Dictionary = DataDB.skills.get("branches", {})
	for branch: String in branches:
		var def: Dictionary = branches[branch]
		var color := Color(String(def.get("color", "#141210")))
		var rank := SaveData.skill_rank(branch)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		row.add_child(column)
		var head := _heading(String(def.get("name", branch)), 30, color)
		column.add_child(head)
		column.add_child(_card_text(String(def.get("tagline", "")), 14, Sumi.FADED))
		var nodes: Array = def.get("nodes", [])
		for i in nodes.size():
			var node: Dictionary = nodes[i]
			var owned := i < rank
			var next := i == rank
			var button := Button.new()
			button.custom_minimum_size = Vector2(238.0, 58.0)
			button.disabled = not (next and free > 0)
			button.pressed.connect(_buy_skill.bind(branch))
			for state in ["normal", "hover", "pressed", "focus", "disabled"]:
				var style := StyleBoxFlat.new()
				style.bg_color = color if owned else (Sumi.PAPER_SHADE if state == "hover" else Sumi.PAPER)
				style.border_color = color if (owned or next) else Color(Sumi.FADED, 0.5)
				style.set_border_width_all(5 if next else 3)
				style.set_corner_radius_all(5)
				button.add_theme_stylebox_override(state, style)
			var face := VBoxContainer.new()
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face.alignment = BoxContainer.ALIGNMENT_CENTER
			face.add_theme_constant_override("separation", 0)
			button.add_child(face)
			face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var ink := Sumi.PAPER if owned else (Sumi.INK if next else Sumi.FADED)
			var name_label := _card_text(String(node.get("name", "")), 19, ink)
			name_label.add_theme_font_override("font", Sumi.TITLE_FONT)
			face.add_child(name_label)
			face.add_child(_card_text(String(node.get("short", "")), 13, ink))
			column.add_child(button)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 14)
	_body.add_child(foot)
	foot.add_child(_button("Reset points", func() -> void:
		SaveData.reset_skills()
		_show(View.SKILLS), 220.0, 50.0, 22))
	foot.add_child(_back())


func _buy_skill(branch: String) -> void:
	if SaveData.buy_skill(branch):
		Audio.play("milestone")
	_show(View.SKILLS)


# --- Inks --------------------------------------------------------------------

func _build_inks() -> void:
	_body.add_child(_heading("Choose your ink", 48, Sumi.INK))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	for id: String in DataDB.inks:
		row.add_child(_ink_card(id))
	_body.add_child(_back())


func _ink_card(id: String) -> Button:
	var def: Dictionary = DataDB.inks[id]
	var vip_only := bool(def.get("vip", false))
	var owned := SaveData.has_ink(id)
	var chosen := id == GameState.ink_id
	var cost := SaveData.ink_cost(id)
	var color := Color(String(def.get("color", "#1a4df2")))
	var card := Button.new()
	card.custom_minimum_size = Vector2(190.0, 400.0)
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
	face.offset_left = 10.0
	face.offset_right = -10.0
	face.offset_top = 12.0
	face.offset_bottom = -10.0

	var swatch := InkSwatch.new()
	swatch.color = color
	swatch.light = Color(String(def.get("light", "#4d8fff")))
	swatch.dimmed = not owned
	swatch.custom_minimum_size = Vector2(0.0, 118.0)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(swatch)
	var name_label := _card_text(String(def.get("name", id)), 30, color.darkened(0.15) if owned else Sumi.FADED)
	name_label.add_theme_font_override("font", Sumi.TITLE_FONT)
	face.add_child(name_label)
	face.add_child(_card_text(String(def.get("tagline", "")).to_upper(), 13, Sumi.SEAL))
	face.add_child(_card_text(String(def.get("desc", "")), 13, Sumi.INK))
	var status := "IN USE" if chosen else ("Tap to use" if owned else ("VIP only" if vip_only else ("Unlock: %d Seals" % cost if SaveData.seals() >= cost else "Locked: %d Seals" % cost)))
	var status_label := _card_text(status, 15, Sumi.SEAL if (chosen or not owned) else Sumi.FADED)
	status_label.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	face.add_child(status_label)
	return card


func _pick_ink(id: String) -> void:
	if not SaveData.has_ink(id):
		if bool(DataDB.inks.get(id, {}).get("vip", false)) or not SaveData.unlock_ink(id):
			Audio.play("fizzle")
			return
		Audio.play("milestone")
	GameState.set_ink(id)
	SaveData.data["ink"] = id
	SaveData.save()
	_show(View.INKS)


# --- Boosts ------------------------------------------------------------------

func _build_boosts() -> void:
	_body.add_child(_heading("Boosts", 48, Sumi.INK))
	_body.add_child(_heading("Permanent, for every run. Bought with Seals, which you earn by playing.", 19, Sumi.FADED))
	var list := _sheet()
	var boosts: Dictionary = DataDB.meta.get("boosts", {})
	for id: String in boosts:
		var def: Dictionary = boosts[id]
		var level := SaveData.boost_level(id)
		var max_level := (def.get("costs", []) as Array).size()
		var cost := SaveData.boost_cost(id)
		var pips := ""
		for i in max_level:
			pips += "● " if i < level else "○ "
		var buy := _button("Maxed" if cost < 0 else "%d Seals" % cost, _buy_boost.bind(id), 190.0, 50.0, 22)
		buy.disabled = cost < 0 or SaveData.seals() < cost
		list.add_child(_row("%s   %s" % [String(def.get("name", id)), pips.strip_edges()], String(def.get("desc", "")), [buy]))
	_body.add_child(_back())


func _buy_boost(id: String) -> void:
	if SaveData.buy_boost(id):
		Audio.play("milestone")
	_show(View.BOOSTS)


## A paper panel holding a list; returns the list to fill.
func _sheet() -> VBoxContainer:
	var sheet := PanelContainer.new()
	var style := Sumi.paper(4)
	style.set_content_margin_all(16)
	sheet.add_theme_stylebox_override("panel", style)
	_body.add_child(sheet)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	sheet.add_child(list)
	return list


## One line of a list: a name, a short description, and buttons on the right.
func _row(title: String, detail: String, buttons: Array, text_width: float = 400.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var text := VBoxContainer.new()
	text.custom_minimum_size = Vector2(text_width, 0.0)
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = title
	Sumi.title(name_label, 24)
	text.add_child(name_label)
	var desc := Label.new()
	desc.text = detail
	Sumi.body(desc, 15, Sumi.FADED)
	text.add_child(desc)
	for button: Button in buttons:
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(button)
	return row


# --- Store -------------------------------------------------------------------

func _build_store() -> void:
	var store: Dictionary = DataDB.store
	_body.add_child(_heading("Store", 44, Sumi.INK))
	_body.add_child(_heading("TEST STORE: purchases are free in this build. No money is charged.", 18, Sumi.SEAL))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900.0, 440.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var sheet := PanelContainer.new()
	var style := Sumi.paper(4)
	style.set_content_margin_all(16)
	style.shadow_size = 0
	sheet.add_theme_stylebox_override("panel", style)
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sheet)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	sheet.add_child(list)

	list.add_child(_section("Gold Leaf"))
	var packs := HBoxContainer.new()
	packs.add_theme_constant_override("separation", 10)
	list.add_child(packs)
	for pack: Dictionary in store.get("packs", []):
		packs.add_child(_button("%s\n%d for %s" % [String(pack.get("name", "")), int(pack.get("gold", 0)), String(pack.get("price", ""))], _buy_pack.bind(pack), 204.0, 76.0, 20))
	var rate: Dictionary = store.get("exchange", {})
	var swap := _button("%d Gold Leaf" % int(rate.get("gold", 50)), _exchange, 190.0, 46.0, 20)
	swap.disabled = SaveData.gold() < int(rate.get("gold", 50))
	list.add_child(_row("Exchange", "Turn Gold Leaf into %d Seals." % int(rate.get("seals", 150)), [swap], 620.0))

	var vip: Dictionary = store.get("vip", {})
	list.add_child(_section("VIP"))
	var vip_button := _button("Owned" if SaveData.is_vip() else String(vip.get("price", "")), _buy_vip, 190.0, 50.0, 22)
	vip_button.disabled = SaveData.is_vip()
	list.add_child(_row(String(vip.get("name", "VIP")), String(vip.get("perks", "")), [vip_button], 620.0))

	list.add_child(_section("Items for a run"))
	var items: Dictionary = store.get("items", {})
	for id: String in items:
		var def: Dictionary = items[id]
		list.add_child(_row("%s   (you have %d)" % [String(def.get("name", id)), SaveData.item_count(id)], String(def.get("short", "")), _price_buttons(def, _buy_item.bind(id))))

	list.add_child(_section("Boosters"))
	var boosters: Dictionary = store.get("boosters", {})
	for id: String in boosters:
		var def: Dictionary = boosters[id]
		var left := SaveData.booster_runs(id)
		list.add_child(_row(String(def.get("name", id)) + ("   (%d runs left)" % left if left > 0 else ""), String(def.get("short", "")), _price_buttons(def, _buy_booster.bind(id))))

	list.add_child(_section("Looks: the seal on your drop"))
	var looks := HBoxContainer.new()
	looks.add_theme_constant_override("separation", 10)
	list.add_child(looks)
	var look_defs: Dictionary = store.get("looks", {})
	for id: String in look_defs:
		var def: Dictionary = look_defs[id]
		var owned := SaveData.has_look(id) or (bool(def.get("vip", false)) and SaveData.is_vip())
		var chosen := String(SaveData.data.get("look", "square")) == id
		var label := "In use" if chosen else ("Use" if owned else ("VIP" if bool(def.get("vip", false)) else "%d Gold" % int(def.get("gold", 0))))
		var button := _button("%s\n%s" % [String(def.get("name", id)), label], _pick_look.bind(id), 160.0, 70.0, 20)
		button.disabled = chosen or (not owned and (bool(def.get("vip", false)) or SaveData.gold() < int(def.get("gold", 0))))
		looks.add_child(button)
	_body.add_child(_back())


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	Sumi.title(label, 28, Sumi.SEAL)
	return label


## Buy buttons for an item priced in Gold Leaf and, optionally, Seals.
func _price_buttons(def: Dictionary, buy: Callable) -> Array:
	var out: Array = []
	if def.has("seals"):
		var with_seals := _button("%d Seals" % int(def["seals"]), buy.bind("seals", int(def["seals"])), 160.0, 46.0, 20)
		with_seals.disabled = SaveData.seals() < int(def["seals"])
		out.append(with_seals)
	var with_gold := _button("%d Gold Leaf" % int(def.get("gold", 0)), buy.bind("gold", int(def.get("gold", 0))), 190.0, 46.0, 20)
	with_gold.disabled = SaveData.gold() < int(def.get("gold", 0))
	out.append(with_gold)
	return out


## A real-money purchase. In this build it is a stand-in: it grants the pack
## and charges nothing. Apple's payment system replaces this call later.
func _buy_pack(pack: Dictionary) -> void:
	SaveData.add_gold(int(pack.get("gold", 0)))
	SaveData.save()
	Audio.play("milestone")
	_show(View.STORE)


func _buy_vip() -> void:
	SaveData.data["vip"] = true
	SaveData.save()
	SaveData.claim_daily()
	Audio.play("victory")
	_show(View.STORE)


func _exchange() -> void:
	var rate: Dictionary = DataDB.store.get("exchange", {})
	if SaveData.spend("gold", int(rate.get("gold", 50))):
		SaveData.add_seals(int(rate.get("seals", 150)))
		SaveData.save()
		Audio.play("milestone")
	_show(View.STORE)


func _buy_item(currency: String, price: int, id: String) -> void:
	if SaveData.spend(currency, price):
		SaveData.add_item(id)
		Audio.play("card")
	_show(View.STORE)


func _buy_booster(currency: String, price: int, id: String) -> void:
	if SaveData.spend(currency, price):
		SaveData.add_booster(id, int(DataDB.store.get("boosters", {}).get(id, {}).get("runs", 5)))
		Audio.play("card")
	_show(View.STORE)


func _pick_look(id: String) -> void:
	var def: Dictionary = DataDB.store.get("looks", {}).get(id, {})
	var owned := SaveData.has_look(id) or (bool(def.get("vip", false)) and SaveData.is_vip())
	if not owned:
		if bool(def.get("vip", false)) or not SaveData.spend("gold", int(def.get("gold", 0))):
			return
		(SaveData.data["looks"] as Array).append(id)
	SaveData.data["look"] = id
	SaveData.save()
	Audio.play("card")
	_show(View.STORE)


# --- Settings ----------------------------------------------------------------

func _build_settings() -> void:
	_body.add_child(_heading("Settings", 52, Sumi.INK))
	for entry: Array in [["sound", "Sound effects"], ["music", "Music"], ["vibration", "Vibration"]]:
		var key: String = entry[0]
		var on := SaveData.setting(key)
		_body.add_child(_button("%s: %s" % [entry[1], "on" if on else "off"], _toggle.bind(key), 380.0))
	_body.add_child(_back())


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
		for corner: Vector2 in [Vector2(0.06, 0.14), Vector2(0.95, 0.9), Vector2(0.93, 0.2), Vector2(0.05, 0.9)]:
			var c := Vector2(corner.x * size.x, corner.y * size.y)
			for k in 4:
				draw_circle(c, 120.0 - k * 14.0, Color(ink, 0.04 + 0.02 * k))
			for k in 8:
				draw_circle(c + Vector2(rng.randf_range(-30, 30), rng.randf_range(-26, 26)), rng.randf_range(28.0, 54.0), Color(ink, 0.9))
			var dir := Vector2.from_angle(rng.randf() * TAU)
			for k in 5:
				draw_circle(c + dir * (62.0 + k * 28.0), 24.0 - k * 4.0, Color(ink, 0.9))
			for k in 14:
				draw_circle(c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(70.0, 170.0), rng.randf_range(3.0, 9.0), Color(ink, 0.9))
		for stroke in 4:
			draw_rect(Rect2(Vector2.ZERO, size).grow(-rng.randf_range(6.0, 16.0)), Color(Sumi.INK, rng.randf_range(0.35, 0.75)), false, rng.randf_range(5.0, 12.0))
