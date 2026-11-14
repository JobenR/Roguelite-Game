class_name Sumi
extends RefCounted
## Shared look for every screen: rice paper panels, black ink, a red seal
## accent, and a brush-script title font. UI code takes colours, fonts and
## panel styles from here so the screens stay consistent.

const PAPER := Color("#efe6d2")
const PAPER_SHADE := Color("#e0d3b4")
const INK := Color("#141210")
const FADED := Color("#5f574a")
const SEAL := Color("#c1272d")
const GOLD := Color("#c9962a")
const GLOW := Color("#2f6bff")
const TITLE_FONT := preload("res://assets/fonts/KaushanScript-Regular.ttf")


## A sheet of rice paper with a brushed ink border.
static func paper(border: int = 5, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = INK
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2(3, 5)
	style.set_content_margin_all(26)
	return style


## Brush-script text, for titles and names.
static func title(label: Label, size: int, color: Color = INK) -> void:
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


## Plain text in ink.
static func body(label: Label, size: int, color: Color = INK) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


## Text that sits over the playfield: ink with a paper edge, so it reads on
## both bare paper and black ink.
static func overlay(label: Label, size: int, color: Color = INK) -> void:
	title(label, size, color)
	label.add_theme_color_override("font_outline_color", PAPER)
	label.add_theme_constant_override("outline_size", 7)


## A paper button with an ink border; it inverts to ink when pressed.
static func ink_button(button: Button, size: int = 26) -> void:
	button.add_theme_font_override("font", TITLE_FONT)
	button.add_theme_font_size_override("font_size", size)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = INK if state == "pressed" else (PAPER_SHADE if state == "hover" else PAPER)
		style.border_color = SEAL if state == "focus" else INK
		style.set_border_width_all(4)
		style.set_corner_radius_all(5)
		style.set_content_margin_all(10)
		if state == "focus":
			style.draw_center = false
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_pressed_color", PAPER)
	button.add_theme_color_override("font_disabled_color", FADED)


## A meter: an ink-edged trough with a coloured fill.
static func meter(bar: ProgressBar, fill_color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(2)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(PAPER, 0.85)
	back.border_color = INK
	back.set_border_width_all(2)
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
