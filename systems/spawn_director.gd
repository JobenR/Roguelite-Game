class_name SpawnDirector
extends Node
## Decides when, where, and what to spawn. Reads a timeline of waves from
## data/waves.json: each wave sets the spawn interval, batch size, and a
## weighted mix of enemy types. Enemy health grows with run time.

var spawn_interval: float = 1.0
var wave_index: int = -1

var _enemies: EnemyManager
var _player: Player
var _arena: Rect2
var _cfg: Dictionary = {}
var _waves: Array = []
var _timer: float = 0.0


func setup(enemies: EnemyManager, player: Player, arena: Rect2, mode_id: String) -> void:
	_enemies = enemies
	_player = player
	_arena = arena
	_cfg = DataDB.waves.get(mode_id, {})
	_waves = _cfg.get("waves", [])


## Seconds until the next wave starts, or -1 after the last one.
func time_to_next_wave() -> float:
	if wave_index + 1 >= _waves.size():
		return -1.0
	return float(_waves[wave_index + 1].get("start", 0.0)) - GameState.run_time


func hp_multiplier() -> float:
	return 1.0 + float(_cfg.get("hp_growth_per_minute", 0.0)) * GameState.run_time / 60.0


func _process(delta: float) -> void:
	if _enemies == null or _waves.is_empty() or not GameState.is_playing():
		return
	if Input.is_action_just_pressed("debug_spawn"):
		spawn_burst(300)

	while wave_index + 1 < _waves.size() and GameState.run_time >= float(_waves[wave_index + 1].get("start", 0.0)):
		wave_index += 1
		Events.wave_started.emit(wave_index)
	if wave_index < 0:
		return
	var wave: Dictionary = _waves[wave_index]
	spawn_interval = float(wave.get("interval", 1.0))

	_timer -= delta
	if _timer > 0.0:
		return
	_timer = spawn_interval
	var batch := int(wave.get("batch", 1))
	if wave_index == _waves.size() - 1:
		# Past the last wave the horde keeps growing.
		var overtime := (GameState.run_time - float(wave.get("start", 0.0))) / 60.0
		batch += int(overtime * float(_cfg.get("overtime_batch_per_minute", 0.0)))
	var room := int(_cfg.get("max_enemies", 400)) - _enemies.active.size()
	var hp_mult := hp_multiplier()
	for i in mini(batch, room):
		_enemies.spawn(_pick_type(wave), _spawn_point(), hp_mult)


## Debug stress test: drops `count` enemies around the player at once.
func spawn_burst(count: int) -> void:
	var wave: Dictionary = _waves[maxi(wave_index, 0)]
	for i in count:
		_enemies.spawn(_pick_type(wave), _spawn_point(), hp_multiplier())


## Weighted random enemy type from the wave's mix.
func _pick_type(wave: Dictionary) -> String:
	var mix: Dictionary = wave.get("enemies", {})
	var total := 0.0
	for id: String in mix:
		total += float(mix[id])
	var roll := randf() * total
	for id: String in mix:
		roll -= float(mix[id])
		if roll <= 0.0:
			return id
	return "walker"


## A point off-screen around the player, kept inside the arena.
func _spawn_point() -> Vector2:
	var d_min := float(_cfg.get("spawn_distance_min", 900.0))
	var d_max := float(_cfg.get("spawn_distance_max", 1100.0))
	var point := _player.position
	for attempt in 8:
		var dir := Vector2.from_angle(randf() * TAU)
		point = _player.position + dir * randf_range(d_min, d_max)
		point.x = clampf(point.x, _arena.position.x, _arena.end.x)
		point.y = clampf(point.y, _arena.position.y, _arena.end.y)
		# Clamping can pull the point back on screen when the player hugs a wall.
		if point.distance_to(_player.position) >= d_min * 0.95:
			break
	return point
