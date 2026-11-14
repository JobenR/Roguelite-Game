class_name InkSwatch
extends Control
## A splat of one ink, drawn in code. Used as the picture on ink cards.

var color: Color = Color.BLUE
var light: Color = Color.CYAN
var dimmed: bool = false


func _draw() -> void:
	var c := size * 0.5
	var ink := color.lerp(Sumi.PAPER, 0.6) if dimmed else color
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(color.to_html())
	# Bleed halo, lumpy core, a streak, and droplets.
	for i in 4:
		draw_circle(c, 62.0 - i * 6.0, Color(ink, 0.06 + 0.03 * i))
	for i in 7:
		draw_circle(c + Vector2(rng.randf_range(-16, 16), rng.randf_range(-12, 12)), rng.randf_range(22.0, 34.0), ink)
	var dir := Vector2.from_angle(rng.randf_range(-0.6, 0.6))
	for i in 4:
		draw_circle(c + dir * (34.0 + i * 15.0), 13.0 - i * 2.6, ink)
	for i in 12:
		draw_circle(c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(44.0, 80.0), rng.randf_range(2.0, 6.0), ink)
	if not dimmed:
		draw_circle(c + Vector2(-10, -8), 12.0, Color(light, 0.55))
