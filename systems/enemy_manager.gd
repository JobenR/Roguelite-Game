class_name EnemyManager
extends Node2D
## Owns every enemy: pooling, movement, abilities, separation, contact damage,
## death. One loop per frame over a flat array; collisions use the spatial grid.
##
## Behaviours (set per type in enemies.json):
##   chase  - walk at the player.
##   charge - walk, then stop, wind up, and lunge in a straight line (Brute).
##   ranged - hold a distance, strafe, and spit smudge globs (Spitter).
##   boss   - walk, erase ink around itself, and slam the ground (The Eraser).

const ENEMY_SCENE := preload("res://entities/enemies/enemy.tscn")
const GRID_CELL := 64.0
const SEPARATION_STRENGTH := 8.0

var active: Array[Enemy] = []
var grid: SpatialGrid
var max_radius: float = 0.0
var boss: Enemy = null
var heavy_count: int = 0
## Set by Burning Page mode: routes enemies around burnt paper.
var flow: FlowField = null

var _pool: ObjectPool
var _player: Player
var _ink: InkSystem
var _effects: Effects
var _shots: EnemyShots
var _burn_left: float = 0.0
var _burning: Array[Enemy] = []
var _bleeding: Array[Enemy] = []
var _thorned: Array[Enemy] = []
var _stepped: Array[Enemy] = []
var _arena: Rect2
var _scratch: Array = []


func setup(player: Player, arena: Rect2, ink: InkSystem, effects: Effects, shots: EnemyShots) -> void:
	_effects = effects
	_shots = shots
	_player = player
	_ink = ink
	_arena = arena
	grid = SpatialGrid.new(arena.size, GRID_CELL)
	_pool = ObjectPool.new(ENEMY_SCENE, self, 64)
	Events.heavy_presence.emit(0)


func spawn(type_id: String, pos: Vector2, hp_mult: float = 1.0) -> Enemy:
	var data: Dictionary = DataDB.enemies.get(type_id, {})
	if data.is_empty():
		push_error("EnemyManager: unknown enemy type '%s'" % type_id)
		return null
	var enemy: Enemy = _pool.acquire()
	enemy.spawn(type_id, data, pos, hp_mult)
	active.append(enemy)
	max_radius = maxf(max_radius, enemy.radius)
	if enemy.heavy:
		heavy_count += 1
		Events.heavy_presence.emit(heavy_count)
	if enemy.is_boss:
		boss = enemy
		Events.boss_spawned.emit(enemy.display_name)
		Events.boss_health_changed.emit(1.0)
	return enemy


## dir is the direction the blow travels; it shapes the kill splat.
func damage(enemy: Enemy, amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	if not enemy.active:
		return
	enemy.last_hit_dir = dir
	if enemy.stain_left > 0.0:
		amount *= 1.0 + enemy.stain_amount
	enemy.hp -= amount
	# Executioner: finish off anything nearly dead (bosses excepted).
	if not enemy.is_boss and enemy.hp > 0.0 and enemy.hp < enemy.max_hp * Upgrades.bonus("execute"):
		enemy.hp = 0.0
	if enemy.is_boss:
		Events.boss_health_changed.emit(clampf(enemy.hp / enemy.max_hp, 0.0, 1.0))
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


## Damages every enemy within `width` of the segment (beams, spikes).
func damage_segment(from: Vector2, to: Vector2, width: float, amount: float) -> void:
	var dir := (to - from).normalized()
	# Copy the list: a kill removes from `active` while we loop.
	for enemy: Enemy in active.duplicate():
		var closest := Geometry2D.get_closest_point_to_segment(enemy.position, from, to)
		var reach := width + enemy.radius
		if closest.distance_squared_to(enemy.position) <= reach * reach:
			damage(enemy, amount, dir)


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


func apply_slow(enemy: Enemy, amount: float, seconds: float) -> void:
	if enemy.heavy:
		amount *= 0.4
	enemy.slow_amount = maxf(enemy.slow_amount if enemy.slow_left > 0.0 else 0.0, minf(amount, 0.85))
	enemy.slow_left = maxf(enemy.slow_left, seconds)


func slow_area(pos: Vector2, radius: float, amount: float, seconds: float) -> void:
	var found: Array = []
	grid.query(pos, radius + max_radius, found)
	for enemy: Enemy in found:
		if enemy.active and pos.distance_to(enemy.position) <= radius + enemy.radius:
			apply_slow(enemy, amount, seconds)


## Drags enemies inside the circle toward its centre. Heavy enemies resist.
func pull(center: Vector2, radius: float, distance: float) -> void:
	for enemy in active:
		if enemy.heavy:
			continue
		var offset := center - enemy.position
		var d := offset.length()
		if d < radius and d > 6.0:
			enemy.position += offset / d * minf(distance, d - 4.0)


## Pushes enemies inside the circle away from its centre. Heavy enemies resist.
func knockback(center: Vector2, radius: float, distance: float) -> void:
	for enemy in active:
		if enemy.heavy:
			continue
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
	_effects.burst(enemy.position, enemy.last_hit_dir, enemy.color, 14 if enemy.heavy else 7)
	if enemy.heavy:
		heavy_count = maxi(0, heavy_count - 1)
		Events.heavy_presence.emit(heavy_count)
	if enemy.is_boss:
		boss = null
		_effects.big_moment(enemy.position, enemy.splat_radius * 1.5, Color(String(enemy.data.get("visual", {}).get("core", "#ffffff"))), 0.9)
		Events.screen_shake.emit(14.0)
		Events.boss_defeated.emit(enemy.display_name)
		if bool(enemy.data.get("final", false)):
			Events.final_boss_defeated.emit()
		queue_redraw()
	Events.enemy_killed.emit(enemy.type_id, enemy.position, enemy.splat_radius, enemy.xp, enemy.last_hit_dir)
	# Splitters break into smaller enemies.
	var split_into := String(enemy.data.get("split_into", ""))
	if split_into != "":
		for i in int(enemy.data.get("split_count", 2)):
			var offset := Vector2.from_angle(randf() * TAU) * enemy.radius
			spawn(split_into, enemy.position + offset, enemy.max_hp / maxf(1.0, float(enemy.data.get("hp", 1.0))))


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
	_burn_left -= delta
	if _burn_left <= 0.0:
		_burn_left = 0.25
		burn_tick = true
	var frozen := GameState.has_power("freeze")
	var thorn_ink := Upgrades.bonus("thorn_ink")
	var thorns := Upgrades.bonus("thorns")
	var cut_scale := 1.0 - minf(Upgrades.bonus("ink_tough"), 0.75)
	var weave_time := GameState.run_time * 1.7
	var walls := Upgrades.bonus("ink_wall") > 0.0
	var now := GameState.run_time
	var burnt := ink_grid.dead_count > 0
	var use_flow := burnt and flow != null and flow.ready

	var bound_pull := DataDB.arsenal_num("lasso", "pull_speed", 520.0) * delta

	for enemy in active:
		var pos := enemy.position
		if enemy.bound_left > 0.0:
			# Lassoed: dragged into the knot, jostling, unable to chase or bite.
			enemy.bound_left -= delta
			var to_knot := enemy.bound_center - pos
			var far := to_knot.length()
			if far > enemy.bound_radius:
				pos += to_knot / far * minf(bound_pull, far - enemy.bound_radius)
			else:
				pos += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 40.0 * delta
			enemy.position = pos
			if burn_tick:
				if burn > 0.0 and ink_grid.is_ink(pos):
					_burning.append(enemy)
				if enemy.bleed_left > 0.0:
					enemy.bleed_left -= 0.25
					_bleeding.append(enemy)
			continue
		var to_player := player_pos - pos
		var dist := to_player.length()
		var toward := to_player / dist if dist > 0.001 else Vector2.ZERO
		if use_flow and dist > 110.0:
			# Follow the route round burnt paper until the player is close.
			var route := flow.direction(pos)
			if route != Vector2.ZERO:
				toward = route
		var pace := enemy.speed
		if slow > 0.0 and not enemy.heavy and ink_grid.is_ink(pos):
			pace *= 1.0 - slow
		if enemy.slow_left > 0.0:
			enemy.slow_left -= delta
			pace *= 1.0 - enemy.slow_amount
		if enemy.stain_left > 0.0:
			enemy.stain_left -= delta

		var step := Vector2.ZERO
		match (-1 if frozen else int(enemy.behavior)):
			Enemy.Behavior.CHASE:
				# Curve in from this enemy's own side (fading out up close) and
				# weave, so the horde fans out and surrounds instead of queueing.
				var bend := enemy.flank * clampf((dist - 90.0) / 260.0, 0.0, 1.0) + sin(weave_time + enemy.weave_phase) * 0.22
				step = toward.rotated(bend) * pace * delta
			Enemy.Behavior.CHARGE:
				step = _charge_step(enemy, toward, dist, pace, delta)
			Enemy.Behavior.RANGED:
				step = _ranged_step(enemy, toward, dist, pace, delta)
			Enemy.Behavior.BOSS:
				step = _boss_step(enemy, toward, dist, pace, delta)

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
		if enemy.heavy:
			push *= 0.15

		var move := step + push * push_factor
		var check_walls := walls and not enemy.heavy
		if (check_walls or burnt) and move != Vector2.ZERO:
			# Wet Ink Wall and burnt paper: a blocked enemy slides along the
			# obstacle instead of pushing through it.
			var feeler := move.normalized() * enemy.radius * 0.7
			if _blocked(ink_grid, pos + move + feeler, check_walls, now):
				if absf(move.x) > 0.01 and not _blocked(ink_grid, pos + Vector2(move.x + feeler.x, 0.0), check_walls, now):
					move = Vector2(signf(move.x) * move.length(), 0.0)
				elif absf(move.y) > 0.01 and not _blocked(ink_grid, pos + Vector2(0.0, move.y + feeler.y), check_walls, now):
					move = Vector2(0.0, signf(move.y) * move.length())
				else:
					# Fully blocked: shuffle sideways to find a way around.
					move = toward.orthogonal() * (1.0 if enemy.flank >= 0.0 else -1.0) * move.length()
					if _blocked(ink_grid, pos + move + move.normalized() * enemy.radius * 0.7, check_walls, now):
						move = Vector2.ZERO
		pos += move
		pos.x = clampf(pos.x, min_x, max_x)
		pos.y = clampf(pos.y, min_y, max_y)
		enemy.position = pos
		if enemy.face_move and step != Vector2.ZERO:
			enemy.visual.rotation = step.angle()

		# Smudge trail, dropped at intervals so it reads as a dotted smear.
		enemy.trail_left -= delta
		if enemy.trail_left <= 0.0:
			enemy.trail_left = enemy.trail_interval
			# Most smudges slide over ink; only some bite through it.
			var protect := -1 if randf() < enemy.ink_cut_chance * cut_scale else InkGrid.INK
			ink_grid.paint_circle(pos, enemy.trail_radius, InkGrid.SMUDGE, protect)

		if dist < enemy.radius + player_radius and not frozen:
			if _player.take_damage(enemy.damage) and thorns > 0.0:
				_thorned.append(enemy)
		if burn_tick:
			if burn > 0.0 and ink_grid.is_ink(pos):
				_burning.append(enemy)
			if enemy.bleed_left > 0.0:
				enemy.bleed_left -= 0.25
				_bleeding.append(enemy)
		if thorn_ink > 0.0:
			var on_ink := ink_grid.is_ink(pos)
			if on_ink and not enemy.was_on_ink:
				_stepped.append(enemy)
			enemy.was_on_ink = on_ink

	# Damage collected during the loop is applied here, because a kill edits
	# `active`.
	for enemy in _burning:
		damage(enemy, burn * 0.25)
	_burning.clear()
	for enemy in _bleeding:
		damage(enemy, enemy.bleed_dps * 0.25)
	_bleeding.clear()
	for enemy in _thorned:
		damage(enemy, thorns)
	_thorned.clear()
	for enemy in _stepped:
		damage(enemy, thorn_ink)
	_stepped.clear()
	if boss != null:
		queue_redraw()


func _blocked(ink_grid: InkGrid, at: Vector2, check_walls: bool, now: float) -> bool:
	return ink_grid.is_dead(at) or (check_walls and ink_grid.is_wall(at, now))


## Brute: walk in, stop and shake, then lunge in a straight line.
func _charge_step(enemy: Enemy, toward: Vector2, dist: float, pace: float, delta: float) -> Vector2:
	var cfg := enemy.data
	enemy.ability_left -= delta
	match enemy.ability_state:
		0:
			if enemy.ability_left <= 0.0 and dist < float(cfg.get("charge_range", 450.0)):
				enemy.ability_state = 1
				enemy.ability_left = float(cfg.get("charge_windup", 0.7))
			return toward * pace * delta
		1:
			# Wind-up: flicker as a warning, and lock the direction at the end.
			enemy.aux_left -= delta
			if enemy.aux_left <= 0.0:
				enemy.aux_left = 0.14
				enemy.visual.flash()
			if enemy.ability_left <= 0.0:
				enemy.ability_state = 2
				enemy.ability_left = float(cfg.get("charge_time", 0.55))
				enemy.ability_dir = toward
			return Vector2.ZERO
		_:
			if enemy.ability_left <= 0.0:
				enemy.ability_state = 0
				enemy.ability_left = float(cfg.get("charge_cooldown", 5.0))
			return enemy.ability_dir * float(cfg.get("charge_speed", 340.0)) * delta


## Spitter: keep a set distance, circle the player, and spit on a timer.
func _ranged_step(enemy: Enemy, toward: Vector2, dist: float, pace: float, delta: float) -> Vector2:
	var cfg := enemy.data
	var keep := float(cfg.get("keep_distance", 320.0))
	enemy.ability_left -= delta
	if enemy.ability_left <= 0.0 and dist < keep * 1.6:
		enemy.ability_left = float(cfg.get("shot_interval", 2.5))
		enemy.visual.flash()
		_shots.fire(enemy.position + toward * enemy.radius, toward, cfg)
	if dist > keep * 1.15:
		return toward * pace * delta
	if dist < keep * 0.85:
		return -toward * pace * 0.7 * delta
	return toward.orthogonal() * pace * 0.5 * delta


## The Eraser: rubs out ink around itself and slams the ground on a timer.
func _boss_step(enemy: Enemy, toward: Vector2, dist: float, pace: float, delta: float) -> Vector2:
	var cfg := enemy.data
	enemy.aux_left -= delta
	if enemy.aux_left <= 0.0:
		enemy.aux_left = 0.2
		_ink.grid.paint_circle(enemy.position, float(cfg.get("erase_radius", 120.0)), InkGrid.SMUDGE)
	enemy.ability_left -= delta
	if enemy.ability_state == 0:
		if enemy.ability_left <= 0.0 and dist < float(cfg.get("slam_radius", 210.0)) * 1.3:
			enemy.ability_state = 1
			enemy.ability_left = float(cfg.get("slam_windup", 1.1))
		return toward * pace * delta
	# Winding up: stand still; the warning circle is drawn in _draw.
	if enemy.ability_left <= 0.0:
		var slam_radius := float(cfg.get("slam_radius", 210.0))
		if dist < slam_radius + _player.radius:
			_player.take_damage(float(cfg.get("slam_damage", 28.0)))
		_ink.grid.paint_circle(enemy.position, slam_radius, InkGrid.SMUDGE)
		_effects.ring(enemy.position, slam_radius, Color(0.75, 0.15, 0.3, 0.95), 0.4)
		Events.screen_shake.emit(12.0)
		enemy.ability_state = 0
		enemy.ability_left = float(cfg.get("slam_cooldown", 6.0))
	return Vector2.ZERO


## Boss telegraphs: the eraser's reach, and the slam warning as it fills in.
func _draw() -> void:
	if boss == null or not boss.active:
		return
	var cfg := boss.data
	draw_arc(boss.position, float(cfg.get("erase_radius", 120.0)), 0.0, TAU, 48, Color(0.96, 0.45, 0.71, 0.35), 3.0)
	if boss.ability_state == 1:
		var slam_radius := float(cfg.get("slam_radius", 210.0))
		var progress := 1.0 - clampf(boss.ability_left / float(cfg.get("slam_windup", 1.1)), 0.0, 1.0)
		draw_circle(boss.position, slam_radius, Color(0.85, 0.1, 0.2, 0.12))
		draw_circle(boss.position, slam_radius * progress, Color(0.85, 0.1, 0.2, 0.22))
		draw_arc(boss.position, slam_radius, 0.0, TAU, 64, Color(0.85, 0.1, 0.2, 0.9), 5.0)
