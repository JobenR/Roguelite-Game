class_name AuxWeapons
extends Node2D
## Extra weapons granted by upgrades, running alongside the main gun:
##   laser (Ink Jet): a piercing beam on a timer that leaves a line of ink.
##   orbit (Orbiting Blots): ink balls circling the player.
##   mortar (Ink Mortar): shells lobbed at the thickest crowd.
## Numbers come from the "laser" and "orbit" entries in weapons.json.

var _player: Player
var _enemies: EnemyManager
var _ink: InkSystem
var _effects: Effects
var _laser: Dictionary = {}
var _orbit: Dictionary = {}
var _laser_left: float = 1.0
var _orbit_angle: float = 0.0
var _orbit_tick: float = 0.0
var _mortar: Dictionary = {}
var _mortar_left: float = 2.0
var _shells: Array[Dictionary] = []


func setup(player: Player, enemies: EnemyManager, ink: InkSystem, effects: Effects) -> void:
	_player = player
	_enemies = enemies
	_ink = ink
	_effects = effects
	_laser = DataDB.weapons.get("laser", {})
	_orbit = DataDB.weapons.get("orbit", {})
	_mortar = DataDB.weapons.get("mortar", {})


func _process(delta: float) -> void:
	if _player == null or not GameState.is_playing():
		return
	var laser_level := int(Upgrades.bonus("laser"))
	if laser_level > 0:
		_laser_left -= delta
		if _laser_left <= 0.0:
			var faster := 1.0 + float(_laser.get("cooldown_per_level", 0.25)) * (laser_level - 1)
			_laser_left = float(_laser.get("cooldown", 3.0)) / faster
			_fire_laser()

	_update_mortar(delta)

	var balls := int(Upgrades.bonus("orbit"))
	if balls > 0:
		_orbit_angle += float(_orbit.get("speed", 3.0)) * delta
		_orbit_tick -= delta
		if _orbit_tick <= 0.0:
			_orbit_tick = float(_orbit.get("tick", 0.2))
			var ball_damage := Upgrades.value("damage", float(_orbit.get("damage", 8.0)))
			for i in balls:
				_enemies.damage_area(_ball_pos(i, balls), float(_orbit.get("ball_radius", 12.0)), ball_damage)
		queue_redraw()


func _update_mortar(delta: float) -> void:
	var level := int(Upgrades.bonus("mortar"))
	if level > 0:
		_mortar_left -= delta
		if _mortar_left <= 0.0:
			var faster := 1.0 + float(_mortar.get("cooldown_per_level", 0.15)) * (level - 1)
			_mortar_left = float(_mortar.get("cooldown", 5.5)) / faster
			var target := _enemies.densest_point(_player.position, float(_mortar.get("range", 650.0)), 110.0)
			if target != Vector2.INF:
				_shells.append({"from": _player.position, "to": target, "t": 0.0, "level": level})
	if _shells.is_empty():
		return
	var i := _shells.size() - 1
	while i >= 0:
		var shell := _shells[i]
		shell["t"] += delta / maxf(0.05, float(_mortar.get("flight_time", 0.7)))
		if shell["t"] >= 1.0:
			_shells.remove_at(i)
			_land_shell(shell)
		i -= 1
	queue_redraw()


func _land_shell(shell: Dictionary) -> void:
	var pos: Vector2 = shell["to"]
	var level: int = shell["level"]
	var radius := float(_mortar.get("blast_radius", 95.0))
	var shell_damage := Upgrades.value("damage", float(_mortar.get("damage", 28.0)))
	shell_damage *= 1.0 + float(_mortar.get("damage_per_level", 0.2)) * (level - 1)
	_ink.splat(pos, float(_mortar.get("splat_radius", 80.0)), Vector2.ZERO)
	_enemies.damage_area(pos, radius, shell_damage)
	_effects.ink_burst(pos, radius)
	_effects.burst(pos, Vector2.ZERO, Color(0.08, 0.07, 0.06), 12)
	Events.screen_shake.emit(5.0)


func _ball_pos(index: int, count: int) -> Vector2:
	return _player.position + Vector2.from_angle(_orbit_angle + TAU * index / count) * float(_orbit.get("radius", 78.0))


func _fire_laser() -> void:
	var dir := _player.aim_dir
	var from := _player.position + dir * (_player.radius + 6.0)
	var to := from + dir * float(_laser.get("length", 700.0))
	var width := float(_laser.get("width", 14.0))
	var beam_damage := Upgrades.value("damage", float(_laser.get("damage", 18.0)))
	# Copy the list: a kill removes from `active` while we loop.
	for enemy: Enemy in _enemies.active.duplicate():
		var closest := Geometry2D.get_closest_point_to_segment(enemy.position, from, to)
		var reach := width + enemy.radius
		if closest.distance_squared_to(enemy.position) <= reach * reach:
			_enemies.damage(enemy, beam_damage, dir)
	_ink.grid.paint_line(from, to, float(_laser.get("ink_radius", 5.0)), InkGrid.INK)
	_effects.beam(from, to, Color(0.08, 0.07, 0.06), width)
	Events.screen_shake.emit(3.0)


func _draw() -> void:
	if _player == null:
		return
	for shell in _shells:
		var t: float = shell["t"]
		var from: Vector2 = shell["from"]
		var to: Vector2 = shell["to"]
		var ground := from.lerp(to, t)
		var height := sin(t * PI) * 120.0
		# Target marker, ground shadow, then the shell arcing above it.
		draw_arc(to, 26.0, 0.0, TAU, 24, Color(0.85, 0.15, 0.2, 0.5), 3.0)
		draw_circle(ground, 9.0, Color(0, 0, 0, 0.2))
		draw_circle(ground - Vector2(0.0, height), 11.0 + height * 0.04, Color("#141210"))
		draw_circle(ground - Vector2(3.0, height + 3.0), 4.0, Color("#8a8273"))
	var balls := int(Upgrades.bonus("orbit"))
	var ball_radius := float(_orbit.get("ball_radius", 12.0))
	for i in balls:
		var pos := _ball_pos(i, balls)
		draw_circle(pos + Vector2(2.0, 4.0), ball_radius, Color(0, 0, 0, 0.25))
		draw_circle(pos, ball_radius, Color("#141210"))
		draw_circle(pos - Vector2(ball_radius, ball_radius) * 0.28, ball_radius * 0.4, Color("#8a8273"))
		draw_arc(pos, ball_radius, 0.0, TAU, 20, Color("#141210"), 2.5)
