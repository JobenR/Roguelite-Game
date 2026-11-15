extends SceneTree
## Balance probe: plays one run with a simple circling bot that picks cards at
## random and cannot die, and prints a line per minute. How full the page is
## compared with the enemy cap shows whether the build is outrunning the
## horde (near 0%) or being buried (100%).
##   godot --headless --fixed-fps 60 --script res://tools/balance_sim.gd -- <seed> <minutes> [mode]

var _frames: int = 0
var _minutes: int = 10
var _hits: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	seed(int(args[0]) if args.size() > 0 else 1)
	_minutes = int(args[1]) if args.size() > 1 else 10
	root.get_node("GameState").mode_id = args[2] if args.size() > 2 else "survival"
	change_scene_to_file("res://modes/survival.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var scene := current_scene
	if scene == null:
		return false
	var gs := root.get_node("GameState")
	var upgrades := root.get_node("Upgrades")
	Input.action_press("fire")
	var dir := Vector2.from_angle(_frames * 0.011)
	Input.action_press("move_right" if dir.x > 0.0 else "move_left", absf(dir.x))
	Input.action_release("move_left" if dir.x > 0.0 else "move_right")
	Input.action_press("move_down" if dir.y > 0.0 else "move_up", absf(dir.y))
	Input.action_release("move_up" if dir.y > 0.0 else "move_down")
	if _frames % 240 == 0:
		Input.action_press("secondary")
		Input.action_press("pulse")
	elif _frames % 240 == 2:
		Input.action_release("secondary")
		Input.action_release("pulse")
	# A real player walks over their gems; the bot gets them pulled in instead.
	if _frames % 600 == 0:
		gs.grant_power("magnet", 1.0)
	if scene.player.hp < scene.player.max_hp:
		_hits += 1
		scene.player.hp = scene.player.max_hp
	if scene.run_summary.visible:
		scene.run_summary.call("_on_primary")
	if scene.levelup.is_open:
		var offer: Array[String] = upgrades.roll_choices(3)
		if offer.is_empty():
			scene.levelup.call("_close")
		else:
			scene.levelup.call("_choose", offer[randi() % offer.size()])
	if _frames % 3600 == 0:
		var cap: int = scene.director.enemy_cap()
		print("min %2d  alive %3d/%3d (%3d%%)  kills %5d  level %2d  cards %2d  ink %2d%%  hp x%.2f  hits %d" % [
			_frames / 3600, scene.enemies.active.size(), cap, scene.enemies.active.size() * 100 / maxi(cap, 1),
			gs.kills, gs.level, upgrades.levels.size(), int(scene.ink.ownership() * 100.0), scene.director.hp_multiplier(), _hits])
		_hits = 0
	return _frames >= _minutes * 3600
