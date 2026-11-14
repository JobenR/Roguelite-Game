class_name PickupManager
extends Node2D
## Temporary-power pickups dropped by enemies (data/pickups.json). Walk over
## one to gain its power. There is one shared drop roll for all types, plus a
## pity timer that guarantees a drop if none has appeared for a while.

const MAX_ACTIVE := 2
const COLLECT_RADIUS := 26.0

var active: Array[Dictionary] = []

var _player: Player
var _effects: Effects
var _last_drop: float = 0.0


func setup(player: Player, effects: Effects) -> void:
	_player = player
	_effects = effects
	var gap := float(DataDB.pickups.get("max_seconds_between", 60.0))
	# Backdate the timer so the first drop arrives at first_drop_seconds.
	_last_drop = float(DataDB.pickups.get("first_drop_seconds", gap)) - gap
	Events.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(_type_id: String, pos: Vector2, _splat_radius: float, _xp: int, _dir: Vector2) -> void:
	if active.size() >= MAX_ACTIVE:
		return
	var cfg: Dictionary = DataDB.pickups
	var overdue := GameState.run_time - _last_drop >= float(cfg.get("max_seconds_between", 60.0))
	if not overdue and randf() >= float(cfg.get("drop_chance", 0.0)):
		return
	var id := _pick_type()
	if id == "":
		return
	_last_drop = GameState.run_time
	var def: Dictionary = cfg.get("types", {}).get(id, {})
	active.append({
		"id": id, "pos": pos, "life": float(cfg.get("lifetime", 25.0)),
		"color": Color(String(def.get("color", "#ffffff"))), "icon": String(def.get("icon", "")),
		"name": String(def.get("name", id)).to_upper(),
	})


## Weighted random pickup type.
func _pick_type() -> String:
	var types: Dictionary = DataDB.pickups.get("types", {})
	var total := 0.0
	for id: String in types:
		total += float(types[id].get("weight", 1.0))
	var roll := randf() * total
	for id: String in types:
		roll -= float(types[id].get("weight", 1.0))
		if roll <= 0.0:
			return id
	return ""


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
			var def: Dictionary = DataDB.pickups.get("types", {}).get(id, {})
			GameState.grant_power(id, float(def.get("duration", 8.0)) + Upgrades.bonus(id + "_duration"))
			_effects.ring(pos, 90.0, pickup["color"], 0.4)
			active.remove_at(i)
		elif pickup["life"] <= 0.0:
			active.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	var beat := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.12
	var font := ThemeDB.fallback_font
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
		match String(pickup["icon"]):
			"crosshair":
				draw_arc(pos, r * 0.5, 0.0, TAU, 20, color, 3.0)
				for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
					draw_line(pos + dir * r * 0.75, pos + dir * (r + 7.0), color, 4.0)
			"chevrons":
				for k in 3:
					var x := -9.0 + k * 7.0
					draw_polyline(PackedVector2Array([pos + Vector2(x, -8), pos + Vector2(x + 6, 0), pos + Vector2(x, 8)]), color, 3.5)
			"magnet":
				draw_arc(pos + Vector2(0, -2), 8.0, PI, TAU, 14, color, 6.0)
				draw_line(pos + Vector2(-8, -2), pos + Vector2(-8, 9), color, 6.0)
				draw_line(pos + Vector2(8, -2), pos + Vector2(8, 9), color, 6.0)
		var text: String = pickup["name"]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string_outline(font, pos + Vector2(-width * 0.5, r + 28.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color.WHITE)
		draw_string(font, pos + Vector2(-width * 0.5, r + 28.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
