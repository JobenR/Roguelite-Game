class_name ItemSystem
extends Node2D
## Saved items, used with the "item" action. Items found in a run (the Lasso
## pickup) live in GameState.items; items bought in the store (Page Wipe)
## live in the save. One button uses whichever is next in line.
##
##   lasso     - ropes the thickest nearby crowd into a tight knot for a few
##               seconds, so it can be shot or bombed at will.
##   page_wipe - destroys every ordinary enemy near the player and wounds bosses.

const ORDER: Array[String] = ["lasso", "page_wipe"]

var _player: Player
var _enemies: EnemyManager
var _effects: Effects
var _ropes: Array[Dictionary] = []


func setup(player: Player, enemies: EnemyManager, effects: Effects) -> void:
	_player = player
	_enemies = enemies
	_effects = effects
	Events.items_changed.emit()


## The item the button will use next, or "" when there is none.
static func held() -> String:
	for id in ORDER:
		if count(id) > 0:
			return id
	return ""


static func count(id: String) -> int:
	return int(GameState.items.get(id, 0)) + SaveData.item_count(id)


func _process(delta: float) -> void:
	if _player == null or not GameState.is_playing():
		return
	if Input.is_action_just_pressed("item"):
		_use(held())
	var i := _ropes.size() - 1
	while i >= 0:
		_ropes[i]["left"] -= delta
		if _ropes[i]["left"] <= 0.0:
			_ropes.remove_at(i)
		i -= 1
	if not _ropes.is_empty():
		queue_redraw()


func _use(id: String) -> void:
	if id == "":
		return
	# Run-found items are spent before bought ones.
	if int(GameState.items.get(id, 0)) > 0:
		GameState.items[id] = int(GameState.items[id]) - 1
	elif not SaveData.use_item(id):
		return
	match id:
		"lasso":
			_lasso()
		"page_wipe":
			_page_wipe()
	Events.items_changed.emit()


func _lasso() -> void:
	var cfg: Dictionary = DataDB.arsenal.get("lasso", {})
	var reach := float(cfg.get("range", 560.0))
	var gather := float(cfg.get("gather_radius", 300.0))
	var seconds := float(cfg.get("seconds", 6.0))
	var limit := int(cfg.get("max", 45))
	var center := _enemies.densest_point(_player.position, reach, gather * 0.6)
	if center == Vector2.INF:
		center = _player.position + _player.aim_dir * 200.0
	# Take the closest enemies to the centre of the crowd, up to the limit.
	var caught: Array[Enemy] = []
	for enemy in _enemies.active:
		if not enemy.heavy and enemy.position.distance_to(center) <= gather:
			caught.append(enemy)
	caught.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.position.distance_squared_to(center) < b.position.distance_squared_to(center))
	if caught.size() > limit:
		caught.resize(limit)
	var knot := 26.0 + sqrt(float(caught.size())) * 13.0
	for enemy in caught:
		enemy.bound_left = seconds
		enemy.bound_center = center
		enemy.bound_radius = knot
	_ropes.append({"center": center, "radius": knot + 16.0, "left": seconds, "total": seconds, "from": _player.position, "start": gather})
	_effects.ring(center, gather, Color(0.55, 0.38, 0.2, 0.9), 0.35)
	Audio.play("fizzle")
	Audio.buzz(40)
	Events.alert.emit("LASSO: %d CAUGHT" % caught.size(), 1.6)


func _page_wipe() -> void:
	var cfg: Dictionary = DataDB.arsenal.get("page_wipe", {})
	var reach := float(cfg.get("radius", 1000.0))
	for enemy: Enemy in _enemies.active.duplicate():
		if enemy.position.distance_to(_player.position) > reach:
			continue
		if enemy.is_boss:
			_enemies.damage(enemy, enemy.max_hp * float(cfg.get("boss_share", 0.25)))
		else:
			_enemies.damage(enemy, 999999.0, (enemy.position - _player.position).normalized())
	_effects.big_moment(_player.position, reach * 0.7, Color.WHITE, 1.0)
	_effects.ring(_player.position, reach, Color(1, 1, 1, 0.95), 0.7)
	Events.screen_shake.emit(16.0)
	Audio.play("bomb")
	Audio.buzz(120)
	Events.alert.emit("PAGE WIPE", 1.6)


## The rope: thrown from the player, then drawn tight round the knot.
func _draw() -> void:
	var rope := Color(0.42, 0.27, 0.13)
	for entry in _ropes:
		var center: Vector2 = entry["center"]
		var total: float = entry["total"]
		var age := total - float(entry["left"])
		var tighten := clampf(age / 0.45, 0.0, 1.0)
		var radius := lerpf(float(entry["start"]), float(entry["radius"]), 1.0 - (1.0 - tighten) * (1.0 - tighten))
		var fade := clampf(float(entry["left"]) / 0.6, 0.0, 1.0)
		var points := PackedVector2Array()
		for i in 41:
			var angle := TAU * i / 40.0
			points.append(center + Vector2.from_angle(angle) * radius * (1.0 + 0.04 * sin(angle * 7.0 + age * 6.0)))
		draw_polyline(points, Color(rope, 0.95 * fade), 6.0, true)
		draw_polyline(points, Color(0.8, 0.62, 0.38, 0.9 * fade), 2.0, true)
		if age < 0.6:
			draw_line(entry["from"], center + (Vector2(entry["from"]) - center).normalized() * radius, Color(rope, 0.9 * (1.0 - age / 0.6)), 5.0)
		draw_circle(center + Vector2(radius, 0.0), 7.0, Color(rope, fade))
