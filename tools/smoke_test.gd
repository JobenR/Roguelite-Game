extends SceneTree
## Headless smoke test: plays the survival scene with fire held, uses the bomb
## and pulse, keeps the player alive, and auto-picks the first card on every level-up. Usage:
##   godot --headless --fixed-fps 60 --script res://tools/smoke_test.gd

var _frames: int = 0
var _scene: Node


func _initialize() -> void:
	_scene = load("res://modes/survival.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene


func _process(_delta: float) -> bool:
	_frames += 1
	var gs := root.get_node("GameState")
	var upgrades := root.get_node("Upgrades")
	if _frames == 5:
		Input.action_press("fire")
		_scene.director.spawn_burst(150)
	# Walk a slow circle so gems get collected.
	var dir := Vector2.from_angle(_frames * 0.01)
	Input.action_press("move_right" if dir.x > 0.0 else "move_left", absf(dir.x))
	Input.action_release("move_left" if dir.x > 0.0 else "move_right")
	Input.action_press("move_down" if dir.y > 0.0 else "move_up", absf(dir.y))
	Input.action_release("move_up" if dir.y > 0.0 else "move_down")
	if _frames % 120 == 0:
		Input.action_press("secondary")
		Input.action_press("pulse")
	elif _frames % 120 == 1:
		Input.action_release("secondary")
		Input.action_release("pulse")
	if _frames == 600:
		for id in ["scatter", "laser", "orbit", "multishot"]:
			upgrades.apply(id)
	# Keep the test player alive so a long run exercises every upgrade.
	_scene.player.hp = _scene.player.max_hp
	if _scene.levelup.is_open:
		_scene.levelup._choose(upgrades.roll_choices(1)[0])
	if _frames % 1500 == 0:
		print("frame %d enemies=%d gems=%d kills=%d hp=%.0f/%.0f level=%d wave=%d ink=%.1f%% upgrades=%s synergies=%s" % [
			_frames, _scene.enemies.active.size(), _scene.gems.active.size(), gs.kills,
			_scene.player.hp, _scene.player.max_hp, gs.level, _scene.director.wave_index + 1,
			_scene.ink.ownership() * 100.0, upgrades.levels, upgrades.synergies.keys()])
	return _frames >= 18000
