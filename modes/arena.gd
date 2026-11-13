class_name Arena
extends Node2D
## Draws the page: a sheet of ruled notebook paper lying on a dark desk.

const PAPER := Color("#f6f1e3")
const PAPER_EDGE := Color("#e9e1cc")
const RULE := Color(0.45, 0.62, 0.85, 0.35)
const MARGIN_LINE := Color(0.85, 0.3, 0.3, 0.4)
const BORDER := Color("#2b2620")
const RULE_SPACING := 64.0

var rect: Rect2 = Rect2()


func setup(p_rect: Rect2) -> void:
	rect = p_rect
	queue_redraw()


func _draw() -> void:
	# Soft shadow under the page.
	for i in 4:
		draw_rect(rect.grow(10.0 + i * 10.0), Color(0, 0, 0, 0.10))
	draw_rect(rect, PAPER)
	# Slightly darker band toward the edges, like worn paper.
	for i in 5:
		draw_rect(rect.grow(-i * 14.0), Color(PAPER_EDGE, 0.5 - i * 0.1), false, 14.0)
	var y := rect.position.y + RULE_SPACING
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), RULE, 2.0)
		y += RULE_SPACING
	var margin_x := rect.position.x + 200.0
	draw_line(Vector2(margin_x, rect.position.y), Vector2(margin_x, rect.end.y), MARGIN_LINE, 3.0)
	draw_rect(rect, BORDER, false, 10.0)
