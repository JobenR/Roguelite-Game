extends Node
## Run-level state shared by all systems: run clock, kills, XP and level.

enum State { PLAYING, DEAD }

var state: State = State.PLAYING
var run_time: float = 0.0
var kills: int = 0
var level: int = 1
var xp: int = 0
var xp_to_next: int = 5
var debug_visible: bool = false
## Temporary powers: id -> seconds left.
var powers: Dictionary = {}
## Extra damage share from the player's current situation (on ink, low health,
## moving...). Set by the player each frame; applied to every weapon.
var damage_bonus: float = 0.0
var _xp_fraction: float = 0.0


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_died.connect(_on_player_died)


func start_run() -> void:
	state = State.PLAYING
	run_time = 0.0
	kills = 0
	level = 1
	xp = 0
	xp_to_next = _xp_needed(1)
	powers.clear()
	damage_bonus = 0.0
	_xp_fraction = 0.0
	Events.run_started.emit()
	Events.xp_changed.emit(xp, xp_to_next, level)


func is_playing() -> bool:
	return state == State.PLAYING


func grant_power(id: String, seconds: float) -> void:
	powers[id] = maxf(power_left(id), seconds)
	Events.power_granted.emit(id, seconds)


func has_power(id: String) -> bool:
	return powers.has(id)


func power_left(id: String) -> float:
	return float(powers.get(id, 0.0))


func add_xp(amount: int) -> void:
	if state != State.PLAYING:
		return
	# Scholar: bonus XP, carried as a fraction until it adds up to a point.
	_xp_fraction += amount * Upgrades.mult_of("xp_gain")
	var gained := int(_xp_fraction)
	_xp_fraction -= gained
	xp += gained
	Events.xp_collected.emit(amount)
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = _xp_needed(level)
		Events.level_up.emit(level)
	Events.xp_changed.emit(xp, xp_to_next, level)


func _xp_needed(for_level: int) -> int:
	var cfg: Dictionary = DataDB.progression
	var base := float(cfg.get("xp_base", 5.0))
	var add := float(cfg.get("xp_add_per_level", 4.0))
	var growth := float(cfg.get("xp_growth", 1.1))
	return int(round((base + add * (for_level - 1)) * pow(growth, for_level - 1)))


func _process(delta: float) -> void:
	if state == State.PLAYING:
		run_time += delta
		for id: String in powers.keys():
			powers[id] = float(powers[id]) - delta
			if float(powers[id]) <= 0.0:
				powers.erase(id)
	# Actions are polled, never read from events: touch UI feeds them with
	# Input.action_press(), which does not generate input events.
	if Input.is_action_just_pressed("debug_toggle"):
		debug_visible = not debug_visible


func _on_enemy_killed(_type_id: String, _pos: Vector2, _splat_radius: float, _xp: int, _dir: Vector2) -> void:
	kills += 1


func _on_player_died() -> void:
	state = State.DEAD


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
