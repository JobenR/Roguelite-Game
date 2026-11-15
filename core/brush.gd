class_name Brush
extends RefCounted
## Drawing helpers for the brush-ink look, shared by everything that is drawn
## in code outside ShapeVisual (extra weapons, hazards, pickups).


## A ragged blot of ink with a soft halo. `key` makes each blot's outline
## different but steady from frame to frame.
static func blot(canvas: CanvasItem, pos: Vector2, radius: float, color: Color, key: float = 0.0, halo: bool = true) -> void:
	if halo:
		canvas.draw_circle(pos, radius * 1.7, Color(color, 0.10))
		canvas.draw_circle(pos, radius * 1.35, Color(color, 0.14))
	var points := PackedVector2Array()
	for i in 14:
		var angle := TAU * i / 14.0
		var wobble := 1.0 + 0.13 * sin(angle * 3.0 + key * 1.7) + 0.08 * sin(angle * 7.0 + key * 3.1)
		points.append(pos + Vector2.from_angle(angle) * radius * wobble)
	canvas.draw_colored_polygon(points, color)


## A small bright core, like the ones enemies carry.
static func core(canvas: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	for i in 3:
		canvas.draw_circle(pos, radius * (2.4 - i * 0.5), Color(color, 0.12 + 0.08 * i))
	canvas.draw_circle(pos, radius, color)
	canvas.draw_circle(pos, radius * 0.45, Color.WHITE)
