class_name SecondarySystem
extends Node2D
## Secondary weapon: a lobbed ink bomb fired with the "secondary" action.
## Recharges over time, and each kill shaves time off the cooldown. Bomb
## upgrades (ring, cluster, sticky, vacuum, burning, twin) resolve here.

var charge: float = 1.0  # 1.0 = one bomb ready; Twin Bombs allows up to 2.0

var _player: Player
var _enemies: EnemyManager
var _ink: InkSystem
var _effects: Effects
var _hazards: Hazards
var _weapon: Dictionary = {}
var _flying: bool = false
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _t: float = 0.0

@onready var visual: Node2D = $Visual


func setup(player: Player, enemies: EnemyManager, ink: InkSystem, effects: Effects, hazards: Hazards) -> void:
	_player = player
	_enemies = enemies
	_ink = ink
	_effects = effects
	_hazards = hazards
	var stats: Dictionary = DataDB.player.get("default", {})
	_weapon = DataDB.weapons.get(String(stats.get("secondary", "")), {})
	visual.setup(_weapon.get("visual", {}), float(_weapon.get("bullet_radius", 10.0)))
	visual.visible = false
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.secondary_charge_changed.emit(charge)


func _on_enemy_killed(_type_id: String, _pos: Vector2, _splat_radius: float, _xp: int, _dir: Vector2) -> void:
	_add_charge(float(_weapon.get("kill_recharge", 0.0)) / _cooldown())


func _cooldown() -> float:
	return maxf(0.1, float(_weapon.get("cooldown", 8.0)) / Upgrades.mult_of("bomb_rate"))


func _max_charge() -> float:
	return 1.0 + Upgrades.bonus("bomb_store")


func _add_charge(amount: float) -> void:
	if charge >= _max_charge():
		return
	charge = minf(_max_charge(), charge + amount)
	Events.secondary_charge_changed.emit(minf(charge, 1.0))


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
			_flying = false
			visual.visible = false
			_explode(_to, 1.0, true)
			# Cluster Bomb: smaller blasts scattered around the main one.
			var cluster := int(Upgrades.bonus("cluster"))
			if cluster > 0:
				var minis := int(DataDB.arsenal_num("cluster", "count", 2.0)) + cluster
				var spread := float(_weapon.get("blast_radius", 100.0)) * Upgrades.mult_of("bomb_size")
				for i in minis:
					var offset := Vector2.from_angle(TAU * i / minis + randf() * 0.5) * spread * randf_range(0.8, 1.2)
					_explode(_to + offset, DataDB.arsenal_num("cluster", "radius_scale", 0.6), false)


func _throw() -> void:
	var throw_range := float(_weapon.get("throw_range", 300.0))
	var target := _enemies.nearest(_player.position, throw_range)
	_from = _player.position
	_to = target.position if target != null else _player.position + _player.aim_dir * throw_range * 0.7
	_t = 0.0
	_flying = true
	visual.position = _from
	visual.visible = true
	charge -= 1.0
	Events.secondary_charge_changed.emit(minf(charge, 1.0))


func _explode(pos: Vector2, size: float, main: bool) -> void:
	var radius := float(_weapon.get("blast_radius", 100.0)) * Upgrades.mult_of("bomb_size") * size
	var bomb_damage := float(_weapon.get("damage", 30.0)) * Upgrades.mult_of("bomb_damage") * (1.0 + GameState.damage_bonus)
	if not main:
		bomb_damage *= DataDB.arsenal_num("cluster", "damage_scale", 0.5)

	# Vacuum Bomb: drag the crowd in first, so the blast catches more.
	var vacuum := Upgrades.bonus("vacuum")
	if vacuum > 0.0 and main:
		var drag := DataDB.arsenal_num("vacuum", "distance", 90.0) + DataDB.arsenal_num("vacuum", "distance_per_level", 50.0) * (vacuum - 1.0)
		_enemies.pull(pos, radius * 2.2, drag)

	# Paint first, then damage: kill splats land on top either way.
	var ring_level := int(Upgrades.bonus("ring_bomb"))
	if ring_level > 0 and main:
		# Ring Bomb: a closed circle of ink, ready for a pulse.
		var ring := (float(_weapon.get("ring_radius", 120.0)) + float(_weapon.get("ring_radius_per_level", 25.0)) * (ring_level - 1)) * Upgrades.mult_of("bomb_size")
		var thickness := float(_weapon.get("ring_thickness", 7.0))
		var steps := int(ceil(TAU * ring / 6.0))
		for i in steps:
			_ink.grid.paint_circle(pos + Vector2.from_angle(TAU * i / steps) * ring, thickness, InkGrid.INK)
		_effects.ring(pos, ring, Color(0.22, 0.45, 0.95, 0.9), 0.4)
	else:
		_ink.splat(pos, float(_weapon.get("splat_radius", radius)) * Upgrades.mult_of("bomb_size") * size * 1.25, Vector2.ZERO)

	var slow := Upgrades.bonus("bomb_slow")
	if slow > 0.0:
		_enemies.slow_area(pos, radius, slow + 0.2, DataDB.arsenal_num("sticky_bomb", "seconds", 4.0))
	_enemies.damage_area(pos, radius, bomb_damage)
	var napalm := Upgrades.bonus("napalm")
	if napalm > 0.0:
		_hazards.add_burn(pos, radius, napalm, DataDB.arsenal_num("napalm", "seconds", 5.0), Color(0.98, 0.45, 0.1))
	_effects.ring(pos, radius, Color(0.12, 0.23, 0.54, 0.9), 0.35)
	_effects.burst(pos, Vector2.ZERO, Color(0.15, 0.3, 0.8), 16 if main else 6)
	if main:
		Events.screen_shake.emit(7.0)
