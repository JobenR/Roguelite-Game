class_name SpawnDirector
extends Node
## Decides when and where enemies spawn. Milestone 1: one enemy type with a
## spawn rate that ramps over time. All numbers come from data/waves.json.

var spawn_interval: float = 1.0

var _enemies: EnemyManager
var _player: Player
var _arena: Rect2
var _cfg: Dictionary = {}
var _timer: float = 0.0


func setup(enemies: EnemyManager, player: Player, arena: Rect2, mode_id: String) -> void:
	_enemies = enemies
	_player = player
	_arena = arena
	_cfg = DataDB.waves.get(mode_id, {})
	spawn_interval = float(_cfg.get("interval_start", 1.0))


func _process(delta: float) -> void:
	if _enemies == null or not GameState.is_playing():
		return
	if Input.is_action_just_pressed("debug_spawn"):
		spawn_burst(300)

	var ramp := clampf(GameState.run_time / float(_cfg.get("ramp_seconds", 180.0)), 0.0, 1.0)
	spawn_interval = lerpf(float(_cfg.get("interval_start", 1.0)), float(_cfg.get("interval_end", 0.2)), ramp)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = spawn_interval
	var batch := int(round(lerpf(float(_cfg.get("batch_start", 1.0)), float(_cfg.get("batch_end", 3.0)), ramp)))
	var room := int(_cfg.get("max_enemies", 400)) - _enemies.active.size()
	for i in mini(batch, room):
		_enemies.spawn(String(_cfg.get("enemy", "walker")), _spawn_point())


## Debug stress test: drops `count` enemies around the player at once.
func spawn_burst(count: int) -> void:
	for i in count:
		_enemies.spawn(String(_cfg.get("enemy", "walker")), _spawn_point())


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
