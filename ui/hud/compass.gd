extends Control
## Reclaim mode: an arrow at the screen edge for each ink source that is off
## screen, so you always know where the next one is.

var reclaim: ReclaimSystem


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if reclaim == null:
		return
	var view := Rect2(Vector2.ZERO, size)
	var inner := view.grow(-54.0)
	var centre := view.get_center()
	var to_screen := get_viewport().get_canvas_transform()
	for source in reclaim.sources:
		if not bool(source["alive"]):
			continue
		var at: Vector2 = to_screen * (source["pos"] as Vector2)
		if view.grow(-20.0).has_point(at):
			continue
		var dir := (at - centre).normalized()
		# Walk from the centre toward the source until the edge of the inner box.
		var reach := 1.0e6
		if absf(dir.x) > 0.001:
			reach = minf(reach, (inner.size.x * 0.5) / absf(dir.x))
		if absf(dir.y) > 0.001:
			reach = minf(reach, (inner.size.y * 0.5) / absf(dir.y))
		var tip := centre + dir * reach
		var side := dir.orthogonal()
		var shape := PackedVector2Array([tip + dir * 16.0, tip - dir * 10.0 + side * 13.0, tip - dir * 10.0 - side * 13.0])
		draw_colored_polygon(shape, Color("#ff3d8b"))
		draw_polyline(PackedVector2Array([shape[0], shape[1], shape[2], shape[0]]), Sumi.INK, 3.0)
