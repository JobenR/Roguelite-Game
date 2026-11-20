extends SceneTree
## Headless checks for Reclaim mode, on page 4 (The Long Wall): walls, the
## ink sources and their creep, spawning from sources, cover against shots,
## routing round walls, killing sources, and winning or losing the race.
##   godot --headless --fixed-fps 60 --script res://tools/reclaim_test.gd

var _frames: int = 0
var _failures: int = 0
var _rc: Node
var _backup: Dictionary = {}
var _stars: int = -1
var _lost: bool = false
var _walker: Node
var _shot: Node
var _smudge_before: int = 0
var _shots_last_x: float = 0.0


func _initialize() -> void:
	root.get_node("GameState").mode_id = "reclaim"
	root.get_node("GameState").reclaim_level = 3
	_backup = (root.get_node("SaveData").data as Dictionary).duplicate(true)
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
	var events := root.get_node("Events")
	var grid: InkGrid = scene.ink.grid
	if gs.state == gs.State.PLAYING:
		scene.player.hp = scene.player.max_hp
	if scene.levelup.is_open:
		scene.levelup.call("_close")
	if _frames == 3:
		events.level_won.connect(func(stars: int) -> void: _stars = stars)
		events.level_lost.connect(func() -> void: _lost = true)
	if _frames == 8:
		_rc = scene.get_node_or_null("ReclaimSystem")
		_check("reclaim mode added the page", _rc != null)
		_check("page 4 is the Long Wall at 2560x1440", String(_rc.level["name"]) == "The Long Wall" and grid.cols * 8 == 2560)
		_check("walls were built (%d wall cells)" % grid.dead_count, grid.dead_count > 1500)
		_check("walls stop shots, enemy ink slows the player", grid.walls_stop_shots and grid.enemy_ink_slow > 0.0)
		_check("three ink sources", _rc.sources.size() == 3)
		# Powers speak Reclaim: reworded cards, Purge for Deluge, mode-only cards.
		var upgrades := root.get_node("Upgrades")
		var data_db := root.get_node("DataDB")
		_check("cards are reworded (Reclaim -> %s)" % upgrades.defs()["reclaim"]["name"], upgrades.defs()["reclaim"]["name"] == "Deep Clean")
		_check("the Deluge is the Purge", data_db.term("Deluge") == "Purge")
		var seen := {}
		for i in 300:
			for id: String in upgrades.roll_choices(3):
				seen[id] = true
		_check("Masterpiece cards are not offered", not seen.has("true_brush") and not seen.has("flood_fill"))
		_check("Reclaim cards are offered", seen.has("spawner_bane") or seen.has("solvent_coat") or seen.has("gate_seal"))
		var spawners := 0
		for enemy in scene.enemies.active:
			if enemy.type_id == "spawner":
				spawners += 1
		_check("each source is a spawner enemy", spawners == 3)
		_check("the player starts on clean ground", grid.is_ink(scene.player.position))
		_check("the enemy starts with a share of the page (%.1f%%)" % (grid.enemy_share() * 100.0), grid.enemy_share() > 0.02 and grid.enemy_share() < 0.15)
		# Every spawn point comes from a source and never from inside a wall.
		var good := true
		for i in 30:
			var at: Vector2 = scene.director.call("_spawn_point")
			var near := false
			for p: Vector2 in _rc.live_points():
				near = near or at.distance_to(p) < 130.0
			good = good and near and not grid.is_dead(at)
		_check("enemies spawn out of the sources", good)
		# Creep: skip ahead to a front 600px wide. It must stop at the wall.
		_smudge_before = grid.smudge_count
		gs.run_time = 600.0 / float(_rc.level["creep_speed"])
	if _frames == 10:
		_check("the creep spread ink (%d -> %d cells)" % [_smudge_before, grid.smudge_count], grid.smudge_count > _smudge_before + 4000)
		_check("it reached open ground near a source", grid.state_at(Vector2(1300, 720)) == InkGrid.SMUDGE)
		_check("it did not pass through the wall", grid.state_at(Vector2(1000, 700)) != InkGrid.SMUDGE)
		# Cover: a shot fired at the wall dies on it.
		_shot = scene.bullets.fire(Vector2(1040, 500), Vector2.RIGHT, scene.player.weapon)
		_shots_last_x = 0.0
	if _frames > 10 and _frames < 40 and _shot != null:
		_shots_last_x = maxf(_shots_last_x, (_shot as Node2D).position.x)
	if _frames == 40:
		_check("the shot stopped at the wall (reached x=%.0f)" % _shots_last_x, not scene.bullets.active.has(_shot) and _shots_last_x < 1170.0)
		# Routing: a walker west of the wall finds the gap to reach the player.
		scene.player.position = Vector2(1300, 900)
		_walker = scene.enemies.spawn("walker", Vector2(1000, 900), 1.0)
	if _frames == 450:
		# The large-area erasing cards: shockwave, pinball sponges, rolling eraser.
		var upgrades := root.get_node("Upgrades")
		for id in ["scrub_wave", "scrub_wave", "pinball", "pinball", "rolling_eraser"]:
			upgrades.apply(id)
		scene.player.position = Vector2(300, 1300)
		for i in grid.total_cells():
			if grid.cells[i] == InkGrid.INK:
				grid.set_cell(i, InkGrid.SMUDGE)
		_rc.set("_wave_left", 0.01)
		_rc.set("_ball_left", 0.01)
		_smudge_before = grid.ink_count
	if _frames == 452:
		var rings: Array = _rc.get("_rings")
		var balls: Array = _rc.get("_balls")
		_check("the shockwave fired and the sponges launched (%d ring, %d balls)" % [rings.size(), balls.size()], rings.size() == 1 and balls.size() == 2)
	if _frames == 500:
		_check("they cleaned a large area (%d -> %d clean cells)" % [_smudge_before, grid.ink_count], grid.ink_count > _smudge_before + 8000)
		_check("the rolling eraser circle follows the player", float(_rc.get("_aura_radius")) > 45.0 and grid.is_ink(scene.player.position))
		var inside := true
		for ball: Dictionary in _rc.get("_balls"):
			inside = inside and not grid.is_dead(ball["pos"])
		_check("no sponge is inside a wall", inside)
	if _frames == 520:
		_check("the walker found the gap in the wall (x=%.0f, y=%.0f)" % [(_walker as Node2D).position.x, (_walker as Node2D).position.y], _walker.active and ((_walker as Node2D).position.x > 1160.0 or (_walker as Node2D).position.y > 1000.0))
		# Destroy one source: its ink is washed away and it stops sending enemies.
		var victim: Dictionary = _rc.sources[2]
		var before: int = _rc.live_points().size()
		scene.enemies.damage(victim["enemy"], 1.0e9)
	if _frames == 522:
		_check("destroying a source counts it (%d left)" % _rc.sources_left(), _rc.sources_left() == 2 and _rc.live_points().size() == 2)
		_check("its ground was washed clean", grid.is_ink(Vector2(1560, 720)))
		for source in _rc.sources:
			if source["alive"]:
				scene.enemies.damage(source["enemy"], 1.0e9)
	if _frames == 525:
		_check("with every source gone nothing more spawns", _rc.live_points().is_empty() and (scene.director.spawn_source.call() as Array).is_empty())
		# Win the race: own the whole open page.
		for i in grid.total_cells():
			if grid.cells[i] != InkGrid.DEAD:
				grid.set_cell(i, InkGrid.INK)
	if _frames == 545:
		_check("owning the page wins it with 3 stars (got %d)" % _stars, _stars == 3)
		_check("the stars were saved for page 4", int((root.get_node("SaveData").data.get("reclaim", {}) as Dictionary).get("4", 0)) == 3)
		_check("page 5 is now open", _rc.call("is_open", 4) and not _rc.call("is_open", 5))
		paused = false
		# Lose the race: the horde's ink everywhere.
		_rc.finished = false
		gs.state = gs.State.PLAYING
		for i in grid.total_cells():
			if grid.cells[i] != InkGrid.DEAD:
				grid.set_cell(i, InkGrid.SMUDGE)
	if _frames == 565:
		_check("the horde owning the page loses it", _lost and gs.state == gs.State.DEAD)
		root.get_node("SaveData").data = _backup
		root.get_node("SaveData").save()
		print("reclaim_test: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
		return true
	return false
