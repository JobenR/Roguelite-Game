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
	var old := cells[index]
	if old == state or old == LOCKED or old == DEAD:
		return
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
