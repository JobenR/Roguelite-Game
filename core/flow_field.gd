class_name FlowField
extends RefCounted
## Routes the horde around burnt ground. A coarse grid over the page; a
## breadth-first search from the player's cell gives every passable cell the
## direction of its shortest path. One search serves every enemy.

const SCALE := 4  # ink cells per flow cell

var ready: bool = false
var cols: int
var rows: int
var cell_size: float

var _dirs: PackedVector2Array = PackedVector2Array()
var _dist: PackedInt32Array = PackedInt32Array()
var _passable: PackedByteArray = PackedByteArray()


func _init(grid: InkGrid) -> void:
	cols = int(ceil(float(grid.cols) / SCALE))
	rows = int(ceil(float(grid.rows) / SCALE))
	cell_size = grid.cell_size * SCALE
	_dirs.resize(cols * rows)
	_dist.resize(cols * rows)
	_passable.resize(cols * rows)


## Recomputes the field toward `target`. A flow cell is passable when the ink
## cell at its centre is not burnt.
func rebuild(grid: InkGrid, target: Vector2) -> void:
	for y in rows:
		var fy := mini(y * SCALE + SCALE / 2, grid.rows - 1)
		for x in cols:
			var fx := mini(x * SCALE + SCALE / 2, grid.cols - 1)
			_passable[y * cols + x] = 0 if grid.cells[fy * grid.cols + fx] == InkGrid.DEAD else 1
	_dist.fill(-1)
	var start := clampi(int(target.y / cell_size), 0, rows - 1) * cols + clampi(int(target.x / cell_size), 0, cols - 1)
	_dist[start] = 0
	var queue := PackedInt32Array([start])
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var x := index % cols
		var y := index / cols
		var next := _dist[index] + 1
		if x > 0 and _passable[index - 1] == 1 and _dist[index - 1] < 0:
			_dist[index - 1] = next
			queue.append(index - 1)
		if x < cols - 1 and _passable[index + 1] == 1 and _dist[index + 1] < 0:
			_dist[index + 1] = next
			queue.append(index + 1)
		if y > 0 and _passable[index - cols] == 1 and _dist[index - cols] < 0:
			_dist[index - cols] = next
			queue.append(index - cols)
		if y < rows - 1 and _passable[index + cols] == 1 and _dist[index + cols] < 0:
			_dist[index + cols] = next
			queue.append(index + cols)
	# Each cell points at its closest-to-target neighbour. Diagonals are only
	# allowed when both cells beside them are open, so nothing cuts a corner.
	for y in rows:
		for x in cols:
			var index := y * cols + x
			var best := _dist[index]
			var dir := Vector2.ZERO
			if best > 0:
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx := x + dx
						var ny := y + dy
						if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
							continue
						var n := ny * cols + nx
						if _dist[n] < 0 or _dist[n] >= best:
							continue
						if dx != 0 and dy != 0 and (_dist[y * cols + nx] < 0 or _dist[ny * cols + x] < 0):
							continue
						best = _dist[n]
						dir = Vector2(dx, dy)
			_dirs[index] = dir.normalized()
	ready = true


## Direction to walk from `pos`, or zero when the cell is cut off or at the target.
func direction(pos: Vector2) -> Vector2:
	return _dirs[clampi(int(pos.y / cell_size), 0, rows - 1) * cols + clampi(int(pos.x / cell_size), 0, cols - 1)]
