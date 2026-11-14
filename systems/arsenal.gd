class_name Arsenal
extends Node2D
## Extra weapons and passive ink effects granted by upgrades. Each one runs on
## its own timer and reads its numbers from data/arsenal.json. An upgrade's
## level is the value of the stat named after it (Upgrades.bonus("mines")).

var _player: Player
var _enemies: EnemyManager
var _bullets: BulletManager
var _ink: InkSystem
var _effects: Effects
var _hazards: Hazards
var _timers: Dictionary = {}
var _pistol: Dictionary = {}
var _quill: Dictionary = {}
var _spray: Dictionary = {}
var _plane: Dictionary = {}
var _sprinkler_angle: float = 0.0
var _boomerangs: Array[Dictionary] = []
var _turrets: Array[Dictionary] = []
var _waves: Array[Dictionary] = []
var _saws: Array[Dictionary] = []
var _trail: Array[Dictionary] = []
var _saw_tick: float = 0.0
var _trail_tick: float = 0.0
var _watermark_left: float = 1.0
var _secondary: SecondarySystem
var _wall_points: Array[Dictionary] = []


func setup(player: Player, enemies: EnemyManager, bullets: BulletManager, ink: InkSystem, effects: Effects, hazards: Hazards, secondary: SecondarySystem) -> void:
	_secondary = secondary
	_player = player
	_enemies = enemies
	_bullets = bullets
	_ink = ink
	_effects = effects
	_hazards = hazards
	_pistol = player.weapon
	# Variants of the main gun used by the extra weapons.
	_quill = _pistol.duplicate(true)
	_quill.merge({"bullet_speed": 520.0, "bullet_life": 1.6, "homing": 5.0, "homing_range": 320.0, "no_split": true,
		"visual": {"sides": 3, "color": "#fde68a", "outline": "#713f12", "glow": "#fbbf24", "streak": 18, "shadow": false}}, true)
	_spray = _pistol.duplicate(true)
	_spray.merge({"bullet_life": 0.35, "bullet_radius": 4.0, "no_split": true}, true)
	_plane = _pistol.duplicate(true)
	_plane.merge({"bullet_speed": 250.0, "bullet_life": 4.5, "bullet_radius": 9.0, "homing": 5.5, "homing_range": 420.0, "no_split": true,
		"visual": {"sides": 3, "color": "#ffffff", "outline": "#334155", "glow": "#cbd5e1", "streak": 14, "shadow": false}}, true)
	Events.player_hurt.connect(_on_player_hurt)
	Events.power_granted.connect(_on_power_granted)


func _num(id: String, key: String, fallback: float) -> float:
	return DataDB.arsenal_num(id, key, fallback)


func _level(stat: String) -> int:
	return int(Upgrades.bonus(stat))


## True when weapon `id` at `level` is ready to fire; restarts its timer.
func _due(id: String, level: int, delta: float) -> bool:
	if level <= 0:
		return false
	var left := float(_timers.get(id, 1.0)) - delta
	if left > 0.0:
		_timers[id] = left
		return false
	var haste := (1.0 + _num(id, "cooldown_per_level", 0.15) * (level - 1)) * Upgrades.mult_of("arsenal_haste")
	_timers[id] = _num(id, "cooldown", 3.0) / haste
	return true


func _damage(id: String, level: int) -> float:
	return Upgrades.value("damage", _num(id, "damage", 10.0)) * (1.0 + _num(id, "damage_per_level", 0.25) * (level - 1)) \
			* Upgrades.mult_of("arsenal_damage") * (1.0 + GameState.damage_bonus)


func _process(delta: float) -> void:
	if _player == null or not GameState.is_playing():
		return
	var pos := _player.position
	var aim := _player.aim_dir
	var grid := _ink.grid

	var level := _level("fountain")
	if _due("fountain", level, delta):
		_ring_of_shots(int(_num("fountain", "shots", 8.0) + _num("fountain", "shots_per_level", 2.0) * (level - 1)), _num("fountain", "damage_scale", 0.6))

	level = _level("quill_volley")
	if _due("quill_volley", level, delta):
		var skip: Array = []
		for i in int(_num("quill_volley", "quills", 2.0)) + level:
			var target := _enemies.nearest_excluding(pos, _num("quill_volley", "range", 520.0), skip)
			if target == null:
				break
			skip.append(target)
			_bullets.fire(pos, (target.position - pos).normalized(), _quill, _num("quill_volley", "damage_scale", 0.9))

	level = _level("boomerang")
	if _due("boomerang", level, delta):
		_boomerangs.append({"pos": pos, "dir": aim, "age": 0.0, "level": level, "tick": 0.0})

	level = _level("sprinkler")
	if level > 0:
		_sprinkler_angle += _num("sprinkler", "turn_speed", 5.5) * delta
		if _due("sprinkler", level, delta):
			_bullets.fire(pos, Vector2.from_angle(_sprinkler_angle), _spray, _num("sprinkler", "damage_scale", 0.45))

	level = _level("chain_blot")
	if _due("chain_blot", level, delta):
		_chain(level)

	level = _level("mines")
	if _due("mines", level, delta):
		_hazards.add_mine(pos, _damage("mines", level), _num("mines", "radius", 90.0), _num("mines", "trigger", 55.0), int(_num("mines", "max", 5.0)) + level,
				_num("mines", "slow", 0.0), _num("mines", "slow_seconds", 0.0))

	level = _level("whip")
	if _due("whip", level, delta):
		var center := pos + aim * _num("whip", "reach", 70.0)
		var reach := _num("whip", "radius", 85.0)
		_enemies.damage_area(center, reach, _damage("whip", level))
		for i in 9:
			grid.paint_circle(pos + aim.rotated(-1.0 + i * 0.25) * (reach + 30.0), 7.0, InkGrid.INK)
		_effects.ring(center, reach, Color(0.22, 0.45, 0.95, 0.8), 0.18)

	level = _level("stamp")
	if _due("stamp", level, delta):
		var victim := _random_enemy_near(pos, _num("stamp", "range", 380.0))
		if victim != null:
			var at := victim.position
			var half := _num("stamp", "radius", 62.0) * 0.7
			for k in 7:
				grid.paint_line(at + Vector2(-half, -half + k * half / 3.0), at + Vector2(half, -half + k * half / 3.0), 6.0, InkGrid.INK)
			_enemies.damage_area(at, _num("stamp", "radius", 62.0), _damage("stamp", level))
			_effects.ring(at, _num("stamp", "radius", 62.0), Color(0.05, 0.13, 0.45, 0.9), 0.25)
			Events.screen_shake.emit(4.0)

	_update_turrets(delta)

	level = _level("planes")
	if _due("planes", level, delta):
		for i in level:
			_bullets.fire(pos, Vector2.from_angle(randf() * TAU), _plane, _num("planes", "damage_scale", 1.2))

	level = _level("tidal_wave")
	if _due("tidal_wave", level, delta):
		_waves.append({"pos": pos + aim * 30.0, "dir": aim, "gone": 0.0, "level": level, "tick": 0.0})

	level = _level("ink_rain")
	if _due("ink_rain", level, delta):
		_drop_blot("ink_rain", level, pos, _num("ink_rain", "range", 320.0))

	level = _level("flamethrower")
	if Input.is_action_pressed("fire") and _due("flamethrower", level, delta):
		_spray_cone(level)

	_update_saws(delta)

	level = _level("black_hole")
	if _due("black_hole", level, delta):
		var spot := _enemies.densest_point(pos, 520.0, 120.0)
		if spot != Vector2.INF:
			_hazards.add_hole(spot, _num("black_hole", "radius", 150.0) + _num("black_hole", "radius_per_level", 20.0) * (level - 1),
					_num("black_hole", "duration", 1.4), _damage("black_hole", level), _num("black_hole", "pull_speed", 220.0))

	level = _level("guardian")
	if _due("guardian", level, delta):
		var close := _enemies.nearest(pos, _num("guardian", "range", 170.0))
		if close != null:
			_effects.beam(pos, close.position, Color(0.1, 0.2, 0.6), 10.0, 0.2)
			_enemies.damage(close, _damage("guardian", level), (close.position - pos).normalized())
		else:
			_timers["guardian"] = 0.2  # nothing in range: stay ready

	_update_moving_weapons(delta)
	_update_ink_passives(delta)
	if not (_boomerangs.is_empty() and _turrets.is_empty() and _waves.is_empty() and _saws.is_empty()):
		queue_redraw()


func _ring_of_shots(count: int, scale: float) -> void:
	var start := randf() * TAU
	for i in count:
		_bullets.fire(_player.position, Vector2.from_angle(start + TAU * i / count), _pistol, scale)


func _random_enemy_near(pos: Vector2, max_range: float) -> Enemy:
	for attempt in 8:
		if _enemies.active.is_empty():
			return null
		var enemy: Enemy = _enemies.active[randi() % _enemies.active.size()]
		if enemy.position.distance_to(pos) <= max_range:
			return enemy
	return _enemies.nearest(pos, max_range)


## Chain Blot: a bolt that hops from enemy to enemy.
func _chain(level: int) -> void:
	var from := _player.position
	var struck: Array = []
	var target := _enemies.nearest(from, _num("chain_blot", "range", 420.0))
	var bolt_damage := _damage("chain_blot", level)
	for jump in int(_num("chain_blot", "jumps", 3.0)) + level:
		if target == null:
			break
		var at := target.position
		struck.append(target)
		_effects.beam(from, at, Color(0.55, 0.75, 1.0), 6.0, 0.18)
		_enemies.damage(target, bolt_damage, (at - from).normalized())
		from = at
		target = _enemies.nearest_excluding(from, _num("chain_blot", "jump_range", 220.0), struck)


func _drop_blot(id: String, level: int, around: Vector2, max_range: float) -> void:
	var at := around + Vector2.from_angle(randf() * TAU) * randf_range(40.0, max_range)
	_ink.splat(at, _num(id, "radius", 34.0) * 0.65, Vector2.ZERO)
	_enemies.damage_area(at, _num(id, "radius", 34.0), _damage(id, maxi(level, 1)))
	_effects.ring(at, _num(id, "radius", 34.0), Color(0.22, 0.45, 0.95, 0.7), 0.2)


## Spray Nozzle: everything in a short cone in front of the player.
func _spray_cone(level: int) -> void:
	var pos := _player.position
	var aim := _player.aim_dir
	var reach := _num("flamethrower", "range", 170.0)
	var cos_half := cos(deg_to_rad(_num("flamethrower", "half_angle_deg", 28.0)))
	var found: Array = []
	_enemies.grid.query(pos, reach, found)
	var spray_damage := _damage("flamethrower", level)
	for enemy: Enemy in found:
		var offset := enemy.position - pos
		var d := offset.length()
		if enemy.active and d <= reach + enemy.radius and d > 0.01 and offset.dot(aim) >= cos_half * d:
			_enemies.damage(enemy, spray_damage, aim)
	_effects.burst(pos + aim * 24.0, aim * 1.4, Color(0.4, 0.75, 1.0), 4)


## Ink Turret (placed where you stand) and Ink Sprouts (grown on your ink).
func _update_turrets(delta: float) -> void:
	var pos := _player.position
	var level := _level("turret")
	if _due("turret", level, delta):
		_add_turret(pos, _num("turret", "life", 18.0), false, 1 + level)
	level = _level("sprouts")
	if _due("sprouts", level, delta):
		for attempt in 10:
			var spot := pos + Vector2.from_angle(randf() * TAU) * randf_range(60.0, _num("sprouts", "range", 300.0))
			if _ink.grid.is_ink(spot):
				_add_turret(spot, _num("sprouts", "life", 14.0), true, 2 * level)
				break
	var i := _turrets.size() - 1
	while i >= 0:
		var turret := _turrets[i]
		turret["life"] -= delta
		turret["cool"] -= delta
		var at: Vector2 = turret["pos"]
		if turret["life"] <= 0.0:
			_turrets.remove_at(i)
		elif turret["cool"] <= 0.0 and _ink.grid.is_ink(at):
			var target := _enemies.nearest(at, _num("turret", "range", 380.0))
			if target != null:
				turret["cool"] = _num("turret", "fire_interval", 0.7)
				turret["aim"] = (target.position - at).normalized()
				_bullets.fire(at, turret["aim"], _pistol, _num("turret", "damage_scale", 0.6))
		i -= 1


func _add_turret(pos: Vector2, life: float, sprout: bool, limit: int) -> void:
	var same := 0
	for turret in _turrets:
		if turret["sprout"] == sprout:
			same += 1
	if same >= limit:
		for i in _turrets.size():
			if _turrets[i]["sprout"] == sprout:
				_turrets.remove_at(i)
				break
	_turrets.append({"pos": pos, "life": life, "cool": 0.3, "sprout": sprout, "aim": Vector2.RIGHT})


func _update_saws(delta: float) -> void:
	var level := _level("saw")
	while _saws.size() < level:
		_saws.append({"pos": _player.position, "vel": Vector2.from_angle(randf() * TAU) * _num("saw", "speed", 360.0)})
	if _saws.is_empty():
		return
	# Saws bounce inside a box around the player, so they stay on screen.
	var box := Rect2(_player.position - Vector2(560.0, 320.0), Vector2(1120.0, 640.0))
	_saw_tick -= delta
	var cut := _saw_tick <= 0.0
	if cut:
		_saw_tick = _num("saw", "tick", 0.15)
	for saw in _saws:
		var pos: Vector2 = saw["pos"]
		var vel: Vector2 = saw["vel"]
		pos += vel * delta
		if pos.x < box.position.x or pos.x > box.end.x:
			vel.x = absf(vel.x) if pos.x < box.position.x else -absf(vel.x)
		if pos.y < box.position.y or pos.y > box.end.y:
			vel.y = absf(vel.y) if pos.y < box.position.y else -absf(vel.y)
		saw["pos"] = pos
		saw["vel"] = vel
		if cut:
			_enemies.damage_area(pos, _num("saw", "radius", 30.0), _damage("saw", level))


## Boomerangs, tidal waves, and the burning trail.
func _update_moving_weapons(delta: float) -> void:
	var grid := _ink.grid
	var i := _boomerangs.size() - 1
	while i >= 0:
		var rang := _boomerangs[i]
		rang["age"] += delta
		var pos: Vector2 = rang["pos"]
		var outbound: bool = rang["age"] < _num("boomerang", "out_time", 0.5)
		var dir: Vector2 = rang["dir"] if outbound else (_player.position - pos).normalized()
		pos += dir * _num("boomerang", "speed", 520.0) * delta
		rang["pos"] = pos
		grid.paint_circle(pos, 6.0, InkGrid.INK)
		rang["tick"] -= delta
		if rang["tick"] <= 0.0:
			rang["tick"] = 0.1
			_enemies.damage_area(pos, _num("boomerang", "radius", 26.0), _damage("boomerang", int(rang["level"])))
		if (not outbound and pos.distance_to(_player.position) < 30.0) or rang["age"] > 3.0:
			_boomerangs.remove_at(i)
		i -= 1

	i = _waves.size() - 1
	while i >= 0:
		var wave := _waves[i]
		var dir: Vector2 = wave["dir"]
		var step := _num("tidal_wave", "speed", 300.0) * delta
		wave["pos"] += dir * step
		wave["gone"] += step
		wave["tick"] -= delta
		if wave["tick"] <= 0.0:
			wave["tick"] = 0.08
			var half := (_num("tidal_wave", "width", 110.0) + _num("tidal_wave", "width_per_level", 25.0) * (int(wave["level"]) - 1)) * 0.5
			var pos: Vector2 = wave["pos"]
			var side := dir.orthogonal() * half
			_enemies.damage_segment(pos - side, pos + side, 20.0, _damage("tidal_wave", int(wave["level"])))
			grid.paint_line(pos - side, pos + side, 14.0, InkGrid.INK)
		if wave["gone"] >= _num("tidal_wave", "range", 520.0):
			_waves.remove_at(i)
		i -= 1

	# Trailblazer: recent footsteps burn whatever crosses them.
	var blaze := Upgrades.bonus("trailblazer")
	if blaze > 0.0:
		if _trail.is_empty() or _player.position.distance_to(_trail[_trail.size() - 1]["pos"]) > _num("trailblazer", "spacing", 40.0):
			_trail.append({"pos": _player.position, "age": 0.0})
			if _trail.size() > int(_num("trailblazer", "points", 14.0)):
				_trail.remove_at(0)
		_trail_tick -= delta
		var burn := _trail_tick <= 0.0
		if burn:
			_trail_tick = _num("trailblazer", "tick", 0.25)
		var k := _trail.size() - 1
		while k >= 0:
			_trail[k]["age"] += delta
			if _trail[k]["age"] > _num("trailblazer", "life", 2.0):
				_trail.remove_at(k)
			elif burn:
				_enemies.damage_area(_trail[k]["pos"], _num("trailblazer", "radius", 18.0), blaze * _num("trailblazer", "tick", 0.25) * (1.0 + GameState.damage_bonus))
			k -= 1


## Passive ink upgrades and timed powers that act on the page.
func _update_ink_passives(delta: float) -> void:
	var grid := _ink.grid
	var pos := _player.position

	var level := _level("electric")
	if _due("electric", level, delta):
		var strikes := 0
		for attempt in 14:
			if strikes >= level or _enemies.active.is_empty():
				break
			var enemy: Enemy = _enemies.active[randi() % _enemies.active.size()]
			if grid.is_ink(enemy.position):
				strikes += 1
				_effects.beam(enemy.position - Vector2(0.0, 90.0), enemy.position, Color(1.0, 0.92, 0.3), 5.0, 0.15)
				_enemies.damage(enemy, _damage("electric", level))

	level = _level("living")
	if _due("living", level, delta):
		for sample in int(_num("living", "samples", 30.0)) * level:
			var index := randi() % grid.total_cells()
			if grid.cells[index] == InkGrid.INK or grid.cells[index] == InkGrid.LOCKED:
				grid.paint_circle(grid.cell_center(index), grid.cell_size * 1.6, InkGrid.INK)

	level = _level("bridges")
	if _due("bridges", level, delta):
		grid.close_gaps(pos, _num("bridges", "radius", 260.0), int(_num("bridges", "span", 2.0)) + level)

	level = _level("tide")
	if _due("tide", level, delta):
		grid.grow_ink(pos, _num("tide", "radius", 520.0), level)
		_effects.ring(pos, _num("tide", "radius", 520.0), Color(0.22, 0.45, 0.95, 0.6), 0.6)

	# Watermark: smudge over former ink wears off and the ink returns.
	grid.track_smudged_ink = Upgrades.bonus("watermark") > 0.0
	if grid.track_smudged_ink:
		_watermark_left -= delta
		if _watermark_left <= 0.0:
			_watermark_left = 1.0
			var chance := _num("watermark", "chance_per_second", 0.1)
			var keep := PackedInt32Array()
			for index in grid.smudged_ink:
				if grid.cells[index] != InkGrid.SMUDGE:
					continue
				if randf() < chance:
					grid.set_cell(index, InkGrid.INK)
				else:
					keep.append(index)
			grid.smudged_ink = keep

	if GameState.has_power("bomb_rain"):
		var rain_left := float(_timers.get("bomb_rain", 0.0)) - delta
		if rain_left <= 0.0:
			rain_left = _num("bomb_rain", "interval", 0.45)
			var at := pos + Vector2.from_angle(randf() * TAU) * randf_range(80.0, _num("bomb_rain", "range", 420.0))
			_secondary.drop_at(at, _num("bomb_rain", "size", 0.7))
		_timers["bomb_rain"] = rain_left

	# Wet Ink Wall: remember the fresh trail so it can be drawn while it holds.
	var wall := Upgrades.bonus("ink_wall")
	if wall > 0.0:
		var hold := _num("ink_wall", "seconds", 2.0) + _num("ink_wall", "seconds_per_level", 1.0) * (wall - 1.0)
		if _wall_points.is_empty() or pos.distance_to(_wall_points[_wall_points.size() - 1]["pos"]) > 10.0:
			if not _wall_points.is_empty():
				grid.mark_wall_line(_wall_points[_wall_points.size() - 1]["pos"], pos, 10.0, GameState.run_time + hold)
			_wall_points.append({"pos": pos, "until": GameState.run_time + hold, "hold": hold})
		while not _wall_points.is_empty() and float(_wall_points[0]["until"]) <= GameState.run_time:
			_wall_points.remove_at(0)
		queue_redraw()

	if GameState.has_power("ink_storm"):
		var left := float(_timers.get("ink_storm", 0.0)) - delta
		if left <= 0.0:
			left = _num("ink_storm", "interval", 0.22)
			_drop_blot("ink_storm", 1, pos, _num("ink_storm", "range", 520.0))
		_timers["ink_storm"] = left


## Retaliation: being hurt fires a free ring of shots.
func _on_player_hurt() -> void:
	var level := _level("retaliation")
	if level > 0:
		_ring_of_shots(8 + 4 * (level - 1), 0.7)


func _on_power_granted(id: String, _seconds: float) -> void:
	if id == "eraser_wave":
		var reach := _num("eraser_wave", "radius", 700.0)
		_ink.grid.clean_circle(_player.position, reach)
		_effects.ring(_player.position, reach, Color(0.06, 0.72, 0.5, 0.9), 0.6)


func _draw() -> void:
	var spin := Time.get_ticks_msec() * 0.012
	# The wet wall: bright while fresh, fading as it dries.
	for i in range(1, _wall_points.size()):
		var a: Dictionary = _wall_points[i - 1]
		var b: Dictionary = _wall_points[i]
		if (a["pos"] as Vector2).distance_to(b["pos"]) > 60.0:
			continue
		var wet := clampf((float(b["until"]) - GameState.run_time) / float(b["hold"]), 0.0, 1.0)
		draw_line(a["pos"], b["pos"], Color(0.02, 0.06, 0.25, 0.9 * wet), 14.0)
		draw_line(a["pos"], b["pos"], Color(0.7, 0.9, 1.0, wet), 4.0)
	for rang in _boomerangs:
		var pos: Vector2 = rang["pos"]
		var arm := Vector2.from_angle(spin * 2.0) * 16.0
		draw_line(pos - arm, pos, Color("#0b1b4d"), 7.0)
		draw_line(pos, pos + arm.orthogonal(), Color("#0b1b4d"), 7.0)
		draw_circle(pos, 5.0, Color("#38bdf8"))
	for wave in _waves:
		var pos: Vector2 = wave["pos"]
		var dir: Vector2 = wave["dir"]
		var half := (_num("tidal_wave", "width", 110.0) + _num("tidal_wave", "width_per_level", 25.0) * (int(wave["level"]) - 1)) * 0.5
		var side := dir.orthogonal() * half
		draw_line(pos - side, pos + side, Color(0.22, 0.45, 0.95, 0.5), 30.0)
		draw_line(pos - side + dir * 10.0, pos + side + dir * 10.0, Color(0.75, 0.88, 1.0, 0.9), 6.0)
	for saw in _saws:
		var pos: Vector2 = saw["pos"]
		var teeth := PackedVector2Array()
		for k in 16:
			teeth.append(pos + Vector2.from_angle(spin + TAU * k / 16.0) * (30.0 if k % 2 == 0 else 20.0))
		draw_colored_polygon(teeth, Color("#12235e"))
		draw_circle(pos, 9.0, Color("#93b4ff"))
	for turret in _turrets:
		var pos: Vector2 = turret["pos"]
		var fade := clampf(float(turret["life"]) / 2.0, 0.25, 1.0)
		var live := _ink.grid.is_ink(pos)
		if turret["sprout"]:
			for k in 5:
				draw_circle(pos + Vector2.from_angle(TAU * k / 5.0) * 9.0, 6.0, Color(0.23, 0.51, 0.96, fade))
			draw_circle(pos, 5.0, Color(0.98, 0.75, 0.14, fade))
		else:
			draw_circle(pos + Vector2(2, 3), 13.0, Color(0, 0, 0, 0.25 * fade))
			draw_circle(pos, 13.0, Color(0.07, 0.14, 0.37, fade) if live else Color(0.4, 0.4, 0.42, fade))
			var aim: Vector2 = turret["aim"]
			draw_line(pos, pos + aim * 20.0, Color(0.02, 0.05, 0.17, fade), 6.0)
			draw_circle(pos, 5.0, Color(0.58, 0.71, 1.0, fade))
