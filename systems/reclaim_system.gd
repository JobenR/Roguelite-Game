class_name ReclaimSystem
extends Node2D
## Reclaim mode: a campaign of pages (data/levels.json). Each page has walls
## and ink sources. Sources creep glowing ink across the page and send out the
## horde; the player scrubs it clean, destroys the sources and races the horde
## to own the field. First to the win share takes the page.
##
## Stars: 1 for clearing the page, 1 more under the par time, 1 more if every
## source was destroyed.

var level: Dictionary = {}
var level_index: int = 0
var sources: Array[Dictionary] = []   # pos, enemy, alive, creep
var destroyed: int = 0
var finished: bool = false

var _player: Player
var _ink: InkSystem
var _enemies: EnemyManager
var _effects: Effects
var _director: SpawnDirector
var _flow: FlowField
var _cfg: Dictionary = {}
var _spawned: bool = false
var _flow_left: float = 0.0
var _check_left: float = 0.0
var _boss_done: bool = false
# Large-area erasing powers (cards): Scrub Shockwave, Pinball Sponges, Rolling Eraser.
var _rings: Array[Dictionary] = []     # pos, r, max
var _balls: Array[Dictionary] = []     # pos, vel, life, hit_left, seed
var _wave_left: float = 5.0
var _ball_left: float = 9.0
var _aura_left: float = 0.0
var _aura_bonus: float = 0.0
var _aura_radius: float = 0.0


static func level_count() -> int:
	return (DataDB.levels.get("levels", []) as Array).size()


static func level_data(index: int) -> Dictionary:
	var all: Array = DataDB.levels.get("levels", [])
	return all[clampi(index, 0, all.size() - 1)] as Dictionary


static func stars_of(index: int) -> int:
	return int((SaveData.data.get("reclaim", {}) as Dictionary).get(str(index + 1), 0))


## A page is open once the one before it has at least one star.
static func is_open(index: int) -> bool:
	return index == 0 or stars_of(index - 1) > 0


## The first page without a star, or the last page once all are cleared.
static func next_open() -> int:
	for i in level_count():
		if stars_of(i) == 0:
			return i
	return level_count() - 1


func setup(player: Player, ink: InkSystem, enemies: EnemyManager, effects: Effects, director: SpawnDirector, cfg: Dictionary, index: int) -> void:
	_player = player
	_ink = ink
	_enemies = enemies
	_effects = effects
	_director = director
	_cfg = cfg
	level_index = index
	level = level_data(index)
	var grid := ink.grid
	grid.walls_stop_shots = true
	grid.enemy_ink_slow = float(cfg.get("enemy_ink_slow", 0.2))
	for shape: Dictionary in level.get("walls", []):
		for cell in Shapes.cells_in(shape, grid):
			grid.make_wall(cell)
	var start: Array = level.get("player", [400, 700])
	player.position = Vector2(float(start[0]), float(start[1]))
	grid.paint_circle(player.position, float(cfg.get("player_seed", 150.0)), InkGrid.INK)
	for source: Dictionary in level.get("spawners", []):
		var pos := Vector2(float(source["pos"][0]), float(source["pos"][1]))
		grid.paint_circle(pos, float(level.get("enemy_start_radius", 170.0)), InkGrid.SMUDGE)
		sources.append({"pos": pos, "hp": float(source.get("hp", 400.0)), "enemy": null, "alive": true, "creep": CreepMap.new(grid, pos)})
	_flow = FlowField.new(grid)
	_flow.rebuild(grid, player.position)
	enemies.flow = _flow
	director.ink = ink
	director.spawn_source = live_points
	director.intensity = float(level.get("intensity", 1.0))
	director.time_offset = float(level.get("time_offset", 0.0))
	Events.enemy_killed.connect(_on_enemy_killed)


func _num(id: String, key: String, fallback: float) -> float:
	return DataDB.arsenal_num(id, key, fallback)


## Positions of the sources still pumping out ink and enemies.
func live_points() -> Array:
	var points: Array = []
	for source in sources:
		if bool(source["alive"]):
			points.append(source["pos"])
	return points


func sources_left() -> int:
	return sources.size() - destroyed


func stars_now() -> int:
	var count := 1
	if GameState.run_time <= float(level.get("par_seconds", 300.0)):
		count += 1
	if destroyed >= sources.size():
		count += 1
	return count


func _spawn_sources() -> void:
	_spawned = true
	var base_hp := float(DataDB.enemies.get("spawner", {}).get("hp", 400.0))
	for source in sources:
		source["enemy"] = _enemies.spawn("spawner", source["pos"], float(source["hp"]) / base_hp)


func _process(delta: float) -> void:
	if finished or not GameState.is_playing():
		return
	if not _spawned:
		_spawn_sources()
	var grid := _ink.grid
	# The creep: each live source's front widens with time.
	var radius := float(level.get("creep_speed", 7.0)) * GameState.run_time
	var bite := clampf(float(_cfg.get("enemy_bite", 0.55)) * (1.0 - Upgrades.bonus("creep_resist")), 0.0, 1.0)
	for source in sources:
		if bool(source["alive"]):
			(source["creep"] as CreepMap).advance(grid, radius, bite)
	_flow_left -= delta
	if _flow_left <= 0.0:
		_flow_left = 0.5
		_flow.rebuild(grid, _player.position)
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = 0.25
		_check_race()
	_run_powers(delta)
	queue_redraw()


## The cards that scrub large areas.
func _run_powers(delta: float) -> void:
	var grid := _ink.grid
	var damage_scale := Upgrades.mult_of("damage") * (1.0 + GameState.damage_bonus)
	# Scrub Shockwave: a ring that sweeps outward, cleaning everything it crosses.
	var wave := Upgrades.bonus("scrub_wave")
	if wave > 0.0:
		_wave_left -= delta
		if _wave_left <= 0.0:
			_wave_left = maxf(_num("scrub_wave", "min_interval", 3.5), _num("scrub_wave", "interval", 9.0) - wave * _num("scrub_wave", "interval_per_level", 1.1))
			var reach := _num("scrub_wave", "radius", 260.0) + wave * _num("scrub_wave", "radius_per_level", 130.0)
			_rings.append({"pos": _player.position, "r": 0.0, "max": reach})
			var power := (_num("scrub_wave", "damage", 16.0) + wave * _num("scrub_wave", "damage_per_level", 10.0)) * damage_scale
			_enemies.damage_area(_player.position, reach, power)
			_enemies.knockback(_player.position, reach, _num("scrub_wave", "knock", 140.0))
			_effects.ring(_player.position, reach, Color(GameState.ink_light, 0.9), 0.6)
			Events.screen_shake.emit(8.0)
			Audio.play("pulse")
	var i := _rings.size() - 1
	while i >= 0:
		var ring := _rings[i]
		ring["r"] = float(ring["r"]) + _num("scrub_wave", "speed", 900.0) * delta
		var r: float = ring["r"]
		var steps := maxi(8, int(TAU * r / 14.0))
		for k in steps:
			grid.paint_circle((ring["pos"] as Vector2) + Vector2.from_angle(TAU * k / steps) * r, 20.0, InkGrid.INK)
		if r >= float(ring["max"]):
			_rings.remove_at(i)
		i -= 1
	# Pinball Sponges: balls that ricochet round the page for a while.
	var pins := Upgrades.bonus("pinball")
	if pins > 0.0:
		_ball_left -= delta
		if _ball_left <= 0.0:
			_ball_left = maxf(_num("pinball", "min_interval", 7.0), _num("pinball", "interval", 16.0) - pins * _num("pinball", "interval_per_level", 1.5))
			for n in mini(int(pins), int(_num("pinball", "max_balls", 6.0))):
				var heading := Vector2.from_angle(TAU * (float(n) / maxf(1.0, pins)) + randf() * 0.6)
				_balls.append({"pos": _player.position, "vel": heading * _num("pinball", "speed", 560.0),
						"life": _num("pinball", "seconds", 6.0) + pins * _num("pinball", "seconds_per_level", 1.0), "hit_left": 0.0, "seed": randf() * 20.0})
	var bounds := Rect2(Vector2.ZERO, Vector2(grid.cols, grid.rows) * grid.cell_size)
	var b := _balls.size() - 1
	while b >= 0:
		var ball := _balls[b]
		ball["life"] = float(ball["life"]) - delta
		var pos: Vector2 = ball["pos"]
		var vel: Vector2 = ball["vel"]
		var radius := _num("pinball", "radius", 24.0)
		var next := pos + vel * delta
		var lead := vel.normalized() * radius
		if grid.is_dead(next + lead) or not bounds.grow(-radius).has_point(next):
			# Bounce: reflect the axis that is blocked (both at a corner).
			var block_x := grid.is_dead(Vector2(pos.x + vel.x * delta, pos.y) + Vector2(signf(vel.x) * radius, 0.0)) or not bounds.grow(-radius).has_point(Vector2(next.x, pos.y))
			var block_y := grid.is_dead(Vector2(pos.x, pos.y + vel.y * delta) + Vector2(0.0, signf(vel.y) * radius)) or not bounds.grow(-radius).has_point(Vector2(pos.x, next.y))
			if block_x:
				vel.x = -vel.x
			if block_y:
				vel.y = -vel.y
			if not block_x and not block_y:
				vel = -vel
			next = pos + vel * delta
			if grid.is_dead(next):
				next = pos
			Audio.play("hit")
		ball["vel"] = vel
		grid.paint_line(pos, next, _num("pinball", "paint", 34.0) + pins * _num("pinball", "paint_per_level", 6.0), InkGrid.INK)
		ball["hit_left"] = float(ball["hit_left"]) - delta
		if float(ball["hit_left"]) <= 0.0:
			ball["hit_left"] = 0.1
			_enemies.damage_area(next, radius + 8.0, (_num("pinball", "damage", 24.0) + pins * _num("pinball", "damage_per_level", 10.0)) * damage_scale)
		ball["pos"] = next
		if float(ball["life"]) <= 0.0:
			_effects.burst(next, Vector2.ZERO, GameState.ink_color, 10)
			_effects.ring(next, 70.0, Color(GameState.ink_light, 0.8), 0.3)
			_balls.remove_at(b)
		b -= 1
	# Rolling Eraser: a scrub circle that follows you and grows with kills.
	var rolling := Upgrades.bonus("rolling_eraser")
	if rolling > 0.0:
		_aura_radius = _num("rolling_eraser", "radius", 28.0) + rolling * _num("rolling_eraser", "radius_per_level", 22.0) + _aura_bonus
		_aura_left -= delta
		if _aura_left <= 0.0:
			_aura_left = 0.1
			grid.paint_circle(_player.position, _aura_radius, InkGrid.INK)
	else:
		_aura_radius = 0.0


func _check_race() -> void:
	var mine := _ink.ownership()
	var theirs := _ink.enemy_share()
	var goal := float(level.get("win_share", 0.9))
	if mine >= goal:
		_win()
		return
	if theirs >= goal:
		_lose()
		return
	var boss: Dictionary = level.get("boss", {})
	if not boss.is_empty() and not _boss_done and mine >= float(boss.get("at_share", 0.5)):
		_boss_done = true
		var from: Array = live_points()
		var at: Vector2 = from[randi() % from.size()] if not from.is_empty() else _player.position + Vector2(700.0, 0.0)
		_enemies.spawn(String(boss.get("enemy", "eraser")), at, _director.hp_multiplier())
		Events.alert.emit(String(boss.get("alert", "THE ERASER ARRIVES")), 4.0)


func _win() -> void:
	finished = true
	var stars := stars_now()
	var saved: Dictionary = SaveData.data.get("reclaim", {})
	if stars > int(saved.get(str(level_index + 1), 0)):
		saved[str(level_index + 1)] = stars
		SaveData.data["reclaim"] = saved
		SaveData.save()
	GameState.won = true
	Events.level_won.emit(stars)


func _lose() -> void:
	finished = true
	GameState.state = GameState.State.DEAD
	Events.level_lost.emit()


func _on_enemy_killed(type_id: String, pos: Vector2, _splat: float, _xp: int, _dir: Vector2) -> void:
	var rolling := Upgrades.bonus("rolling_eraser")
	if rolling > 0.0:
		var cap := _num("rolling_eraser", "bonus_cap", 60.0) + rolling * _num("rolling_eraser", "bonus_cap_per_level", 20.0)
		_aura_bonus = minf(cap, _aura_bonus + _num("rolling_eraser", "per_kill", 1.2))
	if type_id != "spawner":
		return
	var best: Dictionary = {}
	var best_d := 80.0 * 80.0
	for source in sources:
		var d := (source["pos"] as Vector2).distance_squared_to(pos)
		if bool(source["alive"]) and d < best_d:
			best = source
			best_d = d
	if best.is_empty():
		return
	best["alive"] = false
	best["enemy"] = null
	destroyed += 1
	# The source's ink is washed away around it, and with Seal the Gate stays so.
	var wash := float(_cfg.get("clear_radius", 240.0))
	_ink.grid.flood_disc(pos, wash, InkGrid.INK)
	var seal := Upgrades.bonus("gate_seal")
	if seal > 0.0:
		_ink.grid.flood_disc(pos, wash * (0.6 + 0.25 * seal), InkGrid.LOCKED)
	_effects.big_moment(pos, wash * 1.3, GameState.ink_light, 1.0)
	Events.screen_shake.emit(12.0)
	if sources_left() > 0:
		Events.alert.emit("SOURCE DESTROYED\n%d LEFT" % sources_left(), 2.5)
	else:
		Events.alert.emit("EVERY SOURCE DESTROYED\nCLEAN UP THE PAGE", 3.5)


func _draw() -> void:
	# Card powers: sponges, the rolling eraser's edge and any shockwave rings.
	if _aura_radius > 0.0:
		draw_arc(_player.position, _aura_radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.55), 5.0)
		draw_arc(_player.position, _aura_radius + 4.0, 0.0, TAU, 48, Color(GameState.ink_color, 0.7), 3.0)
	for ring in _rings:
		draw_arc(ring["pos"], float(ring["r"]), 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.8), 8.0)
		draw_arc(ring["pos"], float(ring["r"]) + 8.0, 0.0, TAU, 64, Color(GameState.ink_color, 0.8), 4.0)
	for ball in _balls:
		Brush.blot(self, ball["pos"], _num("pinball", "radius", 24.0), GameState.ink_color, float(ball["seed"]))
		draw_circle(ball["pos"] - Vector2(7.0, 7.0), 7.0, Color(1.0, 1.0, 1.0, 0.85))
	# A health ring round each live source, so you can see which is weakest.
	var hot := Color(String(_cfg.get("enemy_color", "#ff3d8b")))
	for source in sources:
		var enemy: Enemy = source["enemy"]
		if not bool(source["alive"]) or enemy == null or not enemy.active:
			continue
		var pos: Vector2 = source["pos"]
		var share := clampf(enemy.hp / enemy.max_hp, 0.0, 1.0)
		draw_arc(pos, 74.0, 0.0, TAU, 40, Color(0.08, 0.07, 0.06, 0.35), 8.0)
		draw_arc(pos, 74.0, -PI * 0.5, -PI * 0.5 + TAU * share, 40, hot, 8.0)
