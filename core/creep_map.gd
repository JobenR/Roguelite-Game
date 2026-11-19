class_name CreepMap
extends RefCounted
## How a spawner's ink creeps across the page. The page is split into blocks
## of BLOCK x BLOCK ink cells; a search outward from the spawner (Dial's
## algorithm, so diagonals cost a little more and the front is round) gives
## each open block its travel cost and a list ordered by it. As the front
## radius grows, blocks are lit in that order. Walls stop it: a block that
## contains any wall cell is closed, and the front goes round.

const BLOCK := 2
const STRAIGHT := 10
const DIAGONAL := 14

var cols: int
var rows: int
var cell_px: float
var order: PackedInt32Array = PackedInt32Array()
var cost: PackedInt32Array = PackedInt32Array()
var head: int = 0

var _bucket_head: PackedInt32Array = PackedInt32Array()
var _node_cell: PackedInt32Array = PackedInt32Array()
var _node_next: PackedInt32Array = PackedInt32Array()


func _init(grid: InkGrid, origin: Vector2) -> void:
	cols = int(ceil(float(grid.cols) / BLOCK))
	rows = int(ceil(float(grid.rows) / BLOCK))
	cell_px = grid.cell_size * BLOCK
	var open := PackedByteArray()
	open.resize(cols * rows)
	for by in rows:
		for bx in cols:
			var clear := 1
			for dy in BLOCK:
				for dx in BLOCK:
					var fx := bx * BLOCK + dx
					var fy := by * BLOCK + dy
					if fx < grid.cols and fy < grid.rows and grid.cells[fy * grid.cols + fx] == InkGrid.DEAD:
						clear = 0
			open[by * cols + bx] = clear
	var start := clampi(int(origin.y / cell_px), 0, rows - 1) * cols + clampi(int(origin.x / cell_px), 0, cols - 1)
	open[start] = 1
	var best := PackedInt32Array()
	best.resize(cols * rows)
	best.fill(0x7fffffff)
	_bucket_head.resize(DIAGONAL * (cols + rows) + 32)
	_bucket_head.fill(-1)
	best[start] = 0
	_push(0, start)
	for d in _bucket_head.size():
		var node := _bucket_head[d]
		while node != -1:
			var cell := _node_cell[node]
			node = _node_next[node]
			if best[cell] != d:
				continue
			order.append(cell)
			cost.append(d)
			var x := cell % cols
			var y := cell / cols
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
						continue
					var n := ny * cols + nx
					if open[n] == 0:
						continue
					if dx != 0 and dy != 0 and (open[y * cols + nx] == 0 or open[ny * cols + x] == 0):
						continue
					var next := d + (DIAGONAL if dx != 0 and dy != 0 else STRAIGHT)
					if next < best[n]:
						best[n] = next
						_push(next, n)
	_node_cell.clear()
	_node_next.clear()


func _push(bucket: int, cell: int) -> void:
	_node_cell.append(cell)
	_node_next.append(_bucket_head[bucket])
	_bucket_head[bucket] = _node_cell.size() - 1


## Lights every block the front has reached. Bare paper always turns to enemy
## ink; the player's clean ground turns with probability `bite`.
func advance(grid: InkGrid, radius: float, bite: float) -> void:
	var limit := int(radius / cell_px * STRAIGHT)
	while head < order.size() and cost[head] <= limit:
		var cell := order[head]
		head += 1
		var x0 := (cell % cols) * BLOCK
		var y0 := (cell / cols) * BLOCK
		for dy in BLOCK:
			for dx in BLOCK:
				var fx := x0 + dx
				var fy := y0 + dy
				if fx >= grid.cols or fy >= grid.rows:
					continue
				var index := fy * grid.cols + fx
				var state := grid.cells[index]
				if state == InkGrid.NEUTRAL or (state == InkGrid.INK and randf() < bite):
					grid.set_cell(index, InkGrid.SMUDGE)


## True once the front has covered everything it can reach.
func finished() -> bool:
	return head >= order.size()
