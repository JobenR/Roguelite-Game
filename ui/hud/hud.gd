extends Control
## In-run HUD: health bar, run timer, kill count. Built in code for now.

var _hp_bar: ProgressBar
var _time_label: Label
var _kills_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(260.0, 22.0)
	_hp_bar.size = Vector2(260.0, 22.0)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#d9363e")
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	_hp_bar.add_theme_stylebox_override("background", back)
	add_child(_hp_bar)

	_time_label = _make_label(Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	_kills_label = _make_label(Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)

	Events.player_health_changed.connect(_on_health_changed)


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
	_time_label.text = GameState.format_time(GameState.run_time)
	_kills_label.text = "Kills %d" % GameState.kills


func _on_health_changed(hp: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
