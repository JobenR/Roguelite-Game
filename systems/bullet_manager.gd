class_name BulletManager
extends Node2D
## Owns every bullet: pooling, movement, and hits against the enemy grid.

const BULLET_SCENE := preload("res://entities/bullets/bullet.tscn")

var active: Array[Bullet] = []

var _pool: ObjectPool
var _enemies: EnemyManager
var _arena: Rect2
var _scratch: Array = []


func setup(enemies: EnemyManager, arena: Rect2) -> void:
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
				if not enemy.active:
					continue
				var reach := bullet.radius + enemy.radius
				if bullet.position.distance_squared_to(enemy.position) <= reach * reach:
					_enemies.damage(enemy, bullet.damage)
					done = true
					break
		if done:
			# Swap-remove keeps removal O(1).
			active[i] = active[active.size() - 1]
			active.pop_back()
			_pool.release(bullet)
		i -= 1
