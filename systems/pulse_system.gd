class_name PulseSystem
extends Node
## The Ultimate ("Deluge"), fired with the "pulse" action once it is charged
## by kills and XP. A wave of ink bursts from the player: it damages and
## throws back everything in reach and floods the ground around the player
## with glowing ink. It takes a long time to charge and always does something.
##
## (This replaced the old loop-filling pulse and glyphs, which the player
## rarely used under pressure. The action and class keep the name "pulse".)

var charge: float = 0.0  # 1.0 = ready; Double Pulse allows up to 2.0

var _player: Player
var _enemies: EnemyManager
var _ink: InkSystem
var _effects: Effects
var _hazards: Hazards
var _cfg: Dictionary = {}


func setup(player: Player, enemies: EnemyManager, ink: InkSystem, effects: Effects, hazards: Hazards) -> void:
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
	# Burning Page: saving a good share of a strip charges the Ultimate.
	Events.strip_burned.connect(func(_i: int, share: float, _x: int, _p: bool) -> void:
		if share >= float(DataDB.modes.get(GameState.mode_id, {}).get("burn", {}).get("pulse_share", 0.35)):
			fill_charge())


func _on_enemy_killed(_type_id: String, _pos: Vector2, _splat_radius: float, _xp: int, _dir: Vector2) -> void:
	_add_charge(float(_cfg.get("charge_per_kill", 1.5)) / 100.0)


func _max_charge() -> float:
	return 1.0 + Upgrades.bonus("pulse_store")


func fill_charge() -> void:
	charge = maxf(charge, 1.0)
	Events.pulse_charge_changed.emit(minf(charge, 1.0))


func _add_charge(amount: float) -> void:
	if charge >= _max_charge():
		return
	var was_ready := charge >= 1.0
	charge = minf(_max_charge(), charge + amount * Upgrades.mult_of("pulse_charge"))
	Events.pulse_charge_changed.emit(minf(charge, 1.0))
	if charge >= 1.0 and not was_ready:
		Events.ultimate_ready.emit()


func _process(_delta: float) -> void:
	if _player == null or not GameState.is_playing():
		return
	if Input.is_action_just_pressed("pulse") and charge >= 1.0:
		fire()


## Releases the wave. Returns the number of ground cells flooded.
func fire() -> int:
	var center := _player.position
	var radius := Upgrades.value("pulse_radius", float(_cfg.get("radius", 420.0)))
	var wave := radius * float(_cfg.get("wave_scale", 1.45))
	var grid := _ink.grid

	# The blast: everything inside the wave is hit and thrown outward.
	var blast := (float(_cfg.get("damage", 110.0)) + Upgrades.bonus("shockwave")) * Upgrades.mult_of("damage") * (1.0 + GameState.damage_bonus)
	_enemies.damage_area(center, wave, blast)
	_enemies.knockback(center, wave, float(_cfg.get("knockback", 150.0)))

	# The flood: a disc of glowing ink (permanent with Permanent Marker).
	var state := InkGrid.LOCKED if Upgrades.bonus("permanent_marker") > 0.0 else InkGrid.INK
	var flooded := grid.flood_disc(center, radius, state)

	_player.heal(Upgrades.bonus("pulse_heal"))
	var harvest := Upgrades.bonus("harvest")
	if harvest > 0.0:
		GameState.add_xp(int(ceil(flooded * harvest / DataDB.arsenal_num("harvest", "cells_per_xp", 220.0))))
	var shield := Upgrades.bonus("pulse_shield")
	if shield > 0.0:
		_player.grant_invulnerability(shield)
	if Upgrades.bonus("loop_fury") > 0.0:
		GameState.grant_power("loop_fury", DataDB.arsenal_num("loop_fury", "seconds", 10.0))
	var burn := Upgrades.bonus("aftershock")
	if burn > 0.0:
		_hazards.add_burn(center, radius, burn, DataDB.arsenal_num("aftershock", "seconds", 3.0), GameState.ink_light)

	charge = clampf(charge - 1.0 + Upgrades.bonus("pulse_refund"), 0.0, _max_charge())
	Events.pulse_charge_changed.emit(minf(charge, 1.0))
	Events.pulse_fired.emit(flooded)
	_effects.big_moment(center, wave, GameState.ink_light, 0.9)
	_effects.ink_burst(center, radius, 0.7)
	_effects.ring(center, wave, Color(GameState.ink_light, 0.95), 0.6)
	Events.screen_shake.emit(14.0)
	return flooded
