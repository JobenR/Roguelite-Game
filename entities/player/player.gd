class_name Player
extends Node2D
## Player: moves from InputMap actions, auto-aims at the nearest enemy, and
## fires the main weapon while the "fire" action is held.

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
var _trail_radius: float = 20.0
var _ink_speed_bonus: float = 0.0
var _last_trail_pos: Vector2 = Vector2.INF
var _base_max_hp: float = 100.0
var _base_pickup: float = 90.0
var _invuln_left: float = 0.0
var _cooldown: float = 0.0

@onready var visual: Node2D = $Visual
@onready var aim_pivot: Node2D = $AimPivot
@onready var barrel: Node2D = $AimPivot/Barrel


func setup(enemies: EnemyManager, bullets: BulletManager, arena: Rect2, ink: InkSystem) -> void:
	_ink = ink
	_enemies = enemies
	_bullets = bullets
	_arena = arena
	var stats: Dictionary = DataDB.player.get("default", {})
	radius = float(stats.get("radius", radius))
	speed = float(stats.get("speed", speed))
	max_hp = float(stats.get("max_hp", max_hp))
	invuln_time = float(stats.get("invuln_time", invuln_time))
	weapon = DataDB.weapons.get(String(stats.get("weapon", "")), {})
	_trail_radius = float(stats.get("trail_radius", _trail_radius))
	_ink_speed_bonus = float(stats.get("ink_speed_bonus", 0.0))
	_base_max_hp = max_hp
	_base_pickup = float(stats.get("pickup_radius", _base_pickup))
	hp = max_hp
	Events.upgrade_applied.connect(_on_upgrade_applied)
	visual.setup(stats.get("visual", {}), radius)
	barrel.position = Vector2(radius + 6.0, 0.0)
	barrel.setup({"sides": 3, "color": "#1e3a8a"}, 7.0)
	Events.player_health_changed.emit(hp, max_hp)


func _process(delta: float) -> void:
	if not GameState.is_playing() or _enemies == null:
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var on_ink := _ink.grid.state_at(position) == InkGrid.INK
	var current_speed := Upgrades.value("move_speed", speed)
	if on_ink:
		current_speed *= 1.0 + _ink_speed_bonus + Upgrades.bonus("ink_speed")
		var regen := Upgrades.bonus("ink_regen")
		if regen > 0.0 and hp < max_hp:
			heal(regen * delta)
	position += move * current_speed * delta
	position.x = clampf(position.x, _arena.position.x + radius, _arena.end.x - radius)
	position.y = clampf(position.y, _arena.position.y + radius, _arena.end.y - radius)

	# Footsteps: a thin trail of ink. Closing it into a loop sets up a pulse.
	if position.distance_squared_to(_last_trail_pos) > 36.0:
		_last_trail_pos = position
		_ink.grid.paint_circle(position, Upgrades.value("trail_radius", _trail_radius), InkGrid.INK)

	_invuln_left -= delta
	_cooldown -= delta

	var target := _enemies.nearest(position, float(weapon.get("range", 500.0)))
	if target != null:
		aim_dir = (target.position - position).normalized()
	elif move != Vector2.ZERO:
		aim_dir = move.normalized()
	aim_pivot.rotation = aim_dir.angle()

	if Input.is_action_pressed("fire") and _cooldown <= 0.0 and not weapon.is_empty():
		_cooldown = float(weapon.get("fire_interval", 0.3)) / Upgrades.mult_of("fire_rate")
		var shots := 1 + int(Upgrades.bonus("multishot"))
		var spread := deg_to_rad(float(weapon.get("multishot_spread_deg", 12.0)))
		for i in shots:
			var dir := aim_dir.rotated((i - (shots - 1) * 0.5) * spread)
			_bullets.fire(position + dir * (radius + 6.0), dir, weapon)


func take_damage(amount: float) -> void:
	if _invuln_left > 0.0 or not GameState.is_playing():
		return
	hp = maxf(0.0, hp - amount)
	_invuln_left = invuln_time
	visual.flash()
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
