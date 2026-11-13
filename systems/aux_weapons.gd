class_name AuxWeapons
extends Node2D
## Extra weapons granted by upgrades, running alongside the main gun:
##   laser (Ink Jet): a piercing beam on a timer that leaves a line of ink.
##   orbit (Orbiting Blots): ink balls circling the player.
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


func setup(player: Player, enemies: EnemyManager, ink: InkSystem, effects: Effects) -> void:
	_player = player
	_enemies = enemies
	_ink = ink
	_effects = effects
	_laser = DataDB.weapons.get("laser", {})
	_orbit = DataDB.weapons.get("orbit", {})


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
	_effects.beam(from, to, Color(0.25, 0.5, 1.0), width)
	Events.screen_shake.emit(3.0)


func _draw() -> void:
	if _player == null:
		return
	var balls := int(Upgrades.bonus("orbit"))
	var ball_radius := float(_orbit.get("ball_radius", 12.0))
	for i in balls:
		var pos := _ball_pos(i, balls)
		draw_circle(pos + Vector2(2.0, 4.0), ball_radius, Color(0, 0, 0, 0.25))
		draw_circle(pos, ball_radius, Color("#12235e"))
		draw_circle(pos - Vector2(ball_radius, ball_radius) * 0.28, ball_radius * 0.4, Color("#5b7fd6"))
		draw_arc(pos, ball_radius, 0.0, TAU, 20, Color("#060d2b"), 2.5)
