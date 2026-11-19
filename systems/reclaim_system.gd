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
	queue_redraw()


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
