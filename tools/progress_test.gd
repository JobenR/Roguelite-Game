extends SceneTree
## Headless checks for the character level, skill tree, store items, the
## Lasso and the Deluge ultimate.
##   godot --headless --fixed-fps 60 --script res://tools/progress_test.gd

var _frames: int = 0
var _failures: int = 0
var _hp_before: float = 0.0


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
	var upgrades := root.get_node("Upgrades")
	if scene.levelup.is_open:
		scene.levelup.call("_close")
	if _frames == 2:
		save.data = save._defaults()
		# Character XP and skills.
		var gained: int = save.add_char_xp(save.char_xp_needed(1) + 5)
		_check("character XP levels up and carries the remainder", gained == 1 and save.char_level() == 2 and int(save.data["char_xp"]) == 5)
		_check("a level gives one skill point", save.skill_points_free() == 1)
		_check("a skill can be bought, once", save.buy_skill("force") and not save.buy_skill("force") and save.skill_rank("force") == 1)
		# Store: spending and items.
		save.data["seals"] = 500
		save.data["gold"] = 100
		_check("spending fails when short and succeeds when not", not save.spend("gold", 101) and save.spend("gold", 40) and save.gold() == 60)
		save.add_item("page_wipe")
		save.add_item("revive")
		save.add_booster("double_xp", 2)
		gs.set_ink("blue")
		reload_current_scene()
	if _frames == 12:
		_check("the bought skill applies in the run (+8% damage)", is_equal_approx(upgrades.mult_of("damage"), 1.08))
		# Lasso: a crowd is roped together and cannot reach the player.
		for i in 30:
			scene.enemies.spawn("walker", scene.player.position + Vector2(260 + (i % 6) * 22, -60 + (i / 6) * 24))
		gs.add_item("lasso")
	if _frames == 14:
		_check("the item button holds the Lasso first", scene.item_system.call("held") == "lasso")
		scene.item_system.call("_use", "lasso")
	if _frames == 16:
		var bound := 0
		for enemy: Node in scene.enemies.active:
			if float(enemy.get("bound_left")) > 0.0:
				bound += 1
		_check("the Lasso bound the crowd (%d of 30)" % bound, bound >= 25)
	if _frames == 120:
		var closest := 99999.0
		for enemy: Node in scene.enemies.active:
			closest = minf(closest, (enemy.position as Vector2).distance_to(scene.player.position))
		_check("bound enemies stay away from the player (closest %.0f)" % closest, closest > 150.0)
		# Deluge: floods ink and damages.
		var ink_before: int = scene.ink.grid.ink_count
		var alive_before: int = scene.enemies.active.size()
		scene.pulse.charge = 1.0
		var flooded: int = scene.pulse.fire()
		_check("the Deluge floods the ground (%d cells)" % flooded, flooded > 3000 and scene.ink.grid.ink_count > ink_before)
		_check("the Deluge kills what it hits", scene.enemies.active.size() < alive_before)
		_check("the Deluge spends its charge", scene.pulse.charge < 1.0)
		# Page Wipe. Spawning is held so a stray new enemy cannot spoil the count.
		scene.director.hold_spawns = 5.0
		for i in 20:
			scene.enemies.spawn("walker", scene.player.position + Vector2.from_angle(i) * 300.0)
		scene.item_system.call("_use", "page_wipe")
	if _frames == 122:
		# The wipe reaches 1000px; an enemy that happened to spawn beyond that survives.
		var near := 0
		for enemy: Node in scene.enemies.active:
			if (enemy.position as Vector2).distance_to(scene.player.position) <= 1000.0:
				near += 1
		_check("Page Wipe cleared the screen (%d in reach, %d wipes held)" % [near, save.item_count("page_wipe")], near == 0 and save.item_count("page_wipe") == 0)
		# Second Life: a killing blow is survived once.
		scene.player.take_damage(999999.0)
		_hp_before = scene.player.hp
		_check("Second Life revived the player", gs.is_playing() and _hp_before > 0.0 and save.item_count("revive") == 0)
	if _frames == 300:
		scene.player.take_damage(999999.0)
	if _frames == 303:
		_check("the next killing blow ends the run", not gs.is_playing())
		var reward: Dictionary = gs.last_reward
		_check("the run paid character XP, doubled by the booster", int(reward.get("char_xp", 0)) == gs.char_xp_earned() * 2 and save.booster_runs("double_xp") == 1)
		save.data = save._defaults()
		save.save()
		print("progress_test: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
		quit(_failures)
		return true
	return false
