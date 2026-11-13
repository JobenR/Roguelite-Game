extends SceneTree
## Headless smoke test: runs the survival scene with fire held and a 300-enemy
## burst, then prints counts. Usage:
##   godot --headless --script res://tools/smoke_test.gd

var _frames: int = 0
var _scene: Node


func _initialize() -> void:
	_scene = load("res://modes/survival.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		Input.action_press("fire")
		Input.action_press("move_right", 1.0)
		_scene.director.spawn_burst(300)
	if _frames % 120 == 0:
		Input.action_press("secondary")
		Input.action_press("pulse")
	elif _frames % 120 == 1:
		Input.action_release("secondary")
		Input.action_release("pulse")
	if _frames % 200 == 0:
		var gs := root.get_node("GameState")
		print("frame %d enemies=%d bullets=%d kills=%d hp=%.0f state=%d ink=%.1f%% smudge=%.1f%% pulse=%.2f" % [
			_frames, _scene.enemies.active.size(), _scene.bullets.active.size(),
			gs.kills, _scene.player.hp, gs.state, _scene.ink.ownership() * 100.0, _scene.ink.smudge_share() * 100.0, _scene.pulse.charge])
	return _frames >= 2000
