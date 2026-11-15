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
## The ink chosen for the run: a play style and a colour (data/inks.json).
## Chosen on the title screen and remembered in the save.
var ink_id: String = "blue"
## Which game mode the next run uses (a key in modes.json and waves.json).
var mode_id: String = "survival"
var ink_color: Color = Color("#1a4df2")
var ink_light: Color = Color("#4d8fff")
## Temporary powers: id -> seconds left.
var powers: Dictionary = {}
## Extra damage share from the player's current situation (on ink, low health,
## moving...). Set by the player each frame; applied to every weapon.
var damage_bonus: float = 0.0
var _xp_fraction: float = 0.0
var milestones: int = 0
## Extra Seals earned inside a run (Burning Page strips).
var bonus_seals: float = 0.0
var won: bool = false
var _rewarded: bool = false


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_died.connect(_on_player_died)
	Events.milestone_reached.connect(func(_p: int, _t: String) -> void: milestones += 1)
	Events.final_boss_defeated.connect(func() -> void: won = true)
	set_ink(String(SaveData.data.get("ink", "blue")))


func set_ink(id: String) -> void:
	if not DataDB.inks.has(id):
		id = "blue"
	ink_id = id
	var def: Dictionary = DataDB.inks.get(id, {})
	ink_color = Color(String(def.get("color", "#1a4df2")))
	ink_light = Color(String(def.get("light", "#4d8fff")))


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
	milestones = 0
	bonus_seals = 0.0
	won = false
	_rewarded = false
	Events.run_started.emit()
	Events.xp_changed.emit(xp, xp_to_next, level)


## Seals this run is worth so far.
func seals_earned() -> int:
	var earn: Dictionary = DataDB.meta.get("earn", {})
	var total := run_time / 60.0 * float(earn.get("per_minute", 4.0))
	total += kills / maxf(1.0, float(earn.get("kills_per_seal", 25.0)))
	total += level * float(earn.get("per_level", 1.0))
	total += milestones * float(earn.get("per_milestone", 3.0))
	total += bonus_seals
	if won:
		total += float(earn.get("win_bonus", 50.0))
	return int(total)


## Banks the run: pays out Seals and updates records. Safe to call twice.
func finish_run() -> int:
	if _rewarded:
		return 0
	_rewarded = true
	var earned := seals_earned()
	SaveData.add_seals(earned)
	SaveData.data["runs"] = int(SaveData.data.get("runs", 0)) + 1
	SaveData.data["best_time"] = maxf(float(SaveData.data.get("best_time", 0.0)), run_time)
	if won:
		SaveData.data["wins"] = int(SaveData.data.get("wins", 0)) + 1
	SaveData.save()
	return earned


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
