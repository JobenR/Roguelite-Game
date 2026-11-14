class_name GlyphSystem
extends Node2D
## Glyphs: when a pulse fills a closed shape, the shape is read. A circle,
## triangle, or square triggers a mega action whose strength scales with the
## shape's area. Numbers live in data/glyphs.json.
##
##   circle   -> Maelstrom: pulls enemies in and grinds everything inside.
##   triangle -> Spike Burst: a beam of ink fires outward from each corner.
##   square   -> Fortress: the area becomes permanent ink and shelters you.

var _player: Player
var _enemies: EnemyManager
var _ink: InkSystem
var _effects: Effects
var _cfg: Dictionary = {}
var _zones: Array[Dictionary] = []   # active maelstroms and fortresses
var _labels: Array[Dictionary] = []  # floating glyph names


func setup(player: Player, enemies: EnemyManager, ink: InkSystem, effects: Effects) -> void:
	_player = player
	_enemies = enemies
	_ink = ink
	_effects = effects
	_cfg = DataDB.glyphs


## Called by the pulse with the cells it just filled. Splits them into
## separate regions and resolves each one.
func resolve(filled: PackedInt32Array) -> void:
	var grid := _ink.grid
	var cell_area := grid.cell_size * grid.cell_size
	# Mark the filled cells, then peel off connected regions one at a time.
	grid.mask.fill(0)
	for index in filled:
		grid.mask[index] = 1
	for start in filled:
		if grid.mask[start] != 1:
			continue
		var region := PackedInt32Array()
		var stack := PackedInt32Array([start])
		grid.mask[start] = 2
		while not stack.is_empty():
			var last := stack.size() - 1
			var index := stack[last]
			stack.resize(last)
			region.append(index)
			var x := index % grid.cols
			for n: int in [index - 1, index + 1, index - grid.cols, index + grid.cols]:
				if n < 0 or n >= grid.mask.size() or grid.mask[n] != 1:
					continue
				# Do not wrap across the left and right page edges.
				if absi(n % grid.cols - x) > 1:
					continue
				grid.mask[n] = 2
				stack.append(n)
		var area := region.size() * cell_area
		if area >= float(_cfg.get("min_area", 6000.0)):
			_resolve_region(region, area)


func _resolve_region(region: PackedInt32Array, area: float) -> void:
	var grid := _ink.grid
	var points := PackedVector2Array()
	points.resize(region.size())
	for i in region.size():
		points[i] = grid.cell_center(region[i])
	var shape := ShapeClassifier.classify(points, area, float(_cfg.get("corner_threshold", 0.1)), float(_cfg.get("min_fill_ratio", 0.7)))
	var kind: String = shape["kind"]
	if kind == "":
		return
	var scale_factor := clampf(area / float(_cfg.get("reference_area", 40000.0)), 0.3, float(_cfg.get("max_scale", 4.0)))
	var centroid: Vector2 = shape["centroid"]
	var corners: PackedVector2Array = shape["corners"]
	var cfg: Dictionary = _cfg.get(kind, {})
	match kind:
		"circle":
			_zones.append({
				"kind": kind, "center": centroid, "radius": float(shape["radius"]),
				"left": float(cfg.get("duration", 2.5)) + float(cfg.get("duration_per_scale", 1.0)) * scale_factor,
				"scale": scale_factor, "tick": 0.0,
			})
		"triangle":
			var length := float(cfg.get("length", 260.0)) + float(cfg.get("length_per_scale", 140.0)) * scale_factor
			var width := float(cfg.get("width", 22.0))
			var spike_damage := float(cfg.get("damage", 60.0)) * sqrt(scale_factor)
			for corner in corners:
				var dir := (corner - centroid).normalized()
				_enemies.damage_segment(corner, corner + dir * length, width, spike_damage)
				grid.paint_line(corner, corner + dir * length, 6.0, InkGrid.INK)
				_effects.beam(corner, corner + dir * length, Color(1.0, 0.78, 0.2), width, 0.45)
		"square":
			for index in region:
				grid.set_cell(index, InkGrid.LOCKED)
				grid.set_glow(index)
			_zones.append({
				"kind": kind, "center": centroid, "polygon": corners,
				"left": float(cfg.get("duration", 5.0)) + float(cfg.get("duration_per_scale", 3.0)) * scale_factor,
				"reduction": float(cfg.get("damage_reduction", 0.75)),
			})
	_labels.append({"text": String(cfg.get("name", kind)).to_upper(), "pos": centroid, "age": 0.0, "outline": corners})
	_effects.big_moment(centroid, float(shape["radius"]) * 1.3, Color(1.0, 0.78, 0.2), 0.8)
	Events.screen_shake.emit(9.0)
	Events.glyph_triggered.emit(kind, scale_factor)


func _process(delta: float) -> void:
	if _player == null:
		return
	if GameState.is_playing():
		_update_zones(delta)
	var i := _labels.size() - 1
	while i >= 0:
		_labels[i]["age"] += delta
		if _labels[i]["age"] >= 1.8:
			_labels.remove_at(i)
		i -= 1
	if not _zones.is_empty() or not _labels.is_empty():
		queue_redraw()


func _update_zones(delta: float) -> void:
	var shelter := 0.0
	var i := _zones.size() - 1
	while i >= 0:
		var zone := _zones[i]
		zone["left"] -= delta
		if zone["left"] <= 0.0:
			_zones.remove_at(i)
			queue_redraw()
		elif zone["kind"] == "circle":
			_update_maelstrom(zone, delta)
		else:
			var polygon: PackedVector2Array = zone["polygon"]
			if Geometry2D.is_point_in_polygon(_player.position, polygon):
				shelter = maxf(shelter, float(zone["reduction"]))
		i -= 1
	_player.shelter = shelter


func _update_maelstrom(zone: Dictionary, delta: float) -> void:
	var cfg: Dictionary = _cfg.get("circle", {})
	var center: Vector2 = zone["center"]
	var radius: float = zone["radius"]
	var pull_radius := radius * float(cfg.get("pull_radius_mult", 1.8))
	var pull := float(cfg.get("pull_speed", 140.0)) * delta
	for enemy in _enemies.active:
		var offset := center - enemy.position
		var d := offset.length()
		if d < pull_radius and d > 4.0 and not enemy.heavy:
			enemy.position += offset / d * minf(pull, d)
	zone["tick"] -= delta
	if zone["tick"] <= 0.0:
		zone["tick"] = 0.25
		var dps := float(cfg.get("damage_per_second", 30.0)) * sqrt(float(zone["scale"]))
		_enemies.damage_area(center, radius, dps * 0.25)


func _draw() -> void:
	var font: Font = Sumi.TITLE_FONT
	var spin := Time.get_ticks_msec() * 0.006
	for zone in _zones:
		var center: Vector2 = zone["center"]
		if zone["kind"] == "circle":
			var radius: float = zone["radius"]
			for k in 3:
				var r := radius * (0.35 + 0.3 * k)
				draw_arc(center, r, spin * (1.0 + k * 0.4), spin * (1.0 + k * 0.4) + 4.2, 28, Color(0.05, 0.13, 0.45, 0.8), 6.0)
		else:
			var polygon: PackedVector2Array = zone["polygon"]
			var closed := polygon.duplicate()
			closed.append(polygon[0])
			var glow := 0.55 + 0.35 * sin(spin * 1.5)
			draw_polyline(closed, Color(1.0, 0.8, 0.2, glow), 7.0, true)
	for label in _labels:
		var t: float = float(label["age"]) / 1.8
		var alpha := 1.0 - t * t
		var outline: PackedVector2Array = label["outline"]
		if outline.size() >= 3 and t < 0.5:
			var closed := outline.duplicate()
			closed.append(outline[0])
			draw_polyline(closed, Color(1.0, 0.8, 0.2, 1.0 - t * 2.0), 6.0, true)
		var text: String = label["text"]
		var pos: Vector2 = label["pos"]
		pos.y -= 30.0 + t * 50.0
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		draw_string_outline(font, pos - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color(0.05, 0.05, 0.1, alpha))
		draw_string(font, pos - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1.0, 0.8, 0.2, alpha))
