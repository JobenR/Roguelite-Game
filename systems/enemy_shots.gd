class_name EnemyShots
extends Node2D
## Projectiles fired by ranged enemies: slow globs of smudge. They hurt the
## player on contact and leave a smudge blot where they land. Few exist at
## once, so they are plain data drawn in one _draw call.

const MAX_SHOTS := 80

var _shots: Array[Dictionary] = []
var _player: Player
var _ink: InkSystem
var _arena: Rect2


func setup(player: Player, ink: InkSystem, arena: Rect2) -> void:
	_player = player
	_ink = ink
	_arena = arena


func fire(pos: Vector2, dir: Vector2, cfg: Dictionary) -> void:
	if _shots.size() >= MAX_SHOTS:
		return
	var speed := float(cfg.get("shot_speed", 180.0))
	_shots.append({
		"pos": pos, "vel": dir * speed, "life": float(cfg.get("keep_distance", 320.0)) * 1.7 / speed,
		"radius": float(cfg.get("shot_radius", 9.0)), "damage": float(cfg.get("shot_damage", 8.0)),
		"smudge": float(cfg.get("shot_smudge", 30.0)),
	})


func _process(delta: float) -> void:
	if _player == null or _shots.is_empty() or not GameState.is_playing():
		return
	var i := _shots.size() - 1
	while i >= 0:
		var shot := _shots[i]
		var vel: Vector2 = shot["vel"]
		var pos: Vector2 = shot["pos"]
		pos += vel * delta
		shot["pos"] = pos
		shot["life"] -= delta
		var radius: float = shot["radius"]
		var reach := radius + _player.radius
		var hit := pos.distance_squared_to(_player.position) <= reach * reach
		if hit:
			_player.take_damage(float(shot["damage"]))
		if hit or shot["life"] <= 0.0 or not _arena.has_point(pos):
			_ink.grid.paint_circle(pos, float(shot["smudge"]), InkGrid.SMUDGE)
			_shots.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	for shot in _shots:
		var pos: Vector2 = shot["pos"]
		var radius: float = shot["radius"]
		var back: Vector2 = -(shot["vel"] as Vector2).normalized()
		draw_circle(pos + back * radius * 1.4, radius * 0.7, Color(0.3, 0.28, 0.3, 0.5))
		draw_circle(pos, radius, Color("#57534e"))
		draw_arc(pos, radius, 0.0, TAU, 16, Color("#1c1917"), 2.5)
		draw_circle(pos - Vector2(radius, radius) * 0.25, radius * 0.3, Color("#a8a29e"))
