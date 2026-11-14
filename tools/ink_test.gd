extends SceneTree
## Headless checks for loop detection. Usage:
##   godot --headless --script res://tools/ink_test.gd


func _init() -> void:
	var failures := 0
	failures += _check("closed ring fills its inside", _ring_count(false, Vector2(800, 800)) > 0)
	failures += _check("ring cut by a smudge does not fill", _ring_count(true, Vector2(800, 800)) == 0)
	failures += _check("empty page has nothing enclosed", InkGrid.new(Vector2(1600, 1600), 16.0).find_enclosed(Vector2(800, 800), 320.0).is_empty())
	# A loop larger than the pulse reach is not enclosed.
	var big := InkGrid.new(Vector2(3200, 3200), 16.0)
	_draw_ring(big, Vector2(1600, 1600), 600.0)
	failures += _check("loop bigger than the reach does not fill", big.find_enclosed(Vector2(1600, 1600), 320.0).is_empty())
	# An arc against the page edge counts as closed.
	var edge := InkGrid.new(Vector2(1600, 1600), 16.0)
	_draw_ring(edge, Vector2(0, 800), 150.0)
	failures += _check("arc closed by the page edge fills", edge.find_enclosed(Vector2(60, 800), 320.0).size() > 0)
	# Forgiving Pulse: a ring with a small gap fills only when gaps are forgiven.
	var gapped := InkGrid.new(Vector2(1600, 1600), 8.0)
	for i in 700:
		gapped.paint_circle(Vector2(800, 800) + Vector2.from_angle(0.06 + (TAU - 0.12) * i / 700.0) * 150.0, 6.0, InkGrid.INK)
	failures += _check("gapped ring does not fill by default", gapped.find_enclosed(Vector2(800, 800), 320.0).is_empty())
	failures += _check("gapped ring fills with gap forgiveness", gapped.find_enclosed(Vector2(800, 800), 320.0, 2).size() > 1000)
	var line := InkGrid.new(Vector2(1600, 1600), 8.0)
	line.paint_line(Vector2(600, 800), Vector2(1000, 800), 6.0, InkGrid.INK)
	failures += _check("a straight line encloses nothing even with forgiveness", line.find_enclosed(Vector2(800, 800), 320.0, 3).is_empty())
	# Permanent ink cannot be smudged and still counts as ink.
	var perm := InkGrid.new(Vector2(160, 160), 8.0)
	perm.set_cell(5, InkGrid.LOCKED)
	perm.set_cell(5, InkGrid.SMUDGE)
	failures += _check("locked ink resists smudge", perm.cells[5] == InkGrid.LOCKED and perm.ink_count == 1)
	print("ink_test: %s" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	quit(failures)


func _ring_count(cut: bool, center: Vector2) -> int:
	var grid := InkGrid.new(Vector2(1600, 1600), 16.0)
	_draw_ring(grid, center, 150.0)
	if cut:
		for i in 12:
			grid.paint_point(center + Vector2(110.0 + i * 8.0, 0.0), InkGrid.SMUDGE)
	return grid.find_enclosed(center, 320.0).size()


func _draw_ring(grid: InkGrid, center: Vector2, radius: float) -> void:
	for i in 720:
		grid.paint_circle(center + Vector2.from_angle(TAU * i / 720.0) * radius, 20.0, InkGrid.INK)


func _check(label: String, ok: bool) -> int:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	return 0 if ok else 1
