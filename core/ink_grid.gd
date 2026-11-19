class_name InkGrid
extends RefCounted
## The page as a grid of cells: who owns each patch of ground.
## One byte per cell plus an RGBA pixel buffer that the renderer uploads.

const NEUTRAL := 0
const INK := 1      # the player's ink
const SMUDGE := 2   # the horde's smudge
const LOCKED := 3   # the player's ink made permanent; nothing overwrites it
const DEAD := 4     # burnt paper: impassable, and nothing can ever paint it

var cell_size: float
var cols: int
var rows: int
var cells: PackedByteArray = PackedByteArray()
var pixels: PackedByteArray = PackedByteArray()  # RGBA8: R = ink, G = smudge, B = locked, A = pulse glow
var ink_count: int = 0
var smudge_count: int = 0
var dead_count: int = 0
var dirty: bool = true
## Scratch mask written by find_enclosed(): 1 = enclosed, 2 = outside.
var mask: PackedByteArray = PackedByteArray()
## Watermark: when on, cells smudged over the player's ink are remembered here.
var track_smudged_ink: bool = false
var smudged_ink: PackedInt32Array = PackedInt32Array()
## Wet Ink Wall: per-cell time until which the cell blocks enemies. Allocated
## only when the upgrade is first used.
var wall_until: PackedFloat32Array = PackedFloat32Array()
## Bleed: a quarter-resolution count of ink cells. Sampled with smooth
## filtering it gives the soft grey halo where ink soaked into the paper.
const BLEED_SCALE := 4
var bleed_cols: int = 0
var bleed_rows: int = 0
var bleed: PackedByteArray = PackedByteArray()


## Paint by number (Masterpiece mode). Off in every other mode.
## `target` is the colour each cell should be (0 = not part of the picture),
## `region` the numbered area it belongs to, `tint` the colour it was last
## painted with. A cell is correct when it is ink and tint equals target.
var paint_on: bool = false
var current_tint: int = 1
var tint: PackedByteArray = PackedByteArray()
var target: PackedByteArray = PackedByteArray()
var region: PackedByteArray = PackedByteArray()
var palette: Array[Color] = []          # index 0 unused
var paint_pixels: PackedByteArray = PackedByteArray()   # RGB8: the colour laid on each cell
var paint_dirty: bool = false
## While set, ink is laid only in this region and on paper outside the
## picture, so a kill splat never spills a mistake into the area next door.
var clip_region: int = 0
## True Brush: while on, every stroke takes the colour its cell wants.
var auto_tint: bool = false
var region_cells: Array[PackedInt32Array] = []   # cell indices of each region; index 0 unused
var region_target: PackedByteArray = PackedByteArray()
var region_center: PackedVector2Array = PackedVector2Array()
var region_correct: PackedInt32Array = PackedInt32Array()   # correct cells in each region
var correct_count: int = 0
var target_total: int = 0


## Reclaim mode: walls (dead cells) stop shots, and enemy ink slows the player.
var walls_stop_shots: bool = false
var enemy_ink_slow: float = 0.0


func _init(area_size: Vector2, p_cell_size: float) -> void:
	cell_size = p_cell_size
	cols = maxi(1, int(ceil(area_size.x / cell_size)))
	rows = maxi(1, int(ceil(area_size.y / cell_size)))
	cells.resize(cols * rows)
	mask.resize(cols * rows)
	pixels.resize(cols * rows * 4)
	bleed_cols = int(ceil(float(cols) / BLEED_SCALE))
	bleed_rows = int(ceil(float(rows) / BLEED_SCALE))
	bleed.resize(bleed_cols * bleed_rows)


func total_cells() -> int:
	return cols * rows


func cell_index(pos: Vector2) -> int:
	var cx := clampi(int(pos.x / cell_size), 0, cols - 1)
	var cy := clampi(int(pos.y / cell_size), 0, rows - 1)
	return cy * cols + cx


func state_at(pos: Vector2) -> int:
	return cells[cell_index(pos)]


## True where the ground belongs to the player (normal or permanent ink).
func is_ink(pos: Vector2) -> bool:
	var state := cells[cell_index(pos)]
	return state == INK or state == LOCKED


func set_cell(index: int, state: int) -> void:
	if clip_region != 0 and state == INK and region[index] != 0 and region[index] != clip_region:
		return
	var old := cells[index]
	if old == state or old == LOCKED or old == DEAD:
		# Fresh ink laid over Deluge-flooded ground shows as an ordinary stroke,
		# so the player can still see their trail and splats there.
		if (state == INK or state == LOCKED) and old != DEAD:
			if pixels[index * 4 + 3] != 0:
				pixels[index * 4 + 3] = 0
				dirty = true
			if paint_on and tint[index] != _tint_for(index):
				_retint(index, true)
		return
	if paint_on:
		if old == INK and tint[index] == target[index] and target[index] != 0:
			correct_count -= 1
			region_correct[region[index]] -= 1
		if state == INK or state == LOCKED:
			_retint(index, false)
	var was_ink := old == INK
	var now_ink := state == INK or state == LOCKED
	if was_ink != now_ink:
		var b := (index / cols / BLEED_SCALE) * bleed_cols + (index % cols) / BLEED_SCALE
		bleed[b] = clampi(bleed[b] + (15 if now_ink else -15), 0, 255)
	if old == INK:
		ink_count -= 1
		if track_smudged_ink and state == SMUDGE:
			smudged_ink.append(index)
	elif old == SMUDGE:
		smudge_count -= 1
	if state == INK or state == LOCKED:
		ink_count += 1
	elif state == SMUDGE:
		smudge_count += 1
	cells[index] = state
	var p := index * 4
	pixels[p] = 255 if (state == INK or state == LOCKED) else 0
	pixels[p + 1] = 255 if state == SMUDGE else 0
	pixels[p + 2] = 255 if state == LOCKED else 0
	pixels[p + 3] = 0  # any change clears the pulse glow
	dirty = true


## The colour a fresh stroke lays on this cell: the carried ink, or with the
## True Brush the colour the picture wants there.
func _tint_for(index: int) -> int:
	return target[index] if (auto_tint and target[index] != 0) else current_tint


## Lays the current colour on a cell. `was_ink` says the cell already held
## ink, so its old colour may have been counted as correct.
func _retint(index: int, was_ink: bool) -> void:
	var goal := target[index]
	if was_ink and goal != 0 and tint[index] == goal:
		correct_count -= 1
		region_correct[region[index]] -= 1
	var lay := _tint_for(index)
	tint[index] = lay
	if goal != 0 and lay == goal:
		correct_count += 1
		region_correct[region[index]] += 1
	var c := palette[lay]
	var p := index * 3
	paint_pixels[p] = c.r8
	paint_pixels[p + 1] = c.g8
	paint_pixels[p + 2] = c.b8
	paint_dirty = true
	dirty = true


## Turns on paint by number. `p_target` and `p_region` are one byte per cell.
func start_paint(p_palette: Array[Color], p_target: PackedByteArray, p_region: PackedByteArray) -> void:
	paint_on = true
	palette = p_palette
	target = p_target
	region = p_region
	tint.resize(cols * rows)
	paint_pixels.resize(cols * rows * 3)
	target_total = 0
	var biggest := 0
	for i in cols * rows:
		biggest = maxi(biggest, region[i])
	region_cells.clear()
	region_target.resize(biggest + 1)
	region_center.resize(biggest + 1)
	region_correct.resize(biggest + 1)
	region_correct.fill(0)
	for id in biggest + 1:
		region_cells.append(PackedInt32Array())
	for i in cols * rows:
		if region[i] != 0:
			region_cells[region[i]].append(i)
			region_target[region[i]] = target[i]
	for id in range(1, biggest + 1):
		region_center[id] = _middle_of(region_cells[id])
	for i in cols * rows:
		var goal := target[i]
		if goal != 0:
			target_total += 1
		# Bare cells start as the colour they should become, so the soft edge
		# of a stroke never blends toward black.
		var c := palette[goal if goal != 0 else 1]
		paint_pixels[i * 3] = c.r8
		paint_pixels[i * 3 + 1] = c.g8
		paint_pixels[i * 3 + 2] = c.b8
	paint_dirty = true


## A point well inside a region: the cell nearest its centre of mass.
func _middle_of(list: PackedInt32Array) -> Vector2:
	if list.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for i in list:
		sum += Vector2(i % cols, i / cols)
	var mean := sum / float(list.size())
	var best := list[0]
	var best_d := INF
	for i in list:
		var d := Vector2(i % cols, i / cols).distance_squared_to(mean)
		if d < best_d:
			best_d = d
			best = i
	return (Vector2(best % cols, best / cols) + Vector2(0.5, 0.5)) * cell_size


## How much of the picture is right, 0..1: the average over its numbered
## areas, so a small area matters as much as a large one.
func accuracy() -> float:
	var sum := 0.0
	var count := 0
	for id in range(1, region_cells.size()):
		if not region_cells[id].is_empty():
			sum += float(region_correct[id]) / float(region_cells[id].size())
			count += 1
	return sum / float(maxi(1, count))


## Share of one numbered region painted in the right colour, 0..1.
func region_accuracy(id: int) -> float:
	return float(region_correct[id]) / float(maxi(1, region_cells[id].size()))


## Fills a whole numbered region with the current colour and makes it glow.
func flood_region(id: int, state: int) -> int:
	var changed := 0
	for i in region_cells[id]:
		if cells[i] != state and cells[i] != LOCKED and cells[i] != DEAD:
			changed += 1
		set_cell(i, state)
		set_glow(i)
	return changed


## Up to `count` unfinished regions that want colour `want`, nearest first.
func regions_wanting(want: int, from: Vector2, skip: int, count: int) -> Array[int]:
	var found: Array[int] = []
	if count <= 0:
		return found
	for id in range(1, region_cells.size()):
		if id != skip and region_target[id] == want and not region_cells[id].is_empty() and region_accuracy(id) < 0.9:
			found.append(id)
	found.sort_custom(func(a: int, b: int) -> bool:
		return region_center[a].distance_squared_to(from) < region_center[b].distance_squared_to(from))
	return found.slice(0, count)


## A permanent barrier: impassable, and nothing can paint it. Used to lay out
## level walls before play; it does not mark the cell as the player's.
func make_wall(index: int) -> void:
	var old := cells[index]
	if old == DEAD:
		return
	if old == INK or old == LOCKED:
		ink_count -= 1
	elif old == SMUDGE:
		smudge_count -= 1
	cells[index] = DEAD
	dead_count += 1
	var p := index * 4
	pixels[p] = 0
	pixels[p + 1] = 255
	pixels[p + 2] = 255
	pixels[p + 3] = 0
	dirty = true


## Share of the open page (walls excluded) held by the horde's ink, 0..1.
func enemy_share() -> float:
	return float(smudge_count) / float(maxi(1, total_cells() - dead_count))


func is_dead(pos: Vector2) -> bool:
	return dead_count > 0 and cells[cell_index(pos)] == DEAD


## Burns one cell. The player's ink survives as permanent ink; anything else
## becomes burnt paper. Returns true when the cell was the player's.
func burn_cell(index: int) -> bool:
	var old := cells[index]
	if old == INK or old == LOCKED:
		set_cell(index, LOCKED)
		return true
	if old == DEAD:
		return false
	if old == SMUDGE:
		smudge_count -= 1
	cells[index] = DEAD
	dead_count += 1
	# Burnt paper is stored as smudge and locked together, a pair no other
	# state uses, so the shader can tell it apart without a second texture.
	var p := index * 4
	pixels[p] = 0
	pixels[p + 1] = 255
	pixels[p + 2] = 255
	pixels[p + 3] = 0
	dirty = true
	return false


## Marks an ink cell as pulse-filled: it is drawn glowing until it is smudged.
func set_glow(index: int) -> void:
	if cells[index] == INK or cells[index] == LOCKED:
		pixels[index * 4 + 3] = 255
		dirty = true


## Floods a disc with ink (or permanent ink) and makes it glow. The edge is
## uneven, like a wave breaking. Returns the number of cells that changed.
func flood_disc(center: Vector2, radius: float, state: int) -> int:
	var x0 := clampi(int((center.x - radius) / cell_size), 0, cols - 1)
	var x1 := clampi(int((center.x + radius) / cell_size), 0, cols - 1)
	var y0 := clampi(int((center.y - radius) / cell_size), 0, rows - 1)
	var y1 := clampi(int((center.y + radius) / cell_size), 0, rows - 1)
	var changed := 0
	for y in range(y0, y1 + 1):
		var dy := (y + 0.5) * cell_size - center.y
		for x in range(x0, x1 + 1):
			var dx := (x + 0.5) * cell_size - center.x
			var edge := radius * (0.9 + 0.1 * sin(atan2(dy, dx) * 9.0) * cos(atan2(dy, dx) * 4.0))
			if dx * dx + dy * dy <= edge * edge:
				var index := y * cols + x
				if cells[index] != state and cells[index] != LOCKED and cells[index] != DEAD:
					changed += 1
				set_cell(index, state)
				set_glow(index)
	return changed


func paint_point(pos: Vector2, state: int) -> void:
	set_cell(cell_index(pos), state)


## Paints a filled circle. Cells currently in `protect` state are left alone.
func paint_circle(pos: Vector2, radius: float, state: int, protect: int = -1) -> void:
	if radius < cell_size * 0.5:
		var single := cell_index(pos)
		if cells[single] != protect:
			set_cell(single, state)
		return
	var x0 := clampi(int((pos.x - radius) / cell_size), 0, cols - 1)
	var x1 := clampi(int((pos.x + radius) / cell_size), 0, cols - 1)
	var y0 := clampi(int((pos.y - radius) / cell_size), 0, rows - 1)
	var y1 := clampi(int((pos.y + radius) / cell_size), 0, rows - 1)
	var r_sq := radius * radius
	for y in range(y0, y1 + 1):
		var dy := (y + 0.5) * cell_size - pos.y
		for x in range(x0, x1 + 1):
			var dx := (x + 0.5) * cell_size - pos.x
			if dx * dx + dy * dy <= r_sq and cells[y * cols + x] != protect:
				set_cell(y * cols + x, state)


## Marks every cell along the segment as a wall until time `until`.
func mark_wall_line(from: Vector2, to: Vector2, radius: float, until: float) -> void:
	if wall_until.is_empty():
		wall_until.resize(cols * rows)
	var steps := maxi(1, int(ceil(from.distance_to(to) / (cell_size * 0.5))))
	var reach := int(ceil(radius / cell_size))
	for i in steps + 1:
		var p := from.lerp(to, float(i) / steps)
		var cx := clampi(int(p.x / cell_size), 0, cols - 1)
		var cy := clampi(int(p.y / cell_size), 0, rows - 1)
		for y in range(maxi(cy - reach, 0), mini(cy + reach, rows - 1) + 1):
			for x in range(maxi(cx - reach, 0), mini(cx + reach, cols - 1) + 1):
				wall_until[y * cols + x] = until


func is_wall(pos: Vector2, now: float) -> bool:
	return not wall_until.is_empty() and wall_until[cell_index(pos)] > now


## Wipes smudge inside the circle back to blank paper. Ink is untouched.
func clean_circle(pos: Vector2, radius: float) -> void:
	var x0 := clampi(int((pos.x - radius) / cell_size), 0, cols - 1)
	var x1 := clampi(int((pos.x + radius) / cell_size), 0, cols - 1)
	var y0 := clampi(int((pos.y - radius) / cell_size), 0, rows - 1)
	var y1 := clampi(int((pos.y + radius) / cell_size), 0, rows - 1)
	var r_sq := radius * radius
	for y in range(y0, y1 + 1):
		var dy := (y + 0.5) * cell_size - pos.y
		for x in range(x0, x1 + 1):
			var dx := (x + 0.5) * cell_size - pos.x
			if dx * dx + dy * dy <= r_sq and cells[y * cols + x] == SMUDGE:
				set_cell(y * cols + x, NEUTRAL)


## Fills gaps of up to `span` cells between two pieces of ink on the same row
## or column, inside the square around `center`.
func close_gaps(center: Vector2, radius: float, span: int) -> void:
	var x0 := clampi(int((center.x - radius) / cell_size), 0, cols - 1)
	var x1 := clampi(int((center.x + radius) / cell_size), 0, cols - 1)
	var y0 := clampi(int((center.y - radius) / cell_size), 0, rows - 1)
	var y1 := clampi(int((center.y + radius) / cell_size), 0, rows - 1)
	var fill := PackedInt32Array()
	for y in range(y0, y1 + 1):
		var last := -1
		for x in range(x0, x1 + 1):
			if not _open(y * cols + x):
				var gap := x - last - 1
				if last >= 0 and gap >= 1 and gap <= span:
					for gx in range(last + 1, x):
						fill.append(y * cols + gx)
				last = x
	for x in range(x0, x1 + 1):
		var last := -1
		for y in range(y0, y1 + 1):
			if not _open(y * cols + x):
				var gap := y - last - 1
				if last >= 0 and gap >= 1 and gap <= span:
					for gy in range(last + 1, y):
						fill.append(gy * cols + x)
				last = y
	for index in fill:
		set_cell(index, INK)


## Grows every ink edge outward by `steps` cells inside the square around `center`.
func grow_ink(center: Vector2, radius: float, steps: int) -> void:
	var x0 := clampi(int((center.x - radius) / cell_size), 0, cols - 1)
	var x1 := clampi(int((center.x + radius) / cell_size), 0, cols - 1)
	var y0 := clampi(int((center.y - radius) / cell_size), 0, rows - 1)
	var y1 := clampi(int((center.y + radius) / cell_size), 0, rows - 1)
	for step in steps:
		var grow := PackedInt32Array()
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var index := y * cols + x
				if not _open(index):
					continue
				if (x > 0 and not _open(index - 1)) or (x < cols - 1 and not _open(index + 1)) \
						or (y > 0 and not _open(index - cols)) or (y < rows - 1 and not _open(index + cols)):
					grow.append(index)
		for index in grow:
			set_cell(index, INK)


func paint_line(from: Vector2, to: Vector2, radius: float, state: int) -> void:
	var steps := maxi(1, int(ceil(from.distance_to(to) / (cell_size * 0.5))))
	for i in steps + 1:
		paint_circle(from.lerp(to, float(i) / steps), radius, state)


## Finds every non-ink cell that is fully walled in by ink (or by ink plus the
## page edge) inside the square reach of a pulse. A shape that extends past the
## reach, or whose outline has a gap, is not enclosed. `gap_cells` forgives
## gaps up to that many cells wide. Returns cell indices and marks them 1 in
## `mask`.
func find_enclosed(center: Vector2, radius: float, gap_cells: int = 0) -> PackedInt32Array:
	var raw_x0 := int(floor((center.x - radius) / cell_size))
	var raw_x1 := int(floor((center.x + radius) / cell_size))
	var raw_y0 := int(floor((center.y - radius) / cell_size))
	var raw_y1 := int(floor((center.y + radius) / cell_size))
	var x0 := maxi(raw_x0, 0)
	var x1 := mini(raw_x1, cols - 1)
	var y0 := maxi(raw_y0, 0)
	var y1 := mini(raw_y1, rows - 1)
	mask.fill(0)

	# Gap forgiveness, step 1: thicken the walls. Cells next to ink become a
	# halo (3) that the flood cannot pass, which plugs small gaps.
	for pass_index in gap_cells:
		_grow(x0, x1, y0, y1, 3, true)

	# Seed the flood from each side of the reach that is open ground. A side
	# that sits on the page edge is a wall and seeds nothing.
	var stack := PackedInt32Array()
	for x in range(x0, x1 + 1):
		if raw_y0 > 0:
			_seed(y0 * cols + x, stack)
		if raw_y1 < rows - 1:
			_seed(y1 * cols + x, stack)
	for y in range(y0, y1 + 1):
		if raw_x0 > 0:
			_seed(y * cols + x0, stack)
		if raw_x1 < cols - 1:
			_seed(y * cols + x1, stack)

	# 4-connected flood, so a diagonal line of ink still counts as a wall.
	while not stack.is_empty():
		var last := stack.size() - 1
		var index := stack[last]
		stack.resize(last)
		var x := index % cols
		var y := index / cols
		if x > x0:
			_seed(index - 1, stack)
		if x < x1:
			_seed(index + 1, stack)
		if y > y0:
			_seed(index - cols, stack)
		if y < y1:
			_seed(index + cols, stack)

	# Step 2: give the halo on the outside of walls back to the outside, so
	# only halo cells that are truly inside a shape remain.
	for pass_index in gap_cells:
		_grow(x0, x1, y0, y1, 2, false)

	var enclosed := PackedInt32Array()
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var index := y * cols + x
			if _open(index) and mask[index] != 2:
				mask[index] = 1
				enclosed.append(index)
	return enclosed


## Open ground: not the player's ink and not burnt. Burnt paper walls in a
## shape just as the page edge does.
func _open(index: int) -> bool:
	var state := cells[index]
	return state != INK and state != LOCKED and state != DEAD


func _seed(index: int, stack: PackedInt32Array) -> void:
	if mask[index] == 0 and _open(index):
		mask[index] = 2
		stack.append(index)


## One step of growth inside the box. With from_ink, unmarked open cells that
## touch ink or the halo become `value`; otherwise halo cells that touch the
## outside (2) become `value`. Uses 8 neighbours.
func _grow(x0: int, x1: int, y0: int, y1: int, value: int, from_ink: bool) -> void:
	var changed := PackedInt32Array()
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var index := y * cols + x
			if not _open(index) or mask[index] != (0 if from_ink else 3):
				continue
			var touches := false
			for ny in range(maxi(y - 1, y0), mini(y + 1, y1) + 1):
				for nx in range(maxi(x - 1, x0), mini(x + 1, x1) + 1):
					var n := ny * cols + nx
					if from_ink:
						touches = touches or not _open(n) or mask[n] == 3
					else:
						touches = touches or mask[n] == 2
			if touches:
				changed.append(index)
	for index in changed:
		mask[index] = value


func cell_center(index: int) -> Vector2:
	return Vector2((index % cols + 0.5) * cell_size, (index / cols + 0.5) * cell_size)
