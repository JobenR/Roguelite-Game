extends SceneTree
## Headless check of the run-end flow: the final boss, victory, continuing,
## death, Seals paid out once, and buying an ink and a boost.
##   godot --headless --fixed-fps 60 --script res://tools/meta_test.gd

var _frames: int = 0
var _failures: int = 0
var _seals_before: int = 0


func _initialize() -> void:
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
	if _frames == 2:
		# Start from a clean save. This must wait for the first frame: the save
		# file is loaded after _initialize and would overwrite an earlier reset.
		save.data = save._defaults()
	if _frames == 30:
		_seals_before = save.seals()
		gs.run_time = 899.0  # just before the final boss
	if _frames == 150:
		_check("final boss spawned", scene.enemies.boss != null and bool(scene.enemies.boss.data.get("final", false)))
		scene.enemies.damage(scene.enemies.boss, 999999.0)
	if _frames == 152:
		_check("victory screen is up and the game is paused", scene.run_summary.visible and paused and gs.won)
		_check("nothing paid out yet", save.seals() == _seals_before)
		scene.run_summary.call("_on_primary")  # Keep going
	if _frames == 155:
		_check("run continues after the win", not paused and not scene.run_summary.visible and gs.is_playing())
		scene.player.take_damage(999999.0)
	if _frames == 158:
		var earned: int = save.seals() - _seals_before
		_check("death pays Seals including the win bonus (got %d)" % earned, earned >= 50 + 60)
		_check("paying twice does nothing", gs.finish_run() == 0)
		_check("a win and a run were recorded", int(save.data["wins"]) == 1 and int(save.data["runs"]) == 1)
		save.data["seals"] = 100
		_check("cannot buy an ink that costs more", not save.unlock_ink("gold"))
		_check("can buy an affordable ink", save.unlock_ink("crimson") and save.seals() == 40)
		_check("can buy a boost", save.buy_boost("vitality") and save.boost_level("vitality") == 1 and save.seals() == 20)
		gs.set_ink("crimson")
		reload_current_scene()
	if _frames == 170:
		# Crimson: -20% health, then the boost adds 6 to base before the cut.
		_check("ink and boost apply to the new run (max health %.0f)" % scene.player.max_hp, is_equal_approx(scene.player.max_hp, 106.0 * 0.8))
		save.data = save._defaults()
		save.save()
		print("meta_test: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
		quit(_failures)
		return true
	return false
