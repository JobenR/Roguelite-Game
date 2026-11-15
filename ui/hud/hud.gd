extends Control
## In-run HUD: health, weapon charges, run timer, ink share, kills.
## Built in code for now.

var _ink: InkSystem
var _milestones: MilestoneSystem
var _hp_bar: ProgressBar
var _bomb_bar: ProgressBar
var _pulse_bar: ProgressBar
var _time_label: Label
var _kills_label: Label
var _xp_bar: ProgressBar
var _banner: Label
var _banner_left: float = 0.0
var _wave_label: Label
var _wave_countdown: float = 0.0
var _wave_number: int = 0
var _wave_show_left: float = 0.0
var _power_label: Label
var _hurt: ColorRect
var _last_hp: float = -1.0
var _wave_tag: String = ""
var _alert_text: String = ""
var _alert_left: float = 0.0
var _boss_bar: ProgressBar
var _boss_label: Label
var _shield_bar: ProgressBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Red flash when hit. Oversized so it covers the screen past the safe area.
	_hurt = ColorRect.new()
	_hurt.color = Color(0.85, 0.05, 0.05, 0.0)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hurt)
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.offset_left = -400.0
	_hurt.offset_top = -400.0
	_hurt.offset_right = 400.0
	_hurt.offset_bottom = 400.0
	_hp_bar = _make_bar(Vector2(0.0, 0.0), Vector2(260.0, 22.0), Sumi.SEAL)
	_bomb_bar = _make_bar(Vector2(0.0, 27.0), Vector2(126.0, 10.0), Sumi.GLOW.darkened(0.35))
	_pulse_bar = _make_bar(Vector2(134.0, 27.0), Vector2(126.0, 10.0), Sumi.GLOW)
	_bomb_bar.max_value = 1.0
	_pulse_bar.max_value = 1.0
	_time_label = _make_label(Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	_kills_label = _make_label(Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	_xp_bar = _make_bar(Vector2.ZERO, Vector2(320.0, 10.0), Sumi.GOLD)
	_xp_bar.anchor_left = 0.5
	_xp_bar.anchor_right = 0.5
	_xp_bar.offset_left = -160.0
	_xp_bar.offset_right = 160.0
	_xp_bar.offset_top = 40.0
	_xp_bar.offset_bottom = 50.0
	_banner = _make_label(Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	Sumi.overlay(_banner, 30, Sumi.GOLD.darkened(0.25))
	_banner.offset_top = 64.0
	_banner.visible = false
	_wave_label = _make_label(Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	Sumi.overlay(_wave_label, 50, Sumi.SEAL)
	_wave_label.offset_top = 130.0
	_wave_label.visible = false
	_power_label = _make_label(Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	Sumi.overlay(_power_label, 24, Sumi.SEAL)
	_power_label.offset_top = 52.0
	# Boss health: a wide bar along the bottom, shown only during a boss.
	_boss_bar = _make_bar(Vector2.ZERO, Vector2(520.0, 18.0), Color("#ff5fa8"))
	_boss_bar.anchor_left = 0.5
	_boss_bar.anchor_right = 0.5
	_boss_bar.anchor_top = 1.0
	_boss_bar.anchor_bottom = 1.0
	_boss_bar.offset_left = -260.0
	_boss_bar.offset_right = 260.0
	_boss_bar.offset_top = -30.0
	_boss_bar.offset_bottom = -12.0
	_boss_bar.max_value = 1.0
	_boss_bar.visible = false
	_boss_label = _make_label(Control.PRESET_CENTER_BOTTOM, HORIZONTAL_ALIGNMENT_CENTER)
	Sumi.overlay(_boss_label, 28)
	_boss_label.offset_top = -66.0
	_boss_label.offset_bottom = -34.0
	_boss_label.visible = false
	Events.boss_spawned.connect(func(boss_name: String) -> void:
		_boss_label.text = boss_name.to_upper()
		_boss_label.visible = true
		_boss_bar.visible = true)
	Events.boss_health_changed.connect(func(ratio: float) -> void: _boss_bar.value = ratio)
	Events.boss_defeated.connect(func(boss_name: String) -> void:
		_boss_label.visible = false
		_boss_bar.visible = false
		_show_banner("%s DEFEATED" % boss_name.to_upper()))
	Events.alert.connect(func(text: String, seconds: float) -> void:
		_alert_text = text
		_alert_left = seconds)
	Events.strip_burned.connect(func(index: int, share: float, xp: int, perfect: bool) -> void:
		_show_banner("STRIP %d BURNT: %d%% SAVED\n+%d XP%s" % [index, int(round(share * 100.0)), xp, "  PERFECT" if perfect else ""]))
	Events.wave_warning.connect(_on_wave_warning)
	Events.wave_started.connect(_on_wave_started)
	Events.player_health_changed.connect(_on_health_changed)
	Events.xp_changed.connect(_on_xp_changed)
	Events.synergy_unlocked.connect(_on_synergy)
	Events.set_bonus.connect(func(set_name: String, count: int, desc: String) -> void:
		_show_banner("%s SET x%d\n%s" % [set_name.to_upper(), count, desc]))
	# Ink Reserve shield: a thin cyan bar over the health bar.
	_shield_bar = _make_bar(Vector2(0.0, -7.0), Vector2(260.0, 6.0), Color("#22d3ee"))
	_shield_bar.visible = false
	Events.shield_changed.connect(func(value: float, max_value: float) -> void:
		_shield_bar.visible = max_value > 0.0
		_shield_bar.max_value = maxf(max_value, 1.0)
		_shield_bar.value = value)
	Events.milestone_reached.connect(func(percent: int, text: String) -> void: _show_banner("INK %d%% REACHED\n%s" % [percent, text]))
	Events.secondary_charge_changed.connect(func(ratio: float) -> void: _bomb_bar.value = ratio)
	Events.pulse_charge_changed.connect(func(ratio: float) -> void: _pulse_bar.value = ratio)


func setup(ink: InkSystem, milestones: MilestoneSystem) -> void:
	_ink = ink
	_milestones = milestones


func _make_bar(pos: Vector2, bar_size: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.position = pos
	bar.custom_minimum_size = bar_size
	bar.size = bar_size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sumi.meter(bar, color)
	add_child(bar)
	return bar


func _make_label(preset: Control.LayoutPreset, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	Sumi.overlay(label, 28)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH if align == HORIZONTAL_ALIGNMENT_CENTER else Control.GROW_DIRECTION_BEGIN
	return label


func _process(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner.visible = _banner_left > 0.0
	_hurt.color.a = maxf(0.0, _hurt.color.a - delta * 1.2)
	_update_wave_label(delta)
	var power_text := ""
	for id: String in GameState.powers:
		var def: Dictionary = DataDB.pickups.get("types", {}).get(id, {})
		power_text += "%s %ds  " % [String(def.get("name", id.replace("_", " "))).to_upper(), int(ceil(GameState.power_left(id)))]
	_power_label.text = power_text.strip_edges()
	var ink_text := ""
	if _ink != null and _ink.grid != null:
		# Floor, so the number never shows a milestone before it is reached.
		ink_text = "   Ink %d%%" % int(_ink.ownership() * 100.0)
		if _milestones != null and _milestones.next_percent() > 0:
			ink_text += " > %d%%" % _milestones.next_percent()
	_time_label.text = "%s   Lv %d%s" % [GameState.format_time(GameState.run_time), GameState.level, ink_text]
	_kills_label.text = "Kills %d" % GameState.kills


func _on_health_changed(hp: float, max_hp: float) -> void:
	if _last_hp >= 0.0 and hp < _last_hp:
		_hurt.color.a = 0.35
	_last_hp = hp
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp


func _on_xp_changed(xp: int, xp_to_next: int, _level: int) -> void:
	_xp_bar.max_value = xp_to_next
	_xp_bar.value = xp


func _on_synergy(synergy_name: String, desc: String) -> void:
	_show_banner("SYNERGY: %s\n%s" % [synergy_name, desc])


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true
	_banner_left = 4.0


func _on_wave_warning(number: int, seconds: float, label: String) -> void:
	_wave_number = number
	_wave_tag = label
	_wave_countdown = seconds
	_wave_show_left = 0.0


func _on_wave_started(index: int) -> void:
	_wave_number = index + 1
	_wave_countdown = 0.0
	_wave_show_left = 2.0


func _update_wave_label(delta: float) -> void:
	if _alert_left > 0.0:
		# Boss alerts take the slot over wave messages.
		_alert_left -= delta
		_wave_countdown = maxf(0.0, _wave_countdown - delta)
		_wave_label.text = _alert_text
		_wave_label.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.01))
		_wave_label.visible = true
	elif _wave_countdown > 0.0:
		_wave_countdown -= delta
		var what := "WAVE %d" % _wave_number if _wave_tag == "" else "WAVE %d: %s" % [_wave_number, _wave_tag]
		_wave_label.text = "%s INCOMING  %d" % [what, int(ceil(maxf(_wave_countdown, 0.0)))]
		# Pulse the warning so it catches the eye.
		_wave_label.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.008))
		_wave_label.visible = true
	elif _wave_show_left > 0.0:
		_wave_show_left -= delta
		_wave_label.text = "WAVE %d" % _wave_number if _wave_tag == "" else "WAVE %d: %s" % [_wave_number, _wave_tag]
		_wave_label.modulate.a = clampf(_wave_show_left, 0.0, 1.0)
		_wave_label.visible = true
	else:
		_wave_label.visible = false
