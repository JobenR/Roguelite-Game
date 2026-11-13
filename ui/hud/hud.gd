extends Control
## In-run HUD: health, weapon charges, run timer, ink share, kills.
## Built in code for now.

var _ink: InkSystem
var _hp_bar: ProgressBar
var _bomb_bar: ProgressBar
var _pulse_bar: ProgressBar
var _time_label: Label
var _kills_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar = _make_bar(Vector2(0.0, 0.0), Vector2(260.0, 22.0), Color("#d9363e"))
	_bomb_bar = _make_bar(Vector2(0.0, 26.0), Vector2(126.0, 8.0), Color("#0f1f4d"))
	_pulse_bar = _make_bar(Vector2(134.0, 26.0), Vector2(126.0, 8.0), Color("#3873f2"))
	_bomb_bar.max_value = 1.0
	_pulse_bar.max_value = 1.0
	_time_label = _make_label(Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	_kills_label = _make_label(Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	Events.player_health_changed.connect(_on_health_changed)
	Events.secondary_charge_changed.connect(func(ratio: float) -> void: _bomb_bar.value = ratio)
	Events.pulse_charge_changed.connect(func(ratio: float) -> void: _pulse_bar.value = ratio)


func setup(ink: InkSystem) -> void:
	_ink = ink


func _make_bar(pos: Vector2, bar_size: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.position = pos
	bar.custom_minimum_size = bar_size
	bar.size = bar_size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	add_child(bar)
	return bar


func _make_label(preset: Control.LayoutPreset, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH if align == HORIZONTAL_ALIGNMENT_CENTER else Control.GROW_DIRECTION_BEGIN
	return label


func _process(_delta: float) -> void:
	var ink_text := ""
	if _ink != null and _ink.grid != null:
		ink_text = "   Ink %d%%" % int(round(_ink.ownership() * 100.0))
	_time_label.text = GameState.format_time(GameState.run_time) + ink_text
	_kills_label.text = "Kills %d" % GameState.kills


func _on_health_changed(hp: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
