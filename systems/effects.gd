class_name Effects
extends Node2D
## Cheap one-shot visual effects drawn in code (expanding rings for now).

var _rings: Array[Dictionary] = []


func ring(pos: Vector2, radius: float, color: Color, duration: float = 0.35) -> void:
	_rings.append({"pos": pos, "radius": radius, "color": color, "duration": duration, "age": 0.0})
	queue_redraw()


func _process(delta: float) -> void:
	if _rings.is_empty():
		return
	var i := _rings.size() - 1
	while i >= 0:
		_rings[i]["age"] += delta
		if _rings[i]["age"] >= _rings[i]["duration"]:
			_rings.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	for r in _rings:
		var t: float = r["age"] / r["duration"]
		var eased := 1.0 - (1.0 - t) * (1.0 - t)
		var color: Color = r["color"]
		color.a *= 1.0 - t
		var radius: float = r["radius"]
		var pos: Vector2 = r["pos"]
		draw_arc(pos, maxf(4.0, radius * eased), 0.0, TAU, 64, color, 8.0)
