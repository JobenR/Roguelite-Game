extends Node2D
## A faint dotted line showing where shots will go. Turns red and gains a
## reticle while the Auto-Aim power is active.

const LENGTH := 150.0

var _locked: bool = false


func set_locked(locked: bool) -> void:
	if locked != _locked:
		_locked = locked
		queue_redraw()


func _draw() -> void:
	var color := Color(0.88, 0.11, 0.28, 0.75) if _locked else Color(0.08, 0.07, 0.06, 0.4)
	var x := 34.0
	while x < LENGTH:
		draw_line(Vector2(x, 0.0), Vector2(x + 8.0, 0.0), color, 3.0)
		x += 18.0
	if _locked:
		draw_arc(Vector2(LENGTH + 10.0, 0.0), 9.0, 0.0, TAU, 20, color, 3.0)
