class_name Arena
extends Node2D
## Draws the page: paper background, faint ruled lines, and the border.

const PAPER := Color("#f4efe1")
const RULE := Color("#d9d2bd")
const BORDER := Color("#3b352b")
const RULE_SPACING := 120.0

var rect: Rect2 = Rect2()


func setup(p_rect: Rect2) -> void:
	rect = p_rect
	queue_redraw()


func _draw() -> void:
	draw_rect(rect, PAPER)
	var y := rect.position.y + RULE_SPACING
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), RULE, 2.0)
		y += RULE_SPACING
	var x := rect.position.x + RULE_SPACING
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), RULE, 2.0)
		x += RULE_SPACING
	draw_rect(rect, BORDER, false, 12.0)
