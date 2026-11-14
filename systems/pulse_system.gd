class_name PulseSystem
extends Node
## The pulse: charged by kills and XP, fired with the "pulse" action. It floods
## every shape fully enclosed by the player's ink within reach, damages enemies
## caught inside, and hands the filled shapes to the glyph system. With no
## closed shape in reach it fizzles and keeps its charge.

var charge: float = 0.0  # 1.0 = one pulse ready; Double Pulse allows up to 2.0

var _player: Player
var _enemies: EnemyManager
var _ink: InkSystem
var _effects: Effects
var _glyphs: GlyphSystem
var _hazards: Hazards
var _cfg: Dictionary = {}


func setup(player: Player, enemies: EnemyManager, ink: InkSystem, effects: Effects, glyphs: GlyphSystem, hazards: Hazards) -> void:
	_glyphs = glyphs
	_hazards = hazards
	_player = player
	_enemies = enemies
	_ink = ink
	_effects = effects
	var stats: Dictionary = DataDB.player.get("default", {})
	_cfg = DataDB.pulses.get(String(stats.get("pulse", "")), {})
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.xp_collected.connect(func(amount: int) -> void: _add_charge(amount * float(_cfg.get("charge_per_xp", 0.0)) / 100.0))
	Events.pulse_charge_changed.emit(charge)


func _on_enemy_killed(_type_id: String, _pos: Vector2, _splat_radius: float, _xp: int, _dir: Vector2) -> void:
	_add_charge(float(_cfg.get("charge_per_kill", 5.0)) / 100.0)


func _max_charge() -> float:
	return 1.0 + Upgrades.bonus("pulse_store")


func fill_charge() -> void:
	charge = maxf(charge, 1.0)
	Events.pulse_charge_changed.emit(minf(charge, 1.0))


func _add_charge(amount: float) -> void:
	if charge >= _max_charge():
		return
	charge = minf(_max_charge(), charge + amount * Upgrades.mult_of("pulse_charge"))
	Events.pulse_charge_changed.emit(minf(charge, 1.0))


func _process(_delta: float) -> void:
	if _player == null or not GameState.is_playing():
		return
	if Input.is_action_just_pressed("pulse") and charge >= 1.0:
		fire()


## Returns the number of cells filled (0 = nothing enclosed).
func fire() -> int:
	var center := _player.position
	var radius := Upgrades.value("pulse_radius", float(_cfg.get("radius", 320.0)))
	var grid := _ink.grid
	var enclosed := grid.find_enclosed(center, radius, int(Upgrades.bonus("pulse_gap")))
	var shock := Upgrades.bonus("shockwave")
	if enclosed.is_empty() and Upgrades.bonus("mending") > 0.0:
		# Mending Pulse: patch small breaks in the trail, then look again.
		grid.close_gaps(center, radius, 4)
		enclosed = grid.find_enclosed(center, radius, int(Upgrades.bonus("pulse_gap")))
	if enclosed.is_empty() and shock <= 0.0:
		# Nothing to fill and no Shockwave: fizzle and keep the charge.
		_effects.ring(center, radius * 0.4, Color(0.85, 0.2, 0.2, 0.8), 0.25)
		Events.pulse_fired.emit(0)
		return 0

	if shock > 0.0:
		# Shockwave: blast and shove everything in reach, loop or not.
		_enemies.damage_area(center, radius, shock)
		_enemies.knockback(center, radius, float(_cfg.get("shockwave_knockback", 70.0)))

	var refund := 0.0
	if not enclosed.is_empty():
		# Weaker pulses fill only part of what they enclose, nearest cells first.
		var fill := clampf(float(_cfg.get("fill", 1.0)), 0.0, 1.0)
		if fill < 1.0:
			var ordered: Array = Array(enclosed)
			ordered.sort_custom(func(a: int, b: int) -> bool:
				return grid.cell_center(a).distance_squared_to(center) < grid.cell_center(b).distance_squared_to(center))
			ordered.resize(maxi(1, int(ordered.size() * fill)))
			grid.mask.fill(0)
			enclosed = PackedInt32Array(ordered)
			for index in enclosed:
				grid.mask[index] = 1

		var pulse_damage := float(_cfg.get("damage", 0.0))
		if pulse_damage > 0.0:
			for enemy: Enemy in _enemies.active.duplicate():
				if grid.mask[grid.cell_index(enemy.position)] == 1:
					_enemies.damage(enemy, pulse_damage)
		# Permanent Marker: pulse-filled ink can never be smudged.
		var fill_state := InkGrid.LOCKED if Upgrades.bonus("permanent_marker") > 0.0 else InkGrid.INK
		for index in enclosed:
			grid.set_cell(index, fill_state)
		_player.heal(Upgrades.bonus("pulse_heal"))
		_reward_fill(enclosed)
		refund = Upgrades.bonus("pulse_refund")
		# Read the filled shapes: a circle, triangle or square is a glyph.
		_glyphs.resolve(enclosed)

	charge = clampf(charge - 1.0 + refund, 0.0, _max_charge())
	Events.pulse_charge_changed.emit(minf(charge, 1.0))
	Events.pulse_fired.emit(enclosed.size())
	_effects.ring(center, radius, Color(0.22, 0.45, 0.95, 0.9), 0.45)
	_effects.ring(center, radius * 0.6, Color(0.6, 0.78, 1.0, 0.8), 0.35)
	if not enclosed.is_empty():
		_effects.big_moment(center, radius * 0.55, Color(0.24, 0.52, 1.0), 0.7)
	Events.screen_shake.emit(5.0)
	return enclosed.size()


## Upgrades that pay out for a successful fill.
func _reward_fill(enclosed: PackedInt32Array) -> void:
	var grid := _ink.grid
	var harvest := Upgrades.bonus("harvest")
	if harvest > 0.0:
		GameState.add_xp(int(ceil(enclosed.size() * harvest / DataDB.arsenal_num("harvest", "cells_per_xp", 220.0))))
	var shield := Upgrades.bonus("pulse_shield")
	if shield > 0.0:
		_player.grant_invulnerability(shield)
	if Upgrades.bonus("loop_fury") > 0.0 and enclosed.size() >= int(DataDB.arsenal_num("loop_fury", "min_cells", 500.0)):
		GameState.grant_power("loop_fury", DataDB.arsenal_num("loop_fury", "seconds", 10.0))
	var burn := Upgrades.bonus("aftershock")
	if burn > 0.0:
		# Aftershock: burn a circle that covers the filled area.
		var middle := Vector2.ZERO
		for index in enclosed:
			middle += grid.cell_center(index)
		middle /= enclosed.size()
		var reach := 0.0
		for i in range(0, enclosed.size(), 8):
			reach = maxf(reach, middle.distance_to(grid.cell_center(enclosed[i])))
		_hazards.add_burn(middle, reach, burn, DataDB.arsenal_num("aftershock", "seconds", 3.0), Color(0.3, 0.55, 1.0))
