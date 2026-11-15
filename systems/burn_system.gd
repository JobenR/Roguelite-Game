class_name BurnSystem
extends Node2D
## Burning Page mode: the page burns inward one strip at a time. When a strip
## burns, the player's ink in it survives as permanent, walkable ground and
## everything else becomes burnt paper that nobody can cross. Each strip pays
## out by the share of it the player owned. Numbers: "burn" in modes.json.

var strips_burned: int = 0

var _player: Player
var _enemies: EnemyManager
var _ink: InkSystem
var _effects: Effects
var _flow: FlowField
var _cfg: Dictionary = {}
var _timer: float = 0.0
var _warned: bool = false
var _burning: PackedInt32Array = PackedInt32Array()  # cells of the strip on fire
var _burn_cursor: int = 0
var _owned: int = 0
var _flow_left: float = 0.0
var _finished: bool = false


func setup(player: Player, enemies: EnemyManager, ink: InkSystem, effects: Effects, flow: FlowField, cfg: Dictionary) -> void:
	_player = player
	_enemies = enemies
	_ink = ink
	_effects = effects
	_flow = flow
	_cfg = cfg
	_timer = float(cfg.get("first", 45.0))


func _strip() -> int:
	return int(_cfg.get("strip_cells", 12))


## The part of the page that has not burnt, in world units.
func inner_rect() -> Rect2:
	var grid := _ink.grid
	var inset := strips_burned * _strip() * grid.cell_size
	return Rect2(inset, inset, grid.cols * grid.cell_size - inset * 2.0, grid.rows * grid.cell_size - inset * 2.0)


## Seconds until the next strip burns, or -1 when the page will burn no more.
func time_to_burn() -> float:
	return -1.0 if _finished else _timer


func _process(delta: float) -> void:
	if _player == null or not GameState.is_playing():
		return
	var grid := _ink.grid
	if not _burning.is_empty():
		_advance_fire()
	elif not _finished:
		_timer -= delta
		var warning := float(_cfg.get("warning", 8.0))
		if not _warned and _timer <= warning:
			_warned = true
			Events.alert.emit("THE PAGE BURNS", warning)
		if _timer <= 0.0:
			_ignite()

	if grid.dead_count > 0:
		# Standing on burnt paper hurts; the horde is rerouted around it.
		if grid.is_dead(_player.position):
			_player.take_damage(float(_cfg.get("burn_damage", 14.0)))
		_flow_left -= delta
		if _flow_left <= 0.0:
			_flow_left = 0.5
			_flow.rebuild(grid, _player.position)
	queue_redraw()


## Collects the cells of the next strip as nested rings, outermost first, so
## the fire eats inward.
func _ignite() -> void:
	var grid := _ink.grid
	var lo := strips_burned * _strip()
	_burning = PackedInt32Array()
	for depth in _strip():
		var x0 := lo + depth
		var x1 := grid.cols - 1 - lo - depth
		var y0 := lo + depth
		var y1 := grid.rows - 1 - lo - depth
		if x0 > x1 or y0 > y1:
			break
		for x in range(x0, x1 + 1):
			_burning.append(y0 * grid.cols + x)
			if y1 != y0:
				_burning.append(y1 * grid.cols + x)
		for y in range(y0 + 1, y1):
			_burning.append(y * grid.cols + x0)
			if x1 != x0:
				_burning.append(y * grid.cols + x1)
	_burn_cursor = 0
	_owned = 0
	Events.screen_shake.emit(6.0)


## Burns part of the strip each frame, so the fire visibly eats inward.
func _advance_fire() -> void:
	var grid := _ink.grid
	var chunk := maxi(200, _burning.size() / 70)
	var end := mini(_burn_cursor + chunk, _burning.size())
	for i in range(_burn_cursor, end):
		if grid.burn_cell(_burning[i]):
			_owned += 1
	_burn_cursor = end
	if _burn_cursor >= _burning.size():
		_finish_strip()


func _finish_strip() -> void:
	var grid := _ink.grid
	var share := float(_owned) / maxf(1.0, float(_burning.size()))
	_burning = PackedInt32Array()
	strips_burned += 1
	_warned = false
	_timer = float(_cfg.get("interval", 40.0))
	# Stop when the page is as small as it is allowed to get.
	var next_inner := mini(grid.cols, grid.rows) - (strips_burned + 1) * _strip() * 2
	if next_inner < int(_cfg.get("min_inner_cells", 70)):
		_finished = true

	# Anything caught on burnt paper is destroyed.
	for enemy: Enemy in _enemies.active.duplicate():
		if grid.is_dead(enemy.position) and not enemy.is_boss:
			_enemies.damage(enemy, 999999.0)
	_flow.rebuild(grid, _player.position)

	# The payout: the more of the strip was yours, the more you get.
	var xp := int(round(float(_cfg.get("xp_per_strip", 30.0)) * strips_burned * share))
	GameState.add_xp(xp)
	_player.heal(float(_cfg.get("heal", 12.0)) * share)
	var perfect := share >= float(_cfg.get("perfect_share", 0.9))
	if perfect:
		Events.bonus_card.emit("STRIP SAVED: BONUS UPGRADE")
	Events.strip_burned.emit(strips_burned, share, xp, perfect)


func _draw() -> void:
	if _ink == null:
		return
	var inner := inner_rect()
	var flicker := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
	if strips_burned > 0 or not _burning.is_empty():
		# The burning edge of the page.
		draw_rect(inner, Color(1.0, 0.45, 0.1, 0.5 * flicker), false, 8.0)
		draw_rect(inner, Color(1.0, 0.85, 0.4, 0.8 * flicker), false, 2.5)
	if _warned and _burning.is_empty() and not _finished:
		# The strip about to burn: a pulsing ember wash over it.
		var width := _strip() * _ink.grid.cell_size
		var urgency := 1.0 - clampf(_timer / float(_cfg.get("warning", 8.0)), 0.0, 1.0)
		var wash := Color(1.0, 0.4, 0.1, (0.1 + 0.22 * urgency) * flicker)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, width)), wash)
		draw_rect(Rect2(inner.position + Vector2(0.0, inner.size.y - width), Vector2(inner.size.x, width)), wash)
		draw_rect(Rect2(inner.position + Vector2(0.0, width), Vector2(width, inner.size.y - width * 2.0)), wash)
		draw_rect(Rect2(inner.position + Vector2(inner.size.x - width, width), Vector2(width, inner.size.y - width * 2.0)), wash)
		draw_rect(inner.grow(-width), Color(1.0, 0.5, 0.15, 0.7 * flicker), false, 4.0)
