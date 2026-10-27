class_name NavGrid
extends RefCounted
## Grid-based A* walkability for the office floor (0.5 m cells).
## Furniture registers its footprint while the office is being built, which
## keeps navigation deterministic and free of runtime baking.

var cell := 0.5

var origin := Vector2(-15.0, -10.0)
var cols := 60
var rows := 36
var astar := AStarGrid2D.new()


func _init() -> void:
	_setup()


## Re-dimensions the grid (the diorama room is smaller and finer than the 3D office).
func configure(new_origin: Vector2, new_cols: int, new_rows: int, new_cell: float) -> void:
	origin = new_origin
	cols = new_cols
	rows = new_rows
	cell = new_cell
	astar = AStarGrid2D.new()
	_setup()


func _setup() -> void:
	astar.region = Rect2i(0, 0, cols, rows)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()


func to_cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor((p.x - origin.x) / cell)), int(floor((p.z - origin.y) / cell)))


func to_world(c: Vector2i) -> Vector3:
	return Vector3(origin.x + (c.x + 0.5) * cell, 0.0, origin.y + (c.y + 0.5) * cell)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func is_free(c: Vector2i) -> bool:
	return in_bounds(c) and not astar.is_point_solid(c)


## Blocks an axis-aligned rectangle (centre + size on the XZ plane).
func block_rect(center: Vector3, size: Vector2, pad := 0.1) -> void:
	_set_rect(center, size, pad, true)


func unblock_rect(center: Vector3, size: Vector2) -> void:
	_set_rect(center, size, 0.0, false)


func _set_rect(center: Vector3, size: Vector2, pad: float, solid: bool) -> void:
	var min_c := to_cell(Vector3(center.x - size.x * 0.5 - pad + 0.01, 0, center.z - size.y * 0.5 - pad + 0.01))
	var max_c := to_cell(Vector3(center.x + size.x * 0.5 + pad - 0.01, 0, center.z + size.y * 0.5 + pad - 0.01))
	for y in range(min_c.y, max_c.y + 1):
		for x in range(min_c.x, max_c.x + 1):
			var c := Vector2i(x, y)
			if in_bounds(c):
				astar.set_point_solid(c, solid)


## Nearest walkable cell to `c` (breadth-first search).
func nearest_free(c: Vector2i) -> Vector2i:
	c = Vector2i(clampi(c.x, 0, cols - 1), clampi(c.y, 0, rows - 1))
	if is_free(c):
		return c
	var seen := {c: true}
	var queue: Array[Vector2i] = [c]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in dirs:
			var n: Vector2i = cur + d
			if seen.has(n) or not in_bounds(n):
				continue
			if not astar.is_point_solid(n):
				return n
			seen[n] = true
			queue.append(n)
	return c


## World-space path from `from` to `to`, string-pulled for natural movement.
func find_path(from: Vector3, to: Vector3) -> Array:
	var a := nearest_free(to_cell(from))
	var b := nearest_free(to_cell(to))
	var ids := astar.get_id_path(a, b)
	var pts: Array = []
	for c in ids:
		pts.append(to_world(c))
	if pts.is_empty():
		return pts
	# land exactly on the requested point if it is walkable
	if is_free(to_cell(to)):
		pts[pts.size() - 1] = Vector3(to.x, 0.0, to.z)
	return _smooth(from, pts)


func _smooth(from: Vector3, pts: Array) -> Array:
	var out: Array = []
	var anchor := from
	var i := 0
	while i < pts.size():
		var j := pts.size() - 1
		while j > i and not _line_clear(anchor, pts[j]):
			j -= 1
		out.append(pts[j])
		anchor = pts[j]
		i = j + 1
	return out


func _line_clear(a: Vector3, b: Vector3) -> bool:
	var dist := Vector2(b.x - a.x, b.z - a.z).length()
	var steps := int(dist / (cell * 0.35)) + 1
	for s in steps + 1:
		var p: Vector3 = a.lerp(b, float(s) / steps)
		# check a little either side so characters don't clip corners
		for off in [Vector3.ZERO, Vector3(0.18, 0, 0), Vector3(-0.18, 0, 0), Vector3(0, 0, 0.18), Vector3(0, 0, -0.18)]:
			if not is_free(to_cell(p + off)):
				return false
	return true
