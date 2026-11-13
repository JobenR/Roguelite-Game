class_name Effects
extends Node2D
## Cheap one-shot visual effects drawn in code: expanding rings, droplet
## bursts, and beams. Particle count is capped.

const MAX_DROPS := 220

var _rings: Array[Dictionary] = []
var _drops: Array[Dictionary] = []
var _beams: Array[Dictionary] = []


func ring(pos: Vector2, radius: float, color: Color, duration: float = 0.35) -> void:
	_rings.append({"pos": pos, "radius": radius, "color": color, "duration": duration, "age": 0.0})


## Droplets flung from pos, biased along dir (zero dir = all directions).
func burst(pos: Vector2, dir: Vector2, color: Color, count: int = 6) -> void:
	for i in count:
		if _drops.size() >= MAX_DROPS:
			return
		var spread := Vector2.from_angle(randf() * TAU) * randf_range(40.0, 170.0)
		_drops.append({
			"pos": pos, "vel": dir * randf_range(120.0, 260.0) + spread,
			"color": color, "size": randf_range(2.5, 5.5), "duration": randf_range(0.25, 0.5), "age": 0.0,
		})


func beam(from: Vector2, to: Vector2, color: Color, width: float, duration: float = 0.25) -> void:
	_beams.append({"from": from, "to": to, "color": color, "width": width, "duration": duration, "age": 0.0})


func _process(delta: float) -> void:
	if _rings.is_empty() and _drops.is_empty() and _beams.is_empty():
		return
	_age(_rings, delta)
	_age(_beams, delta)
	var i := _drops.size() - 1
	while i >= 0:
		var drop := _drops[i]
		drop["age"] += delta
		if drop["age"] >= drop["duration"]:
			_drops.remove_at(i)
		else:
			var vel: Vector2 = drop["vel"]
			drop["pos"] += vel * delta
			drop["vel"] = vel * (1.0 - 4.0 * delta)
		i -= 1
	queue_redraw()


func _age(list: Array[Dictionary], delta: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		list[i]["age"] += delta
		if list[i]["age"] >= list[i]["duration"]:
			list.remove_at(i)
		i -= 1


func _draw() -> void:
	for b in _beams:
		var t: float = b["age"] / b["duration"]
		var color: Color = b["color"]
		var width: float = b["width"]
		var from: Vector2 = b["from"]
		var to: Vector2 = b["to"]
		draw_line(from, to, Color(color, 0.35 * (1.0 - t)), width * 2.4)
		draw_line(from, to, Color(color, 1.0 - t), width * (1.0 - t * 0.5))
		draw_line(from, to, Color(1, 1, 1, 0.9 * (1.0 - t)), width * 0.3)
	for r in _rings:
		var t: float = r["age"] / r["duration"]
		var eased := 1.0 - (1.0 - t) * (1.0 - t)
		var color: Color = r["color"]
		var radius: float = maxf(4.0, float(r["radius"]) * eased)
		var pos: Vector2 = r["pos"]
		draw_circle(pos, radius, Color(color, color.a * 0.12 * (1.0 - t)))
		draw_arc(pos, radius, 0.0, TAU, 64, Color(color, color.a * (1.0 - t)), 10.0 * (1.0 - t * 0.6))
	for d in _drops:
		var t: float = d["age"] / d["duration"]
		var color: Color = d["color"]
		var size: float = d["size"]
		var pos: Vector2 = d["pos"]
		draw_circle(pos, size * (1.0 - t * 0.6), Color(color, 1.0 - t * t))
