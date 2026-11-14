class_name EnemyManager
extends Node2D
## Owns every enemy: pooling, movement, separation, contact damage, death.
## One loop per frame over a flat array; collisions use the spatial grid.

const ENEMY_SCENE := preload("res://entities/enemies/enemy.tscn")
const GRID_CELL := 64.0
const SEPARATION_STRENGTH := 8.0

var active: Array[Enemy] = []
var grid: SpatialGrid
var max_radius: float = 0.0

var _pool: ObjectPool
var _player: Player
var _ink: InkSystem
var _effects: Effects
var _burn_left: float = 0.0
var _burning: Array[Enemy] = []
var _arena: Rect2
var _scratch: Array = []


func setup(player: Player, arena: Rect2, ink: InkSystem, effects: Effects) -> void:
	_effects = effects
	_player = player
	_ink = ink
	_arena = arena
	grid = SpatialGrid.new(arena.size, GRID_CELL)
	_pool = ObjectPool.new(ENEMY_SCENE, self, 64)


func spawn(type_id: String, pos: Vector2, hp_mult: float = 1.0) -> Enemy:
	var data: Dictionary = DataDB.enemies.get(type_id, {})
	if data.is_empty():
		push_error("EnemyManager: unknown enemy type '%s'" % type_id)
		return null
	var enemy: Enemy = _pool.acquire()
	enemy.spawn(type_id, data, pos, hp_mult)
	active.append(enemy)
	max_radius = maxf(max_radius, enemy.radius)
	return enemy


## dir is the direction the blow travels; it shapes the kill splat.
func damage(enemy: Enemy, amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	if not enemy.active:
		return
	enemy.last_hit_dir = dir
	enemy.hp -= amount
	if enemy.hp <= 0.0:
		_kill(enemy)
	else:
		enemy.visual.flash()


## Damages every enemy whose circle touches the blast circle.
func damage_area(pos: Vector2, radius: float, amount: float) -> void:
	# Local array: a kill here can trigger another blast while we iterate.
	var found: Array = []
	grid.query(pos, radius + max_radius, found)
	for enemy: Enemy in found:
		if not enemy.active:
			continue
		var reach := radius + enemy.radius
		if pos.distance_squared_to(enemy.position) <= reach * reach:
			damage(enemy, amount, (enemy.position - pos).normalized())


## Nearest active enemy within max_range of pos, or null.
func nearest(pos: Vector2, max_range: float) -> Enemy:
	var best: Enemy = null
	var best_sq := max_range * max_range
	for enemy in active:
		var d_sq := pos.distance_squared_to(enemy.position)
		if d_sq < best_sq:
			best_sq = d_sq
			best = enemy
	return best


## Damages every enemy within `width` of the segment (beams, spikes).
func damage_segment(from: Vector2, to: Vector2, width: float, amount: float) -> void:
	var dir := (to - from).normalized()
	# Copy the list: a kill removes from `active` while we loop.
	for enemy: Enemy in active.duplicate():
		var closest := Geometry2D.get_closest_point_to_segment(enemy.position, from, to)
		var reach := width + enemy.radius
		if closest.distance_squared_to(enemy.position) <= reach * reach:
			damage(enemy, amount, dir)


## Pushes enemies inside the circle away from its centre.
func knockback(center: Vector2, radius: float, distance: float) -> void:
	for enemy in active:
		var offset := enemy.position - center
		var d := offset.length()
		if d < radius and d > 0.01:
			var pos := enemy.position + offset / d * distance * (1.0 - d / radius * 0.5)
			pos.x = clampf(pos.x, _arena.position.x, _arena.end.x)
			pos.y = clampf(pos.y, _arena.position.y, _arena.end.y)
			enemy.position = pos


## Centre of a crowded spot: the best of a few random enemies by neighbour count.
func densest_point(near: Vector2, max_range: float, crowd_radius: float) -> Vector2:
	var best := Vector2.INF
	var best_count := 0
	var found: Array = []
	for i in mini(10, active.size()):
		var enemy: Enemy = active[randi() % active.size()]
		if enemy.position.distance_to(near) > max_range:
			continue
		grid.query(enemy.position, crowd_radius, found)
		if found.size() > best_count:
			best_count = found.size()
			best = enemy.position
	return best


## Nearest active enemy inside a cone around dir (cos_half = cosine of the
## cone's half angle). Used for aim assist.
func nearest_in_cone(pos: Vector2, dir: Vector2, max_range: float, cos_half: float) -> Enemy:
	var best: Enemy = null
	var best_sq := max_range * max_range
	for enemy in active:
		var offset := enemy.position - pos
		var d_sq := offset.length_squared()
		if d_sq < best_sq and d_sq > 0.01 and offset.dot(dir) >= cos_half * sqrt(d_sq):
			best_sq = d_sq
			best = enemy
	return best


## Nearest active enemy to pos within max_range, skipping `exclude`.
func nearest_excluding(pos: Vector2, max_range: float, exclude: Array) -> Enemy:
	var best: Enemy = null
	var best_sq := max_range * max_range
	for enemy in active:
		var d_sq := pos.distance_squared_to(enemy.position)
		if d_sq < best_sq and not exclude.has(enemy):
			best_sq = d_sq
			best = enemy
	return best


func _kill(enemy: Enemy) -> void:
	enemy.active = false
	active.erase(enemy)
	_pool.release(enemy)
	_effects.burst(enemy.position, enemy.last_hit_dir, enemy.color, 7)
	Events.enemy_killed.emit(enemy.type_id, enemy.position, enemy.splat_radius, enemy.xp, enemy.last_hit_dir)


func _process(delta: float) -> void:
	if grid == null or not GameState.is_playing():
		return
	grid.clear()
	for enemy in active:
		grid.insert(enemy, enemy.position)

	var player_pos := _player.position
	var player_radius := _player.radius
	var push_factor := minf(1.0, SEPARATION_STRENGTH * delta)
	var min_x := _arena.position.x
	var max_x := _arena.end.x
	var min_y := _arena.position.y
	var max_y := _arena.end.y

	var ink_grid := _ink.grid

	# Caustic ink ticks four times a second. Victims are collected during the
	# loop and damaged after it, because a kill edits `active`.
	var slow := minf(Upgrades.bonus("ink_slow"), 0.8)
	var burn := Upgrades.bonus("ink_burn")
	var burn_tick := false
	if burn > 0.0:
		_burn_left -= delta
		if _burn_left <= 0.0:
			_burn_left = 0.25
			burn_tick = true

	for enemy in active:
		var pos := enemy.position
		var to_player := player_pos - pos
		var dist := to_player.length()
		var step := Vector2.ZERO
		if dist > 0.001:
			var pace := enemy.speed
			if slow > 0.0 and ink_grid.is_ink(pos):
				pace *= 1.0 - slow
			step = to_player / dist * pace * delta

		# Push away from overlapping neighbours so the horde does not stack.
		var push := Vector2.ZERO
		grid.query(pos, enemy.radius + max_radius, _scratch)
		for other: Enemy in _scratch:
			if other == enemy:
				continue
			var offset := pos - other.position
			var min_dist := enemy.radius + other.radius
			var d_sq := offset.length_squared()
			if d_sq < min_dist * min_dist and d_sq > 0.0001:
				var d := sqrt(d_sq)
				push += offset / d * (min_dist - d)

		pos += step + push * push_factor
		pos.x = clampf(pos.x, min_x, max_x)
		pos.y = clampf(pos.y, min_y, max_y)
		enemy.position = pos

		# Smudge trail, dropped at intervals so it reads as a dotted smear.
		enemy.trail_left -= delta
		if enemy.trail_left <= 0.0:
			enemy.trail_left = enemy.trail_interval
			# Most smudges slide over ink; only some bite through it.
			var protect := -1 if randf() < enemy.ink_cut_chance else InkGrid.INK
			ink_grid.paint_circle(pos, enemy.trail_radius, InkGrid.SMUDGE, protect)

		if dist < enemy.radius + player_radius:
			_player.take_damage(enemy.damage)
		if burn_tick and ink_grid.is_ink(pos):
			_burning.append(enemy)

	if burn_tick:
		for enemy in _burning:
			damage(enemy, burn * 0.25)
		_burning.clear()
