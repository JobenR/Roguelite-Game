class_name SpatialGrid
extends RefCounted
## Uniform grid over the arena for cheap circle-overlap queries.
## Rebuilt every frame: clear(), insert() each item, then query().

var cell_size: float
var cols: int
var rows: int
var _cells: Array = []
var _used: PackedInt32Array = PackedInt32Array()


func _init(area_size: Vector2, p_cell_size: float) -> void:
	cell_size = p_cell_size
	cols = maxi(1, int(ceil(area_size.x / cell_size)))
	rows = maxi(1, int(ceil(area_size.y / cell_size)))
	_cells.resize(cols * rows)
	for i in _cells.size():
		_cells[i] = []


func clear() -> void:
	for c in _used:
		_cells[c].clear()
	_used.clear()


func insert(item: Object, pos: Vector2) -> void:
	var cx := clampi(int(pos.x / cell_size), 0, cols - 1)
	var cy := clampi(int(pos.y / cell_size), 0, rows - 1)
	var c := cy * cols + cx
	var cell: Array = _cells[c]
	if cell.is_empty():
		_used.append(c)
	cell.append(item)


## Fills `out` with every item whose cell touches the circle. Callers still
## need an exact distance check.
func query(pos: Vector2, radius: float, out: Array) -> void:
	out.clear()
	var x0 := clampi(int((pos.x - radius) / cell_size), 0, cols - 1)
	var x1 := clampi(int((pos.x + radius) / cell_size), 0, cols - 1)
	var y0 := clampi(int((pos.y - radius) / cell_size), 0, rows - 1)
	var y1 := clampi(int((pos.y + radius) / cell_size), 0, rows - 1)
	for y in range(y0, y1 + 1):
		var row := y * cols
		for x in range(x0, x1 + 1):
			var cell: Array = _cells[row + x]
			if not cell.is_empty():
				out.append_array(cell)
