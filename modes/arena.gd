class_name Arena
extends Node2D
## Draws the page in the Sumi-e look: a sheet of rice paper with visible
## fibres, a brushed black frame, and a red seal in the corner.
## Everything is drawn once; the canvas caches it.

const PAPER := Color("#efe6d2")
const FIBRE := Color("#b9a98a")
const INK := Color("#141210")
const SEAL := Color("#c1272d")

var rect: Rect2 = Rect2()


func setup(p_rect: Rect2) -> void:
	rect = p_rect
	queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20241
	# Soft shadow under the page.
	for i in 4:
		draw_rect(rect.grow(10.0 + i * 12.0), Color(0, 0, 0, 0.12))
	draw_rect(rect, PAPER)
	# Fibres: thousands of short pale strands.
	for i in 4200:
		var at := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		var length := rng.randf_range(6.0, 46.0)
		var lean := rng.randf_range(-0.25, 0.25)
		draw_line(at, at + Vector2(length, length * lean), Color(FIBRE, rng.randf_range(0.12, 0.5)), rng.randf_range(1.0, 2.5))
	# A brushed frame: several uneven passes instead of one clean line.
	for stroke in 5:
		var inset := rng.randf_range(-6.0, 8.0)
		var frame := rect.grow(-inset)
		var width := rng.randf_range(6.0, 16.0)
		draw_rect(frame, Color(INK, rng.randf_range(0.35, 0.8)), false, width)
	# The artist's seal, bottom right.
	var seal := Rect2(rect.end - Vector2(190.0, 190.0), Vector2(110.0, 110.0))
	draw_rect(seal, SEAL)
	draw_rect(seal.grow(-14.0), PAPER, false, 7.0)
	draw_line(seal.position + Vector2(34.0, 30.0), seal.position + Vector2(34.0, 80.0), PAPER, 7.0)
	draw_line(seal.position + Vector2(76.0, 30.0), seal.position + Vector2(76.0, 80.0), PAPER, 7.0)
	draw_line(seal.position + Vector2(34.0, 55.0), seal.position + Vector2(76.0, 55.0), PAPER, 7.0)
