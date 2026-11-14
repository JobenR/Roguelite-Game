class_name Hazards
extends Node2D
## Lingering danger zones for enemies, created by upgrades:
##   burn  - a circle that damages enemies inside each quarter second.
##   hole  - a black hole that drags enemies in, then bursts.
##   mine  - sits on the ground and bursts when an enemy steps near.

const TICK := 0.25
const MAX_MINES_HARD := 24

var _enemies: EnemyManager
var _ink: InkSystem
var _effects: Effects
var _burns: Array[Dictionary] = []
var _holes: Array[Dictionary] = []
var _mines: Array[Dictionary] = []
var _tick_left: float = 0.0


func setup(enemies: EnemyManager, ink: InkSystem, effects: Effects) -> void:
	_enemies = enemies
	_ink = ink
	_effects = effects


func add_burn(pos: Vector2, radius: float, dps: float, seconds: float, color: Color) -> void:
	_burns.append({"pos": pos, "radius": radius, "dps": dps, "left": seconds, "color": color})


func add_hole(pos: Vector2, radius: float, seconds: float, burst_damage: float, pull_speed: float) -> void:
	_holes.append({"pos": pos, "radius": radius, "left": seconds, "total": seconds, "damage": burst_damage, "pull": pull_speed})


func add_mine(pos: Vector2, mine_damage: float, radius: float, trigger: float, limit: int) -> void:
	while _mines.size() >= mini(limit, MAX_MINES_HARD):
		_mines.remove_at(0)
	_mines.append({"pos": pos, "damage": mine_damage, "radius": radius, "trigger": trigger, "arm": 0.6})


func _process(delta: float) -> void:
	if _enemies == null or not GameState.is_playing():
		return
	if _burns.is_empty() and _holes.is_empty() and _mines.is_empty():
		return
	_tick_left -= delta
	var tick := _tick_left <= 0.0
	if tick:
		_tick_left = TICK

	var i := _burns.size() - 1
	while i >= 0:
		var burn := _burns[i]
		burn["left"] -= delta
		if tick:
			_enemies.damage_area(burn["pos"], float(burn["radius"]), float(burn["dps"]) * TICK)
		if burn["left"] <= 0.0:
			_burns.remove_at(i)
		i -= 1

	i = _holes.size() - 1
	while i >= 0:
		var hole := _holes[i]
		hole["left"] -= delta
		var pos: Vector2 = hole["pos"]
		var radius: float = hole["radius"]
		_enemies.pull(pos, radius * 1.6, float(hole["pull"]) * delta)
		if hole["left"] <= 0.0:
			_enemies.damage_area(pos, radius, float(hole["damage"]))
			_ink.splat(pos, radius * 0.6, Vector2.ZERO)
			_effects.ring(pos, radius, Color(0.3, 0.2, 0.6, 0.95), 0.4)
			Events.screen_shake.emit(6.0)
			_holes.remove_at(i)
		i -= 1

	i = _mines.size() - 1
	var found: Array = []
	while i >= 0:
		var mine := _mines[i]
		mine["arm"] -= delta
		if tick and mine["arm"] <= 0.0:
			var pos: Vector2 = mine["pos"]
			_enemies.grid.query(pos, float(mine["trigger"]), found)
			var tripped := false
			for enemy: Enemy in found:
				if enemy.active and pos.distance_to(enemy.position) <= float(mine["trigger"]) + enemy.radius:
					tripped = true
					break
			if tripped:
				_mines.remove_at(i)
				_ink.splat(pos, float(mine["radius"]) * 0.7, Vector2.ZERO)
				_enemies.damage_area(pos, float(mine["radius"]), float(mine["damage"]))
				_effects.ring(pos, float(mine["radius"]), Color(0.12, 0.23, 0.54, 0.9), 0.3)
		i -= 1
	queue_redraw()


func _draw() -> void:
	var spin := Time.get_ticks_msec() * 0.008
	for burn in _burns:
		var color: Color = burn["color"]
		var fade := clampf(float(burn["left"]), 0.0, 1.0)
		draw_circle(burn["pos"], float(burn["radius"]), Color(color, 0.16 * fade))
		draw_arc(burn["pos"], float(burn["radius"]) * (0.9 + 0.08 * sin(spin * 2.0)), 0.0, TAU, 40, Color(color, 0.6 * fade), 3.0)
	for hole in _holes:
		var pos: Vector2 = hole["pos"]
		var radius: float = hole["radius"]
		var t := 1.0 - float(hole["left"]) / float(hole["total"])
		draw_circle(pos, radius * 0.35 * (0.6 + t), Color(0.05, 0.02, 0.12, 0.95))
		for k in 3:
			draw_arc(pos, radius * (0.5 + 0.25 * k), -spin * (1.0 + k * 0.5), -spin * (1.0 + k * 0.5) + 3.6, 24, Color(0.35, 0.25, 0.7, 0.7), 4.0)
	for mine in _mines:
		var pos: Vector2 = mine["pos"]
		var armed: bool = mine["arm"] <= 0.0
		draw_circle(pos + Vector2(2, 3), 11.0, Color(0, 0, 0, 0.25))
		draw_circle(pos, 11.0, Color("#0b1b4d"))
		draw_arc(pos, 11.0, 0.0, TAU, 16, Color("#050a1f"), 2.5)
		draw_circle(pos, 4.0, Color("#ef4444") if armed and int(spin) % 2 == 0 else Color("#7f1d1d"))
