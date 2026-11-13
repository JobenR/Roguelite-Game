class_name PickupManager
extends Node2D
## Temporary-power pickups dropped by enemies (data/pickups.json). Walk over
## one to gain its power for a few seconds. A pity timer guarantees a drop if
## none has appeared for a while.

const MAX_ACTIVE := 3
const COLLECT_RADIUS := 26.0

var active: Array[Dictionary] = []

var _player: Player
var _effects: Effects
var _since_drop: Dictionary = {}  # id -> run_time of last drop


func setup(player: Player, effects: Effects) -> void:
	_player = player
	_effects = effects
	Events.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(_type_id: String, pos: Vector2, _splat_radius: float, _xp: int, _dir: Vector2) -> void:
	if active.size() >= MAX_ACTIVE:
		return
	for id: String in DataDB.pickups:
		var def: Dictionary = DataDB.pickups[id]
		var waited := GameState.run_time - float(_since_drop.get(id, 0.0))
		var overdue := waited >= float(def.get("max_seconds_between", 9999.0))
		if overdue or randf() < float(def.get("drop_chance", 0.0)):
			_since_drop[id] = GameState.run_time
			active.append({"id": id, "pos": pos, "life": float(def.get("lifetime", 20.0)), "color": Color(String(def.get("color", "#ffffff")))})
			return


func _process(delta: float) -> void:
	if _player == null or active.is_empty() or not GameState.is_playing():
		return
	var reach := _player.radius + COLLECT_RADIUS
	var i := active.size() - 1
	while i >= 0:
		var pickup := active[i]
		pickup["life"] -= delta
		var pos: Vector2 = pickup["pos"]
		if pos.distance_squared_to(_player.position) <= reach * reach:
			var id: String = pickup["id"]
			var def: Dictionary = DataDB.pickups.get(id, {})
			GameState.grant_power(id, float(def.get("duration", 8.0)) + Upgrades.bonus(id + "_duration"))
			_effects.ring(pos, 90.0, pickup["color"], 0.4)
			active.remove_at(i)
		elif pickup["life"] <= 0.0:
			active.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	var beat := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.12
	for pickup in active:
		var life: float = pickup["life"]
		# Blink during the last four seconds.
		if life < 4.0 and int(life * 6.0) % 2 == 0:
			continue
		var pos: Vector2 = pickup["pos"]
		var color: Color = pickup["color"]
		var r := 18.0 * beat
		draw_circle(pos, r + 8.0, Color(color, 0.18))
		draw_circle(pos, r, Color(1, 1, 1, 0.95))
		draw_arc(pos, r, 0.0, TAU, 28, color, 4.0)
		draw_arc(pos, r * 0.5, 0.0, TAU, 20, color, 3.0)
		for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(pos + dir * r * 0.75, pos + dir * (r + 7.0), color, 4.0)
