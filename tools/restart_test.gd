extends SceneTree
## Headless check that death, restart, pause and a second run work cleanly.
##   godot --headless --fixed-fps 60 --script res://tools/restart_test.gd

var _frames: int = 0
var _restarts: int = 0


func _initialize() -> void:
	change_scene_to_file("res://modes/survival.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var gs := root.get_node("GameState")
	var scene := current_scene
	if scene == null:
		return false
	if _frames % 400 == 50:
		Input.action_press("fire")
		scene.director.spawn_burst(200)
		root.get_node("Upgrades").apply("caustic_ink")
		root.get_node("Upgrades").apply("laser")
		root.get_node("Upgrades").apply("orbit")
		gs.add_xp(3)
	if _frames % 400 == 120 and scene.levelup.is_open:
		scene.levelup._choose(root.get_node("Upgrades").roll_choices(1)[0])
	if _frames % 400 == 200:
		scene.player.take_damage(99999.0)
	if _frames % 400 == 260:
		print("run %d ended: state=%d kills=%d level=%d paused=%s" % [_restarts + 1, gs.state, gs.kills, gs.level, paused])
		_restarts += 1
		if _restarts >= 3:
			print("restart_test: DONE")
			return true
		reload_current_scene()
	return false
