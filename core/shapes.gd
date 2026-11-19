class_name Shapes
extends RefCounted
## Turns a shape from level data into ink-grid cells. A shape is one of
## `{"rect": [x, y, w, h]}`, `{"circle": [x, y, r]}`, `{"ellipse": [x, y, rx, ry]}`
## or `{"poly": [x1, y1, x2, y2, ...]}`, all in page pixels.


static func cells_in(shape: Dictionary, grid: InkGrid) -> PackedInt32Array:
	var found := PackedInt32Array()
	var kind := ""
	for key: String in ["circle", "ellipse", "rect", "poly"]:
		if shape.has(key):
			kind = key
	if kind == "":
		return found
	var v: Array = shape[kind]
	var box := Rect2()
	var poly := PackedVector2Array()
	match kind:
		"circle":
			box = Rect2(float(v[0]) - float(v[2]), float(v[1]) - float(v[2]), float(v[2]) * 2.0, float(v[2]) * 2.0)
		"ellipse":
			box = Rect2(float(v[0]) - float(v[2]), float(v[1]) - float(v[3]), float(v[2]) * 2.0, float(v[3]) * 2.0)
		"rect":
			box = Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
		"poly":
			for i in range(0, v.size() - 1, 2):
				poly.append(Vector2(float(v[i]), float(v[i + 1])))
				box = Rect2(poly[0], Vector2.ZERO) if poly.size() == 1 else box.expand(poly[-1])
	var centre := box.get_center()
	var half := box.size * 0.5
	var x0 := clampi(int(box.position.x / grid.cell_size), 0, grid.cols - 1)
	var x1 := clampi(int(box.end.x / grid.cell_size), 0, grid.cols - 1)
	var y0 := clampi(int(box.position.y / grid.cell_size), 0, grid.rows - 1)
	var y1 := clampi(int(box.end.y / grid.cell_size), 0, grid.rows - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2((x + 0.5) * grid.cell_size, (y + 0.5) * grid.cell_size)
			var inside := true
			if kind == "circle" or kind == "ellipse":
				var d := (p - centre) / half
				inside = d.length_squared() <= 1.0
			elif kind == "poly":
				inside = Geometry2D.is_point_in_polygon(p, poly)
			if inside:
				found.append(y * grid.cols + x)
	return found
