extends SceneTree
## Headless checks for Burning Page mode: what a burnt strip does to ink,
## the payout, blocking, and routing round burnt paper.
##   godot --headless --fixed-fps 60 --script res://tools/burn_test.gd

var _frames: int = 0
var _failures: int = 0
var _xp_before: int = 0
# Untyped on purpose: naming a class that uses autoloads here would compile it
# before the autoloads exist, when this file is run with --script.
var _burn: Node


func _initialize() -> void:
	root.get_node("GameState").mode_id = "burning_page"
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
	var grid: InkGrid = scene.ink.grid
	scene.player.hp = scene.player.max_hp
	if scene.levelup.is_open:
		scene.levelup.call("_close")
	if _frames == 5:
		_burn = scene.get_node("BurnSystem")
		_check("burning page mode added the fire", _burn != null)
		# Own the left half of the first strip, leave the rest bare.
		grid.paint_line(Vector2(48, 0), Vector2(48, 2160), 60.0, InkGrid.INK)
		_xp_before = gs.kills
		_burn._timer = 0.05
	if _frames == 60:
		# Dropped into the strip while it burns, so it is caught when it finishes.
		scene.enemies.spawn("walker", Vector2(3836, 1000))
	if _frames == 200:
		_check("the strip finished burning", _burn.strips_burned == 1)
		_check("my ink in the strip survived as permanent ink", grid.cells[grid.cell_index(Vector2(48, 1000))] == InkGrid.LOCKED)
		_check("bare paper in the strip is burnt", grid.cells[grid.cell_index(Vector2(3800, 1000))] == InkGrid.DEAD)
		_check("the middle of the page is untouched", grid.cells[grid.cell_index(Vector2(1900, 1000))] == InkGrid.NEUTRAL)
		_check("burnt paper cannot be painted", (func() -> bool:
			grid.paint_circle(Vector2(3800, 1000), 20.0, InkGrid.INK)
			return grid.cells[grid.cell_index(Vector2(3800, 1000))] == InkGrid.DEAD).call())
		_check("the enemy caught on burnt paper died", gs.kills > _xp_before)
		_check("inner rectangle shrank by one strip", is_equal_approx(_burn.inner_rect().position.x, 96.0))
		# The player cannot walk onto burnt paper.
		scene.player.position = Vector2(1900, 110)
		Input.action_press("move_up", 1.0)
	if _frames == 260:
		Input.action_release("move_up")
		_check("player is stopped at the burnt edge (y=%.0f)" % scene.player.position.y, scene.player.position.y >= 96.0 and not grid.is_dead(scene.player.position))
		# Routing: wall off a pocket with burnt cells and check the field leads round it.
		scene.player.position = Vector2(1900, 1000)
		# A burnt wall several cells thick (real strips are 12 cells wide).
		for y in range(40, 220):
			for x in range(298, 308):
				grid.burn_cell(y * grid.cols + x)
		scene.enemies.flow.rebuild(grid, scene.player.position)
		var dir: Vector2 = scene.enemies.flow.direction(Vector2(2500, 1000))
		_check("flow field routes round a burnt wall (dir %s)" % dir, dir != Vector2.ZERO and absf(dir.y) > 0.1)
		_check("ownership ignores burnt paper", scene.ink.ownership() > float(grid.ink_count) / grid.total_cells())
		print("burn_test: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
		quit(_failures)
		return true
	return false
