extends SceneTree
## Headless checks for Masterpiece mode: the picture, colours, wells, the
## Deluge fill, the lull and the stars.
##   godot --headless --fixed-fps 60 --script res://tools/paint_test.gd

var _frames: int = 0
var _failures: int = 0
var _paint: Node
var _kills: int = 0


func _initialize() -> void:
	root.get_node("GameState").mode_id = "masterpiece"
	change_scene_to_file("res://modes/survival.tscn")


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failures += 1


func _process(_delta: float) -> bool:
	_frames += 1
	var scene := current_scene
	if scene == null:
		return false
	var gs := root.get_node("GameState")
	var save := root.get_node("SaveData")
	var grid: InkGrid = scene.ink.grid
	scene.player.hp = scene.player.max_hp
	if scene.levelup.is_open:
		scene.levelup.call("_close")
	if _frames == 2:
		save.data["pictures"] = {}
	if _frames == 5:
		_paint = scene.get_node_or_null("PaintSystem")
		_check("masterpiece mode added the picture", _paint != null and grid.paint_on)
		_check("the picture has areas to paint (%d cells)" % grid.target_total, grid.target_total > 2000)
		_check("the first picture is the koi", String(_paint.get("picture_id")) == "koi")
		_check("nothing is painted yet", grid.correct_count == 0)
		_check("the run starts in a picture colour", gs.ink_id == "blue" and grid.current_tint == 1)
		# Area 6 is the koi's crimson body (tint 2). Paint it blue: a mistake.
		var body: Vector2 = grid.region_center[6]
		_check("the body wants crimson", grid.region_target[6] == 2)
		grid.paint_circle(body, 40.0, InkGrid.INK)
		_check("the wrong colour paints but does not count", grid.is_ink(body) and grid.correct_count == 0)
		grid.current_tint = 2
		grid.paint_circle(body, 40.0, InkGrid.INK)
		_check("painting over with the right colour counts", grid.correct_count > 50)
		var before := grid.correct_count
		grid.paint_circle(body, 20.0, InkGrid.SMUDGE)
		_check("smudge wipes correct paint", grid.correct_count < before)
		grid.current_tint = 1
		# A kill inside the gold tail (area 5) splats gold, though blue is carried.
		var tail: Vector2 = grid.region_center[5]
		var gold_before: int = grid.region_correct[5]
		var pond_before: int = grid.region_correct[1]
		root.get_node("Events").enemy_killed.emit("walker", tail, 60.0, 0, Vector2.RIGHT)
		_check("a kill splats the colour of the area it happened in", grid.region_correct[5] > gold_before and grid.tint[grid.cell_index(tail)] == 3)
		_check("the splat stays inside that area", grid.region_correct[1] == pond_before and grid.current_tint == 1)
		# True Brush: blue is carried, but a stroke over the gold eye lays gold.
		var eye: Vector2 = grid.region_center[9]
		grid.auto_tint = true
		grid.paint_circle(eye, 16.0, InkGrid.INK)
		grid.auto_tint = false
		_check("the True Brush lays the colour each area wants", grid.tint[grid.cell_index(eye)] == 3 and grid.region_correct[9] > 0)
		# Walk into the crimson well.
		scene.player.position = _paint.get("_wells")[1]["pos"]
	if _frames == 10:
		_check("dipping in the well changed the ink to crimson", gs.ink_id == "crimson" and grid.current_tint == 2)
		_check("the crimson play style applies", root.get_node("Upgrades").bonus("ink_burn") > 0.0)
		scene.player.position = _paint.get("_wells")[0]["pos"]
	if _frames == 15:
		_check("back to blue, crimson style removed", gs.ink_id == "blue" and is_zero_approx(root.get_node("Upgrades").bonus("ink_burn")))
		# The Deluge, fired inside the pond (area 1, blue), fills the whole area.
		scene.player.position = Vector2(1920, 1584)
		_check("the player stands in the pond", grid.region[grid.cell_index(scene.player.position)] == 1)
		scene.pulse.charge = 1.0
		scene.pulse.fire()
		_check("the Deluge filled the pond (%.0f%%)" % (grid.region_accuracy(1) * 100.0), grid.region_accuracy(1) > 0.99)
		_check("other areas were left alone", grid.region_accuracy(2) < 0.01)
		_check("one area of nine is not yet a star (%d%%)" % int(grid.accuracy() * 100.0), _paint.call("stars") == 0 and grid.accuracy() > 0.1)
		for id in range(2, 8):
			grid.current_tint = grid.region_target[id]
			grid.flood_region(id, InkGrid.INK)
		grid.current_tint = 1
		_check("seven areas of nine earn a star (%d%%)" % int(grid.accuracy() * 100.0), _paint.call("stars") >= 1)
		# A boss dies: the lull stops spawns.
		root.get_node("Events").boss_defeated.emit("The Eraser")
	if _frames == 20:
		_check("the lull holds spawns", scene.director.hold_spawns > 10.0)
		_check("beating a boss pays a True Brush", gs.has_power("true_brush") and grid.auto_tint)
		root.get_node("Events").final_boss_defeated.emit()
		paused = false
	if _frames == 24:
		_check("stars were saved for the picture", int(save.data.get("pictures", {}).get("koi", 0)) >= 1)
		_check("the next picture is the mountain", String(scene.get_node("PaintSystem").get_script().call("next_picture")) == "mountain")
		save.data["pictures"] = {}
		save.save()
		print("paint_test: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
		return true
	return false
