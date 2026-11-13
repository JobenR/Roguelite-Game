class_name SecondarySystem
extends Node2D
## Secondary weapon: a lobbed ink bomb fired with the "secondary" action.
## Recharges over time, and each kill shaves time off the cooldown.

var charge: float = 1.0  # 0..1

var _player: Player
var _enemies: EnemyManager
var _ink: InkSystem
var _effects: Effects
var _weapon: Dictionary = {}
var _flying: bool = false
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _t: float = 0.0

@onready var visual: Node2D = $Visual


func setup(player: Player, enemies: EnemyManager, ink: InkSystem, effects: Effects) -> void:
	_player = player
	_enemies = enemies
	_ink = ink
	_effects = effects
	var stats: Dictionary = DataDB.player.get("default", {})
	_weapon = DataDB.weapons.get(String(stats.get("secondary", "")), {})
	visual.setup(_weapon.get("visual", {}), float(_weapon.get("bullet_radius", 10.0)))
	visual.visible = false
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.secondary_charge_changed.emit(charge)


func _on_enemy_killed(_type_id: String, _pos: Vector2, _splat_radius: float, _xp: int, _dir: Vector2) -> void:
	_add_charge(float(_weapon.get("kill_recharge", 0.0)) / _cooldown())


func _cooldown() -> float:
	return maxf(0.1, float(_weapon.get("cooldown", 8.0)))


func _add_charge(amount: float) -> void:
	if charge >= 1.0:
		return
	charge = minf(1.0, charge + amount)
	Events.secondary_charge_changed.emit(charge)


func _process(delta: float) -> void:
	if _player == null or _weapon.is_empty() or not GameState.is_playing():
		return
	_add_charge(delta / _cooldown())
	if Input.is_action_just_pressed("secondary") and charge >= 1.0 and not _flying:
		_throw()
	if _flying:
		_t += delta / maxf(0.05, float(_weapon.get("flight_time", 0.45)))
		var t := minf(_t, 1.0)
		visual.position = _from.lerp(_to, t)
		var lob := 1.0 + sin(t * PI) * 0.8
		visual.scale = Vector2(lob, lob)
		if _t >= 1.0:
			_explode()


func _throw() -> void:
	var throw_range := float(_weapon.get("throw_range", 300.0))
	var target := _enemies.nearest(_player.position, throw_range)
	_from = _player.position
	_to = target.position if target != null else _player.position + _player.aim_dir * throw_range * 0.7
	_t = 0.0
	_flying = true
	visual.position = _from
	visual.visible = true
	charge = 0.0
	Events.secondary_charge_changed.emit(charge)


func _explode() -> void:
	_flying = false
	visual.visible = false
	var radius := float(_weapon.get("blast_radius", 100.0))
	# Paint first, then damage: kill splats land on top either way.
	_ink.splat(_to, float(_weapon.get("splat_radius", radius)) * 1.25, Vector2.ZERO)
	_enemies.damage_area(_to, radius, float(_weapon.get("damage", 30.0)))
	_effects.ring(_to, radius, Color(0.12, 0.23, 0.54, 0.9), 0.35)
	_effects.burst(_to, Vector2.ZERO, Color(0.15, 0.3, 0.8), 16)
	Events.screen_shake.emit(7.0)
