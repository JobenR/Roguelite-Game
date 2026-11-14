class_name BulletManager
extends Node2D
## Owns every bullet: pooling, movement, homing, ink dots, and hits against
## the enemy grid.

const BULLET_SCENE := preload("res://entities/bullets/bullet.tscn")
const SHED_INTERVAL := 0.07

var active: Array[Bullet] = []

var _pool: ObjectPool
var _enemies: EnemyManager
var _arena: Rect2
var _effects: Effects
var _ink: InkSystem
var _scratch: Array = []
var _weapon: Dictionary = {}


func setup(enemies: EnemyManager, arena: Rect2, effects: Effects, ink: InkSystem) -> void:
	_enemies = enemies
	_arena = arena
	_effects = effects
	_ink = ink
	_pool = ObjectPool.new(BULLET_SCENE, self, 32)


func fire(pos: Vector2, dir: Vector2, weapon: Dictionary, damage_scale: float = 1.0) -> void:
	_weapon = weapon
	var bullet: Bullet = _pool.acquire()
	bullet.launch(pos, dir, weapon, damage_scale)
	active.append(bullet)


func _process(delta: float) -> void:
	if _enemies == null or not GameState.is_playing():
		return
	var homing := Upgrades.bonus("homing")
	var homing_range := float(_weapon.get("homing_range", 170.0))
	# Painter's Shots: distance between ink dots, tighter at higher levels.
	var painter := int(Upgrades.bonus("painter"))
	var paint_gap := 0.0
	if painter > 0:
		var gaps: Array = _weapon.get("painter_spacing", [56, 36, 18])
		paint_gap = float(gaps[mini(painter, gaps.size()) - 1])

	var i := active.size() - 1
	while i >= 0:
		var bullet := active[i]
		if homing > 0.0:
			_steer(bullet, homing * delta, homing_range)
		var step := bullet.velocity * delta
		bullet.position += step
		bullet.life -= delta

		if paint_gap > 0.0:
			bullet.paint_left -= step.length()
			if bullet.paint_left <= 0.0:
				bullet.paint_left = paint_gap
				_ink.grid.paint_circle(bullet.position, 5.0, InkGrid.INK)
		bullet.shed_left -= delta
		if bullet.shed_left <= 0.0:
			bullet.shed_left = SHED_INTERVAL
			_effects.drip(bullet.position - step, bullet.glow, bullet.radius * 0.5)

		var done := bullet.life <= 0.0 or not _arena.has_point(bullet.position)
		if not done:
			_enemies.grid.query(bullet.position, bullet.radius + _enemies.max_radius, _scratch)
			for enemy: Enemy in _scratch:
				if not enemy.active or bullet.hit.has(enemy):
					continue
				var reach := bullet.radius + enemy.radius
				if bullet.position.distance_squared_to(enemy.position) <= reach * reach:
					done = _resolve_hit(bullet, enemy)
					break
		if done:
			# Swap-remove keeps removal O(1).
			active[i] = active[active.size() - 1]
			active.pop_back()
			_pool.release(bullet)
		i -= 1


## Homing Ink: turn toward the nearest unstruck enemy, limited per frame.
func _steer(bullet: Bullet, max_turn: float, search: float) -> void:
	_enemies.grid.query(bullet.position, search, _scratch)
	var best: Enemy = null
	var best_sq := search * search
	for enemy: Enemy in _scratch:
		if not enemy.active or bullet.hit.has(enemy):
			continue
		var d_sq := bullet.position.distance_squared_to(enemy.position)
		if d_sq < best_sq:
			best_sq = d_sq
			best = enemy
	if best == null:
		return
	var turn := bullet.velocity.angle_to(best.position - bullet.position)
	bullet.velocity = bullet.velocity.rotated(clampf(turn, -max_turn, max_turn))
	bullet.rotation = bullet.velocity.angle()


## Applies a hit. Returns true when the bullet is spent.
func _resolve_hit(bullet: Bullet, enemy: Enemy) -> bool:
	var hit_pos := enemy.position
	var dir := bullet.velocity.normalized()
	_effects.burst(bullet.position, dir * 0.4, bullet.glow, 3)
	_enemies.damage(enemy, bullet.damage, dir)
	if bullet.burst_radius > 0.0:
		_enemies.damage_area(hit_pos, bullet.burst_radius, bullet.damage * bullet.burst_damage_mult)
		_effects.ring(hit_pos, bullet.burst_radius, Color(0.95, 0.55, 0.15, 0.8), 0.2)
	bullet.hit.append(enemy)
	if bullet.pierce_left > 0:
		bullet.pierce_left -= 1
		return false
	if bullet.ricochet_left > 0:
		var next := _enemies.nearest_excluding(hit_pos, 320.0, bullet.hit)
		if next != null:
			bullet.ricochet_left -= 1
			bullet.velocity = (next.position - bullet.position).normalized() * bullet.speed
			bullet.rotation = bullet.velocity.angle()
			bullet.life = maxf(bullet.life, 0.5)
			return false
	return true
