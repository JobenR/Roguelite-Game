class_name BulletManager
extends Node2D
## Owns every bullet: pooling, movement, homing, ink dots, and hits against
## the enemy grid. Shot upgrades (pierce, ricochet, split, frost...) resolve here.

const BULLET_SCENE := preload("res://entities/bullets/bullet.tscn")
const SHED_INTERVAL := 0.07

var active: Array[Bullet] = []

var _pool: ObjectPool
var _enemies: EnemyManager
var _arena: Rect2
var _effects: Effects
var _ink: InkSystem
var _scratch: Array = []
var _pending: Array[Dictionary] = []  # shots spawned mid-loop (splits)


func setup(enemies: EnemyManager, arena: Rect2, effects: Effects, ink: InkSystem) -> void:
	_enemies = enemies
	_arena = arena
	_effects = effects
	_ink = ink
	_pool = ObjectPool.new(BULLET_SCENE, self, 32)


func fire(pos: Vector2, dir: Vector2, weapon: Dictionary, damage_scale: float = 1.0) -> Bullet:
	var bullet: Bullet = _pool.acquire()
	bullet.launch(pos, dir, weapon, damage_scale)
	active.append(bullet)
	return bullet


func _process(delta: float) -> void:
	if _enemies == null or not GameState.is_playing():
		return
	var painter := int(Upgrades.bonus("painter"))

	var i := active.size() - 1
	while i >= 0:
		var bullet := active[i]
		if bullet.homing_rate > 0.0:
			_steer(bullet, bullet.homing_rate * delta, float(bullet.weapon.get("homing_range", 170.0)))
		var step := bullet.velocity * delta
		bullet.position += step
		bullet.life -= delta

		if painter > 0:
			# Painter's Shots: dots of ink, packed closer at higher levels.
			bullet.paint_left -= step.length()
			if bullet.paint_left <= 0.0:
				var gaps: Array = bullet.weapon.get("painter_spacing", [56, 36, 18])
				bullet.paint_left = float(gaps[mini(painter, gaps.size()) - 1])
				_ink.grid.paint_circle(bullet.position, 5.0, InkGrid.INK)
		bullet.shed_left -= delta
		if bullet.shed_left <= 0.0:
			bullet.shed_left = SHED_INTERVAL
			_effects.drip(bullet.position - step, bullet.glow, bullet.radius * 0.5)

		var done := bullet.life <= 0.0
		if not done and not _arena.has_point(bullet.position):
			if bullet.wall_bounces > 0:
				# Wall Bounce: reflect off the page edge.
				bullet.wall_bounces -= 1
				if bullet.position.x < _arena.position.x or bullet.position.x > _arena.end.x:
					bullet.velocity.x = -bullet.velocity.x
				if bullet.position.y < _arena.position.y or bullet.position.y > _arena.end.y:
					bullet.velocity.y = -bullet.velocity.y
				bullet.position = bullet.position.clamp(_arena.position, _arena.end)
				bullet.rotation = bullet.velocity.angle()
			else:
				done = true
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

	# Shots created by hits are launched after the loop, so the list being
	# walked is never grown mid-walk.
	for shot in _pending:
		var child := fire(shot["pos"], shot["dir"], shot["weapon"], shot["scale"])
		child.hit.append(shot["skip"])
	_pending.clear()


## Homing: turn toward the nearest unstruck enemy, limited per frame.
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

	var amount := bullet.damage
	if enemy.hp >= enemy.max_hp:
		amount *= 1.0 + Upgrades.bonus("first_strike")
	if enemy.heavy:
		amount *= 1.0 + Upgrades.bonus("giant")
	# Status effects land before the damage, so a staining shot boosts itself.
	var frost := Upgrades.bonus("frost")
	if frost > 0.0:
		var slow := DataDB.arsenal_num("frost", "slow", 0.15) + DataDB.arsenal_num("frost", "slow_per_level", 0.1) * (frost - 1.0)
		_enemies.apply_slow(enemy, slow, DataDB.arsenal_num("frost", "seconds", 2.0))
	var stain := Upgrades.bonus("stain")
	if stain > 0.0:
		enemy.stain_left = 3.0
		enemy.stain_amount = stain
	var bleed := Upgrades.bonus("bleed")
	if bleed > 0.0:
		enemy.bleed_left = 3.0
		enemy.bleed_dps = bleed
	if bullet.knockback > 0.0 and not enemy.heavy:
		enemy.position += dir * bullet.knockback

	_enemies.damage(enemy, amount, dir)
	if bullet.crit and not enemy.active:
		_ink.splat(hit_pos, 34.0, dir)
	if bullet.burst_radius > 0.0:
		_enemies.damage_area(hit_pos, bullet.burst_radius, amount * bullet.burst_damage_mult)
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
	if bullet.can_split:
		# Splitting Shots: two smaller shots fan out from the impact.
		var level := Upgrades.bonus("split")
		var child_weapon := bullet.weapon.duplicate()
		child_weapon["no_split"] = true
		child_weapon["bullet_life"] = 0.45
		var share := DataDB.arsenal_num("split", "damage_scale", 0.4) + DataDB.arsenal_num("split", "damage_scale_per_level", 0.1) * (level - 1.0)
		var base := Upgrades.value("damage", float(bullet.weapon.get("damage", 5.0)))
		var angle := deg_to_rad(DataDB.arsenal_num("split", "angle_deg", 28.0))
		for side: float in [-1.0, 1.0]:
			_pending.append({"pos": bullet.position, "dir": dir.rotated(side * angle), "weapon": child_weapon,
				"scale": share * bullet.damage / maxf(base, 0.01) / (1.0 + GameState.damage_bonus), "skip": enemy})
	return true
