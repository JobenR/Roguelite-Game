class_name Player
extends Node2D
## Player: moves and aims from InputMap actions and fires the main weapon
## while "fire" is held. Aim order: the Auto-Aim power (nearest enemy), then
## the aim stick, then the direction of travel.

const AIM_DEADZONE := 0.25

var radius: float = 14.0
var speed: float = 230.0
var max_hp: float = 100.0
var hp: float = 100.0
var invuln_time: float = 0.6
var weapon: Dictionary = {}
var aim_dir: Vector2 = Vector2.RIGHT

var _enemies: EnemyManager
var _bullets: BulletManager
var _arena: Rect2
var _ink: InkSystem
var _trail_radius: float = 6.0
var _ink_speed_bonus: float = 0.0
var _last_trail_pos: Vector2 = Vector2.INF
var _base_max_hp: float = 100.0
var _base_pickup: float = 90.0
var _invuln_left: float = 0.0
var _cooldown: float = 0.0
var _assist_cos: float = 1.0
var _aim_hold: float = 1.0
var _aim_hold_left: float = 0.0
var _raw_aim: Vector2 = Vector2.RIGHT
var _effects: Effects
var _stats: Dictionary = {}
var _dash_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT

@onready var visual: Node2D = $Visual
@onready var aim_pivot: Node2D = $AimPivot
@onready var barrel: Node2D = $AimPivot/Barrel
@onready var aim_guide: Node2D = $AimPivot/AimGuide


func setup(enemies: EnemyManager, bullets: BulletManager, arena: Rect2, ink: InkSystem, effects: Effects) -> void:
	_effects = effects
	_enemies = enemies
	_bullets = bullets
	_arena = arena
	_ink = ink
	var stats: Dictionary = DataDB.player.get("default", {})
	_stats = stats
	radius = float(stats.get("radius", radius))
	speed = float(stats.get("speed", speed))
	max_hp = float(stats.get("max_hp", max_hp))
	invuln_time = float(stats.get("invuln_time", invuln_time))
	weapon = DataDB.weapons.get(String(stats.get("weapon", "")), {})
	_trail_radius = float(stats.get("trail_radius", _trail_radius))
	_ink_speed_bonus = float(stats.get("ink_speed_bonus", 0.0))
	_base_max_hp = max_hp
	_base_pickup = float(stats.get("pickup_radius", _base_pickup))
	_assist_cos = cos(deg_to_rad(float(stats.get("aim_assist_deg", 0.0))))
	_aim_hold = float(stats.get("aim_hold_seconds", 1.0))
	hp = max_hp
	Events.upgrade_applied.connect(_on_upgrade_applied)
	visual.setup(stats.get("visual", {}), radius)
	barrel.position = Vector2(radius + 7.0, 0.0)
	barrel.setup({"sides": 3, "color": "#12235e", "outline": "#060d2b", "shadow": false}, 8.0)
	Events.player_health_changed.emit(hp, max_hp)


func _process(delta: float) -> void:
	if not GameState.is_playing() or _enemies == null:
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var on_ink := _ink.grid.is_ink(position)
	var current_speed := Upgrades.value("move_speed", speed)
	if on_ink:
		current_speed *= 1.0 + _ink_speed_bonus + Upgrades.bonus("ink_speed")
		var regen := Upgrades.bonus("ink_regen")
		if regen > 0.0 and hp < max_hp:
			heal(regen * delta)
	_update_dash(move, delta)
	if _dash_left > 0.0:
		position += _dash_dir * current_speed * float(_stats.get("dash_speed_mult", 4.0)) * delta
	else:
		position += move * current_speed * delta
	position.x = clampf(position.x, _arena.position.x + radius, _arena.end.x - radius)
	position.y = clampf(position.y, _arena.position.y + radius, _arena.end.y - radius)

	# Footsteps: a thin line of ink. Closing it into a loop sets up a pulse.
	# Painted as a line from the last point, so a slow frame cannot leave gaps.
	if position.distance_squared_to(_last_trail_pos) > 9.0:
		var trail := Upgrades.value("trail_radius", _trail_radius)
		if _last_trail_pos == Vector2.INF:
			_ink.grid.paint_circle(position, trail, InkGrid.INK)
		else:
			_ink.grid.paint_line(_last_trail_pos, position, trail, InkGrid.INK)
		_last_trail_pos = position

	_invuln_left -= delta
	_cooldown -= delta
	_update_aim(move, delta)

	if Input.is_action_pressed("fire") and _cooldown <= 0.0 and not weapon.is_empty():
		_cooldown = float(weapon.get("fire_interval", 0.3)) / Upgrades.mult_of("fire_rate")
		if GameState.has_power("frenzy"):
			_cooldown /= float(DataDB.pickups.get("types", {}).get("frenzy", {}).get("fire_rate_mult", 2.0))
		_fire_volley()


func _update_aim(move: Vector2, delta: float) -> void:
	var auto := GameState.has_power("auto_aim")
	var weapon_range := float(weapon.get("range", 500.0))
	var target: Enemy = null
	if auto:
		target = _enemies.nearest(position, weapon_range)
	if target == null:
		# Manual aim: the stick wins and is remembered briefly after release,
		# so letting go mid-fight does not swing the gun to the move direction.
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		_aim_hold_left -= delta
		if stick.length() > AIM_DEADZONE:
			_raw_aim = stick.normalized()
			_aim_hold_left = _aim_hold
		elif _aim_hold_left <= 0.0 and move != Vector2.ZERO:
			_raw_aim = move.normalized()
		# Aim assist: snap to the nearest enemy inside a cone around the aim.
		if _assist_cos < 1.0:
			target = _enemies.nearest_in_cone(position, _raw_aim, weapon_range, _assist_cos)
		if target == null:
			aim_dir = _raw_aim
	if target != null:
		aim_dir = (target.position - position).normalized()
	aim_pivot.rotation = aim_dir.angle()
	aim_guide.set_locked(auto)


## Parallel shots (Twin Nib) plus angled side shots (Scatter).
func _fire_volley() -> void:
	var muzzle := position + aim_dir * (radius + 8.0)
	var side := aim_dir.orthogonal()
	var parallel := 1 + int(Upgrades.bonus("multishot"))
	var spacing := float(weapon.get("parallel_spacing", 14.0))
	# Each extra parallel shot makes all of them a little weaker.
	var parallel_scale := 1.0 / (1.0 + float(weapon.get("parallel_damage_falloff", 0.0)) * (parallel - 1))
	for i in parallel:
		_bullets.fire(muzzle + side * (i - (parallel - 1) * 0.5) * spacing, aim_dir, weapon, parallel_scale)
	_effects.muzzle(muzzle, aim_dir, Color("#38bdf8"))
	var scatter := int(Upgrades.bonus("scatter"))
	var angle := deg_to_rad(float(weapon.get("scatter_angle_deg", 16.0)))
	var scatter_damage := float(weapon.get("scatter_damage_mult", 0.6))
	for i in scatter:
		var ring := i / 2 + 1
		var sign_dir := 1.0 if i % 2 == 0 else -1.0
		_bullets.fire(muzzle, aim_dir.rotated(sign_dir * ring * angle), weapon, scatter_damage)


## Dash (unlocked by the Dash upgrade): a short invulnerable burst.
func _update_dash(move: Vector2, delta: float) -> void:
	var level := int(Upgrades.bonus("dash"))
	if level <= 0:
		return
	var cooldown := maxf(1.0, float(_stats.get("dash_cooldown", 4.5)) - float(_stats.get("dash_cooldown_per_level", 0.5)) * (level - 1))
	if _dash_left > 0.0:
		_dash_left -= delta
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left -= delta
		Events.dash_charge_changed.emit(clampf(1.0 - _dash_cooldown_left / cooldown, 0.0, 1.0))
	elif Input.is_action_just_pressed("dash"):
		_dash_dir = move.normalized() if move != Vector2.ZERO else aim_dir
		_dash_left = float(_stats.get("dash_time", 0.18))
		_dash_cooldown_left = cooldown
		_invuln_left = maxf(_invuln_left, _dash_left + 0.15)
		_effects.ring(position, 40.0, Color(0.22, 0.45, 0.95, 0.8), 0.25)
		Events.dash_charge_changed.emit(0.0)


func take_damage(amount: float) -> void:
	if _invuln_left > 0.0 or not GameState.is_playing():
		return
	hp = maxf(0.0, hp - amount)
	_invuln_left = invuln_time
	visual.flash()
	Events.screen_shake.emit(8.0)
	Events.player_health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		Events.player_died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	Events.player_health_changed.emit(hp, max_hp)


func pickup_radius() -> float:
	return Upgrades.value("pickup_radius", _base_pickup)


func _on_upgrade_applied(_id: String) -> void:
	# Max health upgrades also heal by the amount gained.
	var new_max := Upgrades.value("max_hp", _base_max_hp)
	if new_max != max_hp:
		var gained := new_max - max_hp
		max_hp = new_max
		hp = clampf(hp + maxf(gained, 0.0), 0.0, max_hp)
		Events.player_health_changed.emit(hp, max_hp)
