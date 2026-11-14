class_name Player
extends Node2D
## Player: moves and aims from InputMap actions and fires the main weapon
## while "fire" is held. Aim order: the Auto-Aim power (nearest enemy), then
## the aim stick, then the direction of travel. Most defensive, movement and
## gun upgrades resolve here.

const AIM_DEADZONE := 0.25

var radius: float = 14.0
var speed: float = 230.0
var max_hp: float = 100.0
var hp: float = 100.0
var invuln_time: float = 0.6
var weapon: Dictionary = {}
var aim_dir: Vector2 = Vector2.RIGHT
var on_ink: bool = false
var moving: bool = false
## Share of incoming damage blocked (set each frame by a Fortress glyph).
var shelter: float = 0.0

var _enemies: EnemyManager
var _bullets: BulletManager
var _arena: Rect2
var _ink: InkSystem
var _effects: Effects
var _stats: Dictionary = {}
var _sniper_weapon: Dictionary = {}
var _trail_radius: float = 6.0
var _ink_speed_bonus: float = 0.0
var _last_trail_pos: Vector2 = Vector2.INF
var _trail_travel: float = 0.0
var _base_max_hp: float = 100.0
var _base_pickup: float = 90.0
var _invuln_left: float = 0.0
var _cooldown: float = 0.0
var _assist_cos: float = 1.0
var _aim_hold: float = 1.0
var _aim_hold_left: float = 0.0
var _raw_aim: Vector2 = Vector2.RIGHT
var _dash_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _shot_count: int = 0
var _echoes: Array[Dictionary] = []
var _overcharge: float = 0.0      # 0..1 ramp while firing and standing still
var _slipstream: float = 0.0      # 0..1 ramp while moving straight
var _last_move_dir: Vector2 = Vector2.ZERO
var _ghost_left: float = 0.0
var _paper_left: float = 0.0      # seconds until the Paper Shield is back
var _second_wind_used: bool = false
var _shield: float = 0.0          # Ink Reserve points
var _shield_delay: float = 0.0

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
	# The gun and the player take the colour of the chosen ink.
	weapon = (DataDB.weapons.get(String(stats.get("weapon", "")), {}) as Dictionary).duplicate(true)
	var shot_look: Dictionary = weapon.get("visual", {})
	shot_look["color"] = GameState.ink_color.to_html()
	shot_look["outline"] = GameState.ink_color.to_html()
	shot_look["glow"] = GameState.ink_light.to_html()
	weapon["visual"] = shot_look
	# Sniper Nib rounds: the same gun, but fast, fat and piercing.
	_sniper_weapon = weapon.duplicate(true)
	_sniper_weapon["bullet_speed"] = float(weapon.get("bullet_speed", 600.0)) * DataDB.arsenal_num("sniper", "speed_mult", 2.0)
	_sniper_weapon["bullet_radius"] = DataDB.arsenal_num("sniper", "radius", 10.0)
	_sniper_weapon["pierce_bonus"] = 99
	_trail_radius = float(stats.get("trail_radius", _trail_radius))
	_ink_speed_bonus = float(stats.get("ink_speed_bonus", 0.0))
	_base_max_hp = max_hp
	_base_pickup = float(stats.get("pickup_radius", _base_pickup))
	_assist_cos = cos(deg_to_rad(float(stats.get("aim_assist_deg", 0.0))))
	_aim_hold = float(stats.get("aim_hold_seconds", 1.0))
	hp = max_hp
	Events.upgrade_applied.connect(_on_upgrade_applied)
	Events.set_bonus.connect(func(_n: String, _c: int, _d: String) -> void: _on_upgrade_applied(""))
	Events.enemy_killed.connect(_on_enemy_killed)
	var look: Dictionary = (stats.get("visual", {}) as Dictionary).duplicate()
	look["color"] = GameState.ink_color.to_html()
	visual.setup(look, radius)
	barrel.position = Vector2(radius + 7.0, 0.0)
	barrel.setup({"sides": 3, "color": GameState.ink_color.to_html(), "outline": GameState.ink_color.to_html(), "shadow": false}, 8.0)
	Events.player_health_changed.emit(hp, max_hp)


func _process(delta: float) -> void:
	if not GameState.is_playing() or _enemies == null:
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = move.length() > 0.5
	on_ink = _ink.grid.is_ink(position)
	var low_health := hp < max_hp * 0.25

	# Situational damage shared by every weapon.
	var bonus := 0.0
	if on_ink:
		bonus += Upgrades.bonus("home_turf")
	if moving:
		bonus += Upgrades.bonus("momentum")
	if low_health:
		bonus += Upgrades.bonus("last_stand")
	if GameState.has_power("loop_fury"):
		bonus += Upgrades.bonus("loop_fury")
	GameState.damage_bonus = bonus

	_update_health(delta)
	_move(move, delta)
	_paint_trail(move)

	_invuln_left -= delta
	_cooldown -= delta
	_update_aim(move, delta)
	_update_fire(low_health, delta)
	queue_redraw()


func _update_health(delta: float) -> void:
	var regen := Upgrades.bonus("regen")
	if on_ink:
		regen += Upgrades.bonus("ink_regen")
	if regen > 0.0 and hp < max_hp:
		heal(regen * delta)
	if _paper_left > 0.0:
		_paper_left -= delta
	# Ink Reserve: a shield sized by the share of the page you own.
	var per_step := Upgrades.bonus("reserve")
	if per_step > 0.0:
		var shield_max := floorf(_ink.ownership() * 100.0 / 5.0) * per_step
		_shield_delay -= delta
		if _shield_delay <= 0.0 and _shield < shield_max:
			_shield = minf(shield_max, _shield + DataDB.arsenal_num("reserve", "regen_per_second", 2.0) * delta)
		_shield = minf(_shield, shield_max)
		Events.shield_changed.emit(_shield, shield_max)


func _move(move: Vector2, delta: float) -> void:
	var current_speed := Upgrades.value("move_speed", speed)
	if on_ink:
		current_speed *= 1.0 + _ink_speed_bonus + Upgrades.bonus("ink_speed")
	# Slipstream: builds while you hold a straight line.
	var stream := Upgrades.bonus("slipstream")
	if stream > 0.0:
		if moving and move.normalized().dot(_last_move_dir) > 0.97:
			_slipstream = minf(1.0, _slipstream + delta / DataDB.arsenal_num("slipstream", "ramp_seconds", 2.0))
		else:
			_slipstream = 0.0
		current_speed *= 1.0 + stream * _slipstream
	if moving:
		_last_move_dir = move.normalized()
	if _ghost_left > 0.0:
		_ghost_left -= delta
		current_speed *= 1.0 + Upgrades.bonus("ghost_step")
	_update_dash(move, delta)
	if _dash_left > 0.0:
		position += _dash_dir * current_speed * float(_stats.get("dash_speed_mult", 4.0)) * delta
	else:
		position += move * current_speed * delta
	position.x = clampf(position.x, _arena.position.x + radius, _arena.end.x - radius)
	position.y = clampf(position.y, _arena.position.y + radius, _arena.end.y - radius)


## Footsteps: a thin line of ink. Closing it into a loop sets up a pulse.
## Painted as a line from the last point, so a slow frame cannot leave gaps.
func _paint_trail(move: Vector2) -> void:
	if position.distance_squared_to(_last_trail_pos) <= 9.0:
		return
	var trail := Upgrades.value("trail_radius", _trail_radius)
	# Brush pressure: the line swells and thins as it goes.
	_trail_travel += position.distance_to(_last_trail_pos) if _last_trail_pos != Vector2.INF else 0.0
	trail *= 0.75 + 0.55 * absf(sin(_trail_travel * 0.013)) + 0.2 * absf(sin(_trail_travel * 0.047))
	if move.length() > 0.9:
		trail *= 1.0 + Upgrades.bonus("trail_run")
	if GameState.has_power("giant_brush"):
		trail *= 5.0
	var grid := _ink.grid
	if _last_trail_pos == Vector2.INF:
		grid.paint_circle(position, trail, InkGrid.INK)
	else:
		grid.paint_line(_last_trail_pos, position, trail, InkGrid.INK)
		if Upgrades.bonus("double_trail") > 0.0:
			var side := (position - _last_trail_pos).normalized().orthogonal() * (trail + 14.0)
			grid.paint_line(_last_trail_pos + side, position + side, trail, InkGrid.INK)
	var clean := Upgrades.bonus("eraser")
	if clean > 0.0:
		grid.clean_circle(position, clean + trail)
	_last_trail_pos = position


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


func _update_fire(low_health: bool, delta: float) -> void:
	var firing := Input.is_action_pressed("fire") and not weapon.is_empty()
	# Overcharge: ramps while firing from a standstill, drops when you move.
	if firing and not moving:
		_overcharge = minf(1.0, _overcharge + delta / DataDB.arsenal_num("overcharge", "ramp_seconds", 3.0))
	else:
		_overcharge = maxf(0.0, _overcharge - delta * 2.0)

	if firing and _cooldown <= 0.0:
		var rate := Upgrades.mult_of("fire_rate")
		rate *= 1.0 + Upgrades.bonus("overcharge") * DataDB.arsenal_num("overcharge", "levels_mult", 3.0) * _overcharge
		if moving:
			rate *= 1.0 + Upgrades.bonus("run_gun")
		if low_health:
			rate *= 1.0 + Upgrades.bonus("last_stand")
		if GameState.has_power("frenzy"):
			rate *= float(DataDB.pickups.get("types", {}).get("frenzy", {}).get("fire_rate_mult", 2.0))
		_cooldown = float(weapon.get("fire_interval", 0.3)) / rate
		_fire_volley(1.0)
		_fire_extras()
		var echo := Upgrades.bonus("echo")
		if echo > 0.0:
			var share := DataDB.arsenal_num("echo", "damage_scale", 0.3) + DataDB.arsenal_num("echo", "damage_scale_per_level", 0.1) * (echo - 1.0)
			_echoes.append({"left": DataDB.arsenal_num("echo", "delay", 0.5), "scale": share})

	# Echo Shot: replay queued volleys.
	var i := _echoes.size() - 1
	while i >= 0:
		_echoes[i]["left"] -= delta
		if _echoes[i]["left"] <= 0.0:
			_fire_volley(float(_echoes[i]["scale"]))
			_echoes.remove_at(i)
		i -= 1


## Parallel shots (Twin Nib) plus angled side shots (Scatter).
func _fire_volley(scale: float) -> void:
	var muzzle := position + aim_dir * (radius + 8.0)
	var side := aim_dir.orthogonal()
	var parallel := 1 + int(Upgrades.bonus("multishot"))
	var spacing := float(weapon.get("parallel_spacing", 14.0))
	# Each extra parallel shot makes all of them a little weaker.
	var parallel_scale := scale / (1.0 + float(weapon.get("parallel_damage_falloff", 0.0)) * (parallel - 1))
	for i in parallel:
		_bullets.fire(muzzle + side * (i - (parallel - 1) * 0.5) * spacing, aim_dir, weapon, parallel_scale)
	_effects.muzzle(muzzle, aim_dir, GameState.ink_color)
	var scatter := int(Upgrades.bonus("scatter"))
	var angle := deg_to_rad(float(weapon.get("scatter_angle_deg", 16.0)))
	var scatter_damage := float(weapon.get("scatter_damage_mult", 0.6)) * scale
	for i in scatter:
		var ring := i / 2 + 1
		var sign_dir := 1.0 if i % 2 == 0 else -1.0
		_bullets.fire(muzzle, aim_dir.rotated(sign_dir * ring * angle), weapon, scatter_damage)


## Rear Guard, Side Guns and Sniper Nib ride along with each real volley.
func _fire_extras() -> void:
	var rear := int(Upgrades.bonus("rear_guard"))
	if rear > 0:
		var spread := deg_to_rad(DataDB.arsenal_num("rear_guard", "spread_deg", 14.0))
		for i in rear:
			var dir := (-aim_dir).rotated((i - (rear - 1) * 0.5) * spread)
			_bullets.fire(position + dir * (radius + 8.0), dir, weapon, DataDB.arsenal_num("rear_guard", "damage_scale", 0.8))
	var sides := Upgrades.bonus("side_guns")
	if sides > 0.0:
		var share := DataDB.arsenal_num("side_guns", "damage_scale", 0.5) + DataDB.arsenal_num("side_guns", "damage_scale_per_level", 0.15) * (sides - 1.0)
		for dir: Vector2 in [aim_dir.orthogonal(), -aim_dir.orthogonal()]:
			_bullets.fire(position + dir * (radius + 8.0), dir, weapon, share)
	var sniper := Upgrades.bonus("sniper")
	if sniper > 0.0:
		_shot_count += 1
		if _shot_count >= maxi(4, int(DataDB.arsenal_num("sniper", "every", 10.0)) - int(sniper) + 1):
			_shot_count = 0
			var power := DataDB.arsenal_num("sniper", "damage_scale", 3.0) + DataDB.arsenal_num("sniper", "damage_scale_per_level", 1.0) * (sniper - 1.0)
			_bullets.fire(position + aim_dir * (radius + 10.0), aim_dir, _sniper_weapon, power)
			Events.screen_shake.emit(3.0)


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
		_effects.ring(position, 40.0, Color(GameState.ink_color, 0.8), 0.25)
		Events.dash_charge_changed.emit(0.0)


## Returns true when the hit actually landed (not dodged, blocked or ignored).
func take_damage(amount: float) -> bool:
	if _invuln_left > 0.0 or not GameState.is_playing() or GameState.has_power("invincible"):
		return false
	if randf() < Upgrades.bonus("dodge"):
		_invuln_left = 0.25
		_effects.ring(position, 34.0, Color(1, 1, 1, 0.8), 0.2)
		return false
	var paper := Upgrades.bonus("paper_shield")
	if paper > 0.0 and _paper_left <= 0.0:
		# Paper Shield: swallow the whole hit, then recharge.
		_paper_left = maxf(4.0, DataDB.arsenal_num("paper_shield", "recharge", 18.0) - DataDB.arsenal_num("paper_shield", "recharge_per_level", 3.0) * (paper - 1.0))
		_invuln_left = invuln_time
		_effects.ring(position, 60.0, Color(1.0, 0.95, 0.7, 0.95), 0.35)
		return false

	var blocked := shelter + Upgrades.bonus("armor")
	if on_ink:
		blocked += Upgrades.bonus("ink_armor")
	amount *= 1.0 - clampf(blocked, 0.0, 0.9)
	if _shield > 0.0:
		var absorbed := minf(_shield, amount)
		_shield -= absorbed
		amount -= absorbed
	_shield_delay = DataDB.arsenal_num("reserve", "regen_delay", 4.0)

	hp = maxf(0.0, hp - amount)
	_invuln_left = invuln_time + Upgrades.bonus("mercy")
	_ghost_left = DataDB.arsenal_num("ghost_step", "seconds", 1.5)
	if hp <= 0.0 and Upgrades.bonus("second_wind") > 0.0 and not _second_wind_used:
		# Second Wind: once per run, refuse to die.
		_second_wind_used = true
		hp = max_hp * 0.3
		_invuln_left = 2.0
		_effects.ring(position, 220.0, Color(1.0, 0.8, 0.2, 0.95), 0.6)
		_enemies.knockback(position, 220.0, 120.0)
	visual.flash()
	Events.screen_shake.emit(8.0)
	Events.player_health_changed.emit(hp, max_hp)
	Events.player_hurt.emit()
	if hp <= 0.0:
		Events.player_died.emit()
	return true


func heal(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	Events.player_health_changed.emit(hp, max_hp)


## Brief invulnerability granted by other systems (Pulse Shield).
func grant_invulnerability(seconds: float) -> void:
	_invuln_left = maxf(_invuln_left, seconds)


func pickup_radius() -> float:
	return Upgrades.value("pickup_radius", _base_pickup)


func _on_enemy_killed(_type_id: String, _pos: Vector2, _splat_radius: float, _xp: int, _dir: Vector2) -> void:
	if randf() < Upgrades.bonus("vampiric"):
		heal(1.0)


func _on_upgrade_applied(_id: String) -> void:
	# Max health upgrades also heal by the amount gained.
	var new_max := Upgrades.value("max_hp", _base_max_hp)
	if new_max != max_hp:
		var gained := new_max - max_hp
		max_hp = new_max
		hp = clampf(hp + maxf(gained, 0.0), 0.0, max_hp)
		Events.player_health_changed.emit(hp, max_hp)


## Shield rings around the player: gold for a ready Paper Shield, cyan for
## Ink Reserve points, white while invincible.
func _draw() -> void:
	if Upgrades.bonus("paper_shield") > 0.0 and _paper_left <= 0.0:
		draw_arc(Vector2.ZERO, radius + 9.0, 0.0, TAU, 28, Color(1.0, 0.85, 0.3, 0.9), 3.0)
	if _shield > 0.5:
		draw_arc(Vector2.ZERO, radius + 14.0, 0.0, TAU, 28, Color(GameState.ink_color, 0.8), 3.0)
	if GameState.has_power("invincible"):
		draw_arc(Vector2.ZERO, radius + 19.0, 0.0, TAU, 28, Color(1, 1, 1, 0.9), 4.0)
