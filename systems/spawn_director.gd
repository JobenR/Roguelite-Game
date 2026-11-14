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
var _warned_index: int = -1
var _boss_cfg: Dictionary = {}
var _next_boss: float = INF
var _boss_count: int = 0
var _boss_warned: bool = false
var _final_cfg: Dictionary = {}
var _final_stage: int = 0  # 0 waiting, 1 warned, 2 spawned


func setup(enemies: EnemyManager, player: Player, arena: Rect2, mode_id: String) -> void:
	_enemies = enemies
	_player = player
	_arena = arena
	_cfg = DataDB.waves.get(mode_id, {})
	_waves = _cfg.get("waves", [])
	_boss_cfg = _cfg.get("miniboss", {})
	_final_cfg = _cfg.get("final_boss", {})
	if not _boss_cfg.is_empty():
		_next_boss = float(_boss_cfg.get("first", 150.0))


## Seconds until the next wave starts, or -1 after the last one.
func time_to_next_wave() -> float:
	if wave_index + 1 >= _waves.size():
		return -1.0
	return float(_waves[wave_index + 1].get("start", 0.0)) - GameState.run_time


func hp_multiplier() -> float:
	# Linear plus squared growth: gentle early, steep late, so a strong build
	# keeps meeting resistance.
	var minutes := GameState.run_time / 60.0
	return 1.0 + float(_cfg.get("hp_growth_per_minute", 0.0)) * minutes + float(_cfg.get("hp_growth_per_minute_squared", 0.0)) * minutes * minutes


## Most enemies allowed alive right now. The cap starts low and rises each
## minute, so the early horde stays a size the starting gun can manage.
func enemy_cap() -> int:
	var ramp := float(_cfg.get("max_enemies_start", 400.0)) + float(_cfg.get("max_enemies_per_minute", 0.0)) * GameState.run_time / 60.0
	return mini(int(_cfg.get("max_enemies", 400)), int(ramp))


## Seconds until the next mini-boss, or -1 when none is scheduled.
func time_to_boss() -> float:
	return _next_boss - GameState.run_time if _next_boss < INF else -1.0


func _process(delta: float) -> void:
	if _enemies == null or _waves.is_empty() or not GameState.is_playing():
		return
	if Input.is_action_just_pressed("debug_spawn"):
		spawn_burst(300)

	while wave_index + 1 < _waves.size() and GameState.run_time >= float(_waves[wave_index + 1].get("start", 0.0)):
		wave_index += 1
		Events.wave_started.emit(wave_index)
	# Warn a few seconds before the next wave.
	var next_in := time_to_next_wave()
	if next_in >= 0.0 and next_in <= float(_cfg.get("warning_seconds", 5.0)) and _warned_index != wave_index + 1:
		_warned_index = wave_index + 1
		Events.wave_warning.emit(wave_index + 2, next_in, String(_waves[wave_index + 1].get("label", "")))
	_update_boss()
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
	var room := enemy_cap() - _enemies.active.size()
	var hp_mult := hp_multiplier()
	for i in mini(batch, room):
		_enemies.spawn(_pick_type(wave), _spawn_point(), hp_mult)


## Mini-boss schedule: a warning a few seconds ahead, then the spawn.
func _update_boss() -> void:
	_update_final_boss()
	if _next_boss == INF:
		return
	var warn := float(_cfg.get("warning_seconds", 5.0))
	if not _boss_warned and GameState.run_time >= _next_boss - warn:
		_boss_warned = true
		Events.alert.emit(String(_boss_cfg.get("alert", "BOSS APPROACHES")), warn + 1.5)
	if GameState.run_time >= _next_boss:
		_boss_warned = false
		_next_boss += float(_boss_cfg.get("every", 180.0))
		# Wait for the current boss to die before sending another.
		if _enemies.boss == null:
			var boss_hp := hp_multiplier() * (1.0 + float(_boss_cfg.get("hp_mult_per_spawn", 0.5)) * _boss_count)
			_enemies.spawn(String(_boss_cfg.get("enemy", "eraser")), _spawn_point(), boss_hp)
			_boss_count += 1


## The final boss: one fixed time in the run. Beating it wins the run.
func _update_final_boss() -> void:
	if _final_cfg.is_empty() or _final_stage == 2:
		return
	var at := float(_final_cfg.get("time", 900.0))
	if _final_stage == 0 and GameState.run_time >= at - 6.0:
		_final_stage = 1
		Events.alert.emit(String(_final_cfg.get("alert", "THE FINAL BOSS RISES")), 7.5)
	if GameState.run_time >= at:
		_final_stage = 2
		_next_boss = INF  # no more mini-bosses once the final boss is out
		_enemies.spawn(String(_final_cfg.get("enemy", "eraser")), _spawn_point(), 1.0)


## Seconds until the final boss, or -1 once it has appeared.
func time_to_final() -> float:
	if _final_cfg.is_empty() or _final_stage == 2:
		return -1.0
	return float(_final_cfg.get("time", 900.0)) - GameState.run_time


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
