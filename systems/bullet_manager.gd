class_name BulletManager
extends Node2D
## Owns every bullet: pooling, movement, and hits against the enemy grid.

const BULLET_SCENE := preload("res://entities/bullets/bullet.tscn")

var active: Array[Bullet] = []

var _pool: ObjectPool
var _enemies: EnemyManager
var _arena: Rect2
var _scratch: Array = []
var _effects: Effects


func setup(enemies: EnemyManager, arena: Rect2, effects: Effects) -> void:
	_effects = effects
	_enemies = enemies
	_arena = arena
	_pool = ObjectPool.new(BULLET_SCENE, self, 32)


func fire(pos: Vector2, dir: Vector2, weapon: Dictionary) -> void:
	var bullet: Bullet = _pool.acquire()
	bullet.launch(pos, dir, weapon)
	active.append(bullet)


func _process(delta: float) -> void:
	if _enemies == null or not GameState.is_playing():
		return
	var i := active.size() - 1
	while i >= 0:
		var bullet := active[i]
		bullet.position += bullet.velocity * delta
		bullet.life -= delta
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


## Applies a hit. Returns true when the bullet is spent.
func _resolve_hit(bullet: Bullet, enemy: Enemy) -> bool:
	var hit_pos := enemy.position
	_enemies.damage(enemy, bullet.damage)
	if bullet.burst_radius > 0.0:
		_enemies.damage_area(hit_pos, bullet.burst_radius, bullet.damage * 0.5)
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
			bullet.life = maxf(bullet.life, 0.5)
			return false
	return true
