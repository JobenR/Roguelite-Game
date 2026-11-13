class_name InkGrid
extends RefCounted
## The page as a grid of cells: who owns each patch of ground.
## One byte per cell plus an RGBA pixel buffer that the renderer uploads.

const NEUTRAL := 0
const INK := 1      # the player's ink
const SMUDGE := 2   # the horde's smudge

var cell_size: float
var cols: int
var rows: int
var cells: PackedByteArray = PackedByteArray()
var pixels: PackedByteArray = PackedByteArray()  # RGBA8: R = ink, G = smudge
var ink_count: int = 0
var smudge_count: int = 0
var dirty: bool = true
## Scratch mask written by find_enclosed(): 1 = enclosed, 2 = outside.
var mask: PackedByteArray = PackedByteArray()


func _init(area_size: Vector2, p_cell_size: float) -> void:
	cell_size = p_cell_size
	cols = maxi(1, int(ceil(area_size.x / cell_size)))
	rows = maxi(1, int(ceil(area_size.y / cell_size)))
	cells.resize(cols * rows)
	mask.resize(cols * rows)
	pixels.resize(cols * rows * 4)


func total_cells() -> int:
	return cols * rows


func cell_index(pos: Vector2) -> int:
	var cx := clampi(int(pos.x / cell_size), 0, cols - 1)
	var cy := clampi(int(pos.y / cell_size), 0, rows - 1)
	return cy * cols + cx


func state_at(pos: Vector2) -> int:
	return cells[cell_index(pos)]


func set_cell(index: int, state: int) -> void:
	var old := cells[index]
	if old == state:
		return
	if old == INK:
		ink_count -= 1
	elif old == SMUDGE:
		smudge_count -= 1
	if state == INK:
		ink_count += 1
	elif state == SMUDGE:
		smudge_count += 1
	cells[index] = state
	var p := index * 4
	pixels[p] = 255 if state == INK else 0
	pixels[p + 1] = 255 if state == SMUDGE else 0
	dirty = true


func paint_point(pos: Vector2, state: int) -> void:
	set_cell(cell_index(pos), state)


func paint_circle(pos: Vector2, radius: float, state: int) -> void:
	if radius < cell_size * 0.5:
		paint_point(pos, state)
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
			if dx * dx + dy * dy <= r_sq:
				set_cell(y * cols + x, state)


## Finds every non-ink cell that is fully walled in by ink (or by ink plus the
## page edge) inside the square reach of a pulse. A shape that extends past the
## reach, or whose outline has any gap, is not enclosed. Returns cell indices
## and marks them 1 in `mask`.
func find_enclosed(center: Vector2, radius: float) -> PackedInt32Array:
	var raw_x0 := int(floor((center.x - radius) / cell_size))
	var raw_x1 := int(floor((center.x + radius) / cell_size))
	var raw_y0 := int(floor((center.y - radius) / cell_size))
	var raw_y1 := int(floor((center.y + radius) / cell_size))
	var x0 := maxi(raw_x0, 0)
	var x1 := mini(raw_x1, cols - 1)
	var y0 := maxi(raw_y0, 0)
	var y1 := mini(raw_y1, rows - 1)
	mask.fill(0)
	var stack := PackedInt32Array()

	# Seed the flood from each side of the reach that is open ground. A side
	# that sits on the page edge is a wall and seeds nothing.
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

	var enclosed := PackedInt32Array()
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var index := y * cols + x
			if cells[index] != INK and mask[index] == 0:
				mask[index] = 1
				enclosed.append(index)
	return enclosed


func _seed(index: int, stack: PackedInt32Array) -> void:
	if mask[index] == 0 and cells[index] != INK:
		mask[index] = 2
		stack.append(index)


func cell_center(index: int) -> Vector2:
	return Vector2((index % cols + 0.5) * cell_size, (index / cols + 0.5) * cell_size)
