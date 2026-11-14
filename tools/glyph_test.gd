extends SceneTree
## Headless checks for glyph recognition: draws outlines on an ink grid the way
## a player would, fills them like a pulse, and classifies the result.
##   godot --headless --script res://tools/glyph_test.gd


func _init() -> void:
	var failures := 0
	var c := Vector2(800, 800)
	failures += _check("circle", _kind(_ring(c, 150.0, 0.0)), "circle")
	failures += _check("wobbly circle", _kind(_ring(c, 150.0, 18.0)), "circle")
	failures += _check("oval", _kind(_oval(c, 190.0, 130.0)), "circle")
	failures += _check("triangle", _kind(_poly(c, 3, 190.0, -PI / 2.0, 0.0)), "triangle")
	failures += _check("tilted triangle", _kind(_poly(c, 3, 190.0, 0.4, 0.0)), "triangle")
	failures += _check("wobbly triangle", _kind(_poly(c, 3, 190.0, 1.1, 10.0)), "triangle")
	failures += _check("square", _kind(_poly(c, 4, 180.0, PI / 4.0, 0.0)), "square")
	failures += _check("tilted square", _kind(_poly(c, 4, 180.0, 0.2, 0.0)), "square")
	failures += _check("wobbly square", _kind(_poly(c, 4, 180.0, 0.9, 10.0)), "square")
	failures += _check("rectangle", _kind(_rect(c, 260.0, 150.0)), "square")
	# Small shapes, near the minimum size that counts as a glyph.
	failures += _check("small circle", _kind(_ring(c, 55.0, 0.0)), "circle")
	failures += _check("small triangle", _kind(_poly(c, 3, 85.0, 0.3, 0.0)), "triangle")
	failures += _check("small square", _kind(_poly(c, 4, 70.0, 0.5, 0.0)), "square")
	failures += _check("large circle", _kind(_ring(c, 290.0, 20.0)), "circle")
	failures += _check("large triangle", _kind(_poly(c, 3, 300.0, 2.0, 14.0)), "triangle")
	failures += _check("large square", _kind(_poly(c, 4, 300.0, 1.3, 14.0)), "square")
	failures += _check("pentagon reads as circle", _kind(_poly(c, 5, 180.0, 0.0, 0.0)), "circle")
	print("glyph_test: %s" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	quit(failures)


func _kind(outline: PackedVector2Array) -> String:
	var grid := InkGrid.new(Vector2(1600, 1600), 8.0)
	for i in outline.size():
		grid.paint_line(outline[i], outline[(i + 1) % outline.size()], 6.0, InkGrid.INK)
	var filled := grid.find_enclosed(Vector2(800, 800), 320.0)
	var points := PackedVector2Array()
	for index in filled:
		points.append(grid.cell_center(index))
	var shape := ShapeClassifier.classify(points, filled.size() * 64.0, 0.1, 0.7)
	return String(shape["kind"])


func _ring(center: Vector2, radius: float, wobble: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 90:
		var a := TAU * i / 90.0
		out.append(center + Vector2.from_angle(a) * (radius + sin(a * 5.0) * wobble))
	return out


func _oval(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 90:
		var a := TAU * i / 90.0
		out.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return out


## A regular polygon whose sides bow in and out by `wobble`, like a shaky hand.
func _poly(center: Vector2, sides: int, radius: float, rotation: float, wobble: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for s in sides:
		var a := center + Vector2.from_angle(rotation + TAU * s / sides) * radius
		var b := center + Vector2.from_angle(rotation + TAU * (s + 1) / sides) * radius
		var normal := (b - a).orthogonal().normalized()
		for k in 12:
			var t := k / 12.0
			out.append(a.lerp(b, t) + normal * sin(t * PI * 3.0) * wobble)
	return out


func _rect(center: Vector2, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(-w, -h) * 0.5, center + Vector2(w, -h) * 0.5, center + Vector2(w, h) * 0.5, center + Vector2(-w, h) * 0.5])


func _check(label: String, got: String, want: String) -> int:
	print("  [%s] %s -> %s" % ["ok" if got == want else "FAIL", label, got if got != "" else "(none)"])
	return 0 if got == want else 1
