class_name PaintSystem
extends Node2D
## Masterpiece mode: paint by number. Lays a picture of numbered areas on the
## page, places an ink well for each colour it needs, swaps the player's ink
## (colour and play style) when they dip in a well, and calls a short lull
## after each boss so the picture can be touched up.

var picture_id: String = ""
var picture: Dictionary = {}

var _player: Player
var _ink: InkSystem
var _effects: Effects
var _director: SpawnDirector
var _cfg: Dictionary = {}
var _wells: Array[Dictionary] = []    # pos, tint, ink_id, color
var _labels: Array[Dictionary] = []   # region, pos, tint, size, done
var _check_index: int = 0
var _check_left: float = 0.0
var _lull_left: float = 0.0
var _home_ink: String = "blue"
var _best_stars: int = 0


## The picture to paint next: the first without a star, else the weakest.
static func next_picture() -> String:
	var done: Dictionary = SaveData.data.get("pictures", {})
	var pick := ""
	var fewest := 99
	for id: String in DataDB.pictures:
		var stars := int(done.get(id, 0))
		if stars < 1:
			return id
		if stars < fewest:
			fewest = stars
			pick = id
	return pick


func setup(player: Player, ink: InkSystem, effects: Effects, director: SpawnDirector, arena: Rect2, cfg: Dictionary) -> void:
	_player = player
	_ink = ink
	_effects = effects
	_director = director
	_cfg = cfg
	picture_id = next_picture()
	picture = DataDB.pictures.get(picture_id, {})
	var grid := ink.grid
	var size: Array = picture.get("size", [1600, 900])
	var scale_by := Vector2(arena.size.x / float(size[0]), arena.size.y / float(size[1]))

	var ink_ids: Array = picture.get("inks", ["blue"])
	var palette: Array[Color] = [Color.BLACK]
	for id: String in ink_ids:
		palette.append(Color(String(DataDB.inks.get(id, {}).get("color", "#1a4df2"))))

	# Rasterise the shapes in order; later shapes sit on top of earlier ones.
	var target := PackedByteArray()
	var region := PackedByteArray()
	target.resize(grid.cols * grid.rows)
	region.resize(grid.cols * grid.rows)
	var shapes: Array = picture.get("shapes", [])
	for n in shapes.size():
		_rasterise(shapes[n], n + 1, ink_ids.find(String(shapes[n].get("ink", ""))) + 1, scale_by, grid, target, region)
	grid.start_paint(palette, target, region)
	ink.start_paint()

	for id in range(1, grid.region_cells.size()):
		var cells := grid.region_cells[id].size()
		if cells > 0:
			_labels.append({"region": id, "pos": grid.region_center[id], "tint": int(grid.region_target[id]),
				"size": clampf(sqrt(cells) * grid.cell_size * 0.2, 46.0, 110.0), "done": false})

	var spots: Array = picture.get("wells", [])
	for i in mini(spots.size(), ink_ids.size()):
		_wells.append({"pos": Vector2(float(spots[i][0]), float(spots[i][1])) * scale_by, "tint": i + 1,
			"ink_id": String(ink_ids[i]), "color": palette[i + 1]})

	# Start with the chosen ink if the picture uses it, else its first colour.
	_home_ink = GameState.ink_id
	var start := maxi(0, ink_ids.find(GameState.ink_id))
	GameState.set_ink(String(ink_ids[start]))
	grid.current_tint = start + 1
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.final_boss_defeated.connect(_on_final_boss_defeated)


func _exit_tree() -> void:
	# The ink chosen on the title screen comes back after the run.
	GameState.set_ink(_home_ink)


func _rasterise(shape: Dictionary, id: int, tint: int, scale_by: Vector2, grid: InkGrid, target: PackedByteArray, region: PackedByteArray) -> void:
	if tint <= 0:
		return
	var box := Rect2()
	var poly := PackedVector2Array()
	var kind := ""
	for key: String in ["circle", "ellipse", "rect", "poly"]:
		if shape.has(key):
			kind = key
	var v: Array = shape.get(kind, [])
	match kind:
		"circle":
			box = Rect2(float(v[0]) - float(v[2]), float(v[1]) - float(v[2]), float(v[2]) * 2.0, float(v[2]) * 2.0)
		"ellipse":
			box = Rect2(float(v[0]) - float(v[2]), float(v[1]) - float(v[3]), float(v[2]) * 2.0, float(v[3]) * 2.0)
		"rect":
			box = Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
		"poly":
			for i in range(0, v.size() - 1, 2):
				poly.append(Vector2(float(v[i]), float(v[i + 1])))
				box = Rect2(poly[0], Vector2.ZERO) if poly.size() == 1 else box.expand(poly[-1])
		_:
			return
	var centre := box.get_center()
	var half := box.size * 0.5
	var x0 := clampi(int(box.position.x * scale_by.x / grid.cell_size), 0, grid.cols - 1)
	var x1 := clampi(int(box.end.x * scale_by.x / grid.cell_size), 0, grid.cols - 1)
	var y0 := clampi(int(box.position.y * scale_by.y / grid.cell_size), 0, grid.rows - 1)
	var y1 := clampi(int(box.end.y * scale_by.y / grid.cell_size), 0, grid.rows - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2((x + 0.5) * grid.cell_size / scale_by.x, (y + 0.5) * grid.cell_size / scale_by.y)
			var inside := true
			if kind == "circle" or kind == "ellipse":
				var d := (p - centre) / half
				inside = d.length_squared() <= 1.0
			elif kind == "poly":
				inside = Geometry2D.is_point_in_polygon(p, poly)
			if inside:
				target[y * grid.cols + x] = tint
				region[y * grid.cols + x] = id


## 0 to 3 stars for the share of the picture painted correctly.
func stars() -> int:
	var count := 0
	for need: Variant in _cfg.get("stars", [0.6, 0.75, 0.9]):
		if _ink.grid.accuracy() >= float(need):
			count += 1
	return count


## The share needed for the next star, or 0 when all are earned.
func next_star_share() -> float:
	for need: Variant in _cfg.get("stars", [0.6, 0.75, 0.9]):
		if _ink.grid.accuracy() < float(need):
			return float(need)
	return 0.0


func _process(delta: float) -> void:
	if _player == null or not GameState.is_playing():
		return
	var reach := float(_cfg.get("well_radius", 70.0))
	for well in _wells:
		if int(well["tint"]) != _ink.grid.current_tint and _player.position.distance_to(well["pos"]) < reach:
			_dip(well)
	# One numbered area is re-counted every so often; finished ones lose their number.
	_check_left -= delta
	if _check_left <= 0.0 and not _labels.is_empty():
		_check_left = 0.2
		_check_index = (_check_index + 1) % _labels.size()
		var label := _labels[_check_index]
		var done := _ink.grid.region_accuracy(int(label["region"])) >= float(_cfg.get("done_share", 0.9))
		if done != bool(label["done"]):
			label["done"] = done
			if done:
				_effects.big_moment(label["pos"], 200.0, _ink.grid.palette[int(label["tint"])].lerp(Color.WHITE, 0.4), 0.6)
				Audio.play("milestone")
	if _lull_left > 0.0:
		_lull_left -= delta
	queue_redraw()


func _dip(well: Dictionary) -> void:
	var old := GameState.ink_id
	var fresh := String(well["ink_id"])
	GameState.set_ink(fresh)
	Upgrades.swap_ink(old, fresh)
	_ink.grid.current_tint = int(well["tint"])
	Events.ink_changed.emit()
	var def: Dictionary = DataDB.inks.get(fresh, {})
	Events.alert.emit("%s: %s" % [String(def.get("name", fresh)).to_upper(), String(def.get("tagline", ""))], 1.6)
	_effects.ring(well["pos"], 130.0, Color(GameState.ink_light, 0.95), 0.4)
	_effects.burst(well["pos"], Vector2.ZERO, GameState.ink_color, 14)
	Audio.play("card")


func _on_boss_defeated(_boss_name: String) -> void:
	var seconds := float(_cfg.get("lull_seconds", 12.0))
	_lull_left = seconds
	_director.hold_spawns = seconds
	Audio.hold_pressure(seconds)
	Events.alert.emit("TOUCH UP! %d SECONDS" % int(seconds), 3.0)


func _on_final_boss_defeated() -> void:
	_best_stars = maxi(_best_stars, stars())
	var done: Dictionary = SaveData.data.get("pictures", {})
	if _best_stars > int(done.get(picture_id, 0)):
		done[picture_id] = _best_stars
		SaveData.data["pictures"] = done
		SaveData.save()


func _draw() -> void:
	var font: Font = Sumi.TITLE_FONT
	for label in _labels:
		if bool(label["done"]):
			continue
		var size := int(label["size"])
		var text := str(int(label["tint"]))
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at: Vector2 = label["pos"] + Vector2(-width * 0.5, size * 0.35)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(Sumi.PAPER, 0.85))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Sumi.INK, 0.8))
	var reach := float(_cfg.get("well_radius", 70.0))
	var held := _ink.grid.current_tint if _ink != null else 0
	for well in _wells:
		var pos: Vector2 = well["pos"]
		var color: Color = well["color"]
		draw_circle(pos + Vector2(6, 9), reach * 0.8, Color(0.0, 0.0, 0.0, 0.18))
		draw_circle(pos, reach * 0.8, Sumi.PAPER)
		Brush.blot(self, pos, reach * 0.58, color, float(int(well["tint"])) * 1.7)
		draw_arc(pos, reach * 0.8, 0.0, TAU, 40, Sumi.INK, 7.0)
		if int(well["tint"]) == held:
			draw_arc(pos, reach * 0.98, 0.0, TAU, 40, Color(color.lerp(Color.WHITE, 0.4), 0.9), 5.0)
		var text := str(int(well["tint"]))
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
		draw_string_outline(font, pos + Vector2(-width * 0.5, 16.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, 8, Color(Sumi.INK, 0.9))
		draw_string(font, pos + Vector2(-width * 0.5, 16.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Sumi.PAPER)
