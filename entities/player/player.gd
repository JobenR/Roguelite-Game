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
var _invuln_left: float = 0.0
var _cooldown: float = 0.0

@onready var visual: Node2D = $Visual
@onready var aim_pivot: Node2D = $AimPivot
@onready var barrel: Node2D = $AimPivot/Barrel


func setup(enemies: EnemyManager, bullets: BulletManager, arena: Rect2) -> void:
	_enemies = enemies
	_bullets = bullets
	_arena = arena
	var stats: Dictionary = DataDB.player.get("default", {})
	radius = float(stats.get("radius", radius))
	speed = float(stats.get("speed", speed))
	max_hp = float(stats.get("max_hp", max_hp))
	invuln_time = float(stats.get("invuln_time", invuln_time))
	weapon = DataDB.weapons.get(String(stats.get("weapon", "")), {})
	hp = max_hp
	visual.setup(stats.get("visual", {}), radius)
	barrel.position = Vector2(radius + 6.0, 0.0)
	barrel.setup({"sides": 3, "color": "#1e3a8a"}, 7.0)
	Events.player_health_changed.emit(hp, max_hp)


func _process(delta: float) -> void:
	if not GameState.is_playing() or _enemies == null:
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += move * speed * delta
	position.x = clampf(position.x, _arena.position.x + radius, _arena.end.x - radius)
	position.y = clampf(position.y, _arena.position.y + radius, _arena.end.y - radius)

	_invuln_left -= delta
	_cooldown -= delta

	var target := _enemies.nearest(position, float(weapon.get("range", 500.0)))
	if target != null:
		aim_dir = (target.position - position).normalized()
	elif move != Vector2.ZERO:
		aim_dir = move.normalized()
	aim_pivot.rotation = aim_dir.angle()

	if Input.is_action_pressed("fire") and _cooldown <= 0.0 and not weapon.is_empty():
		_cooldown = float(weapon.get("fire_interval", 0.3))
		_bullets.fire(position + aim_dir * (radius + 6.0), aim_dir, weapon)


func take_damage(amount: float) -> void:
	if _invuln_left > 0.0 or not GameState.is_playing():
		return
	hp = maxf(0.0, hp - amount)
	_invuln_left = invuln_time
	visual.flash()
	Events.player_health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		Events.player_died.emit()
