extends RefCounted

const CLIFF := 0
const GRASS := 1
const STAIRS := 2
const DIRT := 3
const PATH := 3
const WATER := 4
const TALL_GRASS := 5
const TALLGRASS := 5
const TREE := 6
const FENCE := 7


static func generate(width: int, height: int, floor_num: int, rng: RandomNumberGenerator) -> Dictionary:
	var grid: Array = []
	for y in height:
		var row: Array = []
		row.resize(width)
		row.fill(GRASS)
		grid.append(row)

	for y in height:
		for x in width:
			if x < 2 or y < 2 or x >= width - 2 or y >= height - 2:
				grid[y][x] = CLIFF

	var cw := 9
	var ch := 7
	var cx: int = int(width / 2) - int(cw / 2)
	var cy: int = height - 5 - ch
	cx = clampi(cx, 4, width - cw - 4)
	cy = clampi(cy, 12, height - ch - 5)

	var opening := Vector2i(cx + int(cw / 2), cy)
	var start := Vector2i(cx + int(cw / 2), cy + int(ch / 2))

	for y in range(cy, cy + ch):
		for x in range(cx, cx + cw):
			if not _inner(x, y, width, height):
				continue
			if (x + y + floor_num) % 4 == 0:
				grid[y][x] = GRASS
			else:
				grid[y][x] = DIRT

	var fence: Array = []
	var south_y: int = cy + ch - 1
	var east_x: int = cx + cw - 1
	_stamp_fence(grid, fence, Vector2i(cx, cy), width, height, "nw")
	_stamp_fence(grid, fence, Vector2i(east_x, cy), width, height, "ne")
	_stamp_fence(grid, fence, Vector2i(cx, south_y), width, height, "sw")
	_stamp_fence(grid, fence, Vector2i(east_x, south_y), width, height, "se")
	for y in range(cy + 1, south_y):
		_stamp_fence(grid, fence, Vector2i(cx, y), width, height, "v")
		_stamp_fence(grid, fence, Vector2i(east_x, y), width, height, "v")
	for x in range(cx + 1, east_x):
		_stamp_fence(grid, fence, Vector2i(x, south_y), width, height, "h")
		if x != opening.x and absi(x - opening.x) > 1:
			_stamp_fence(grid, fence, Vector2i(x, cy), width, height, "h")

	grid[start.y][start.x] = DIRT
	grid[opening.y][opening.x] = DIRT
	if _inner(opening.x - 1, opening.y, width, height):
		grid[opening.y][opening.x - 1] = DIRT
	if _inner(opening.x + 1, opening.y, width, height):
		grid[opening.y][opening.x + 1] = DIRT

	var stairs_x: int = int(width / 2) + rng.randi_range(-10, 10)
	stairs_x = clampi(stairs_x, 8, width - 9)
	var stairs := Vector2i(stairs_x, 5)

	var waypoints: Array[Vector2i] = [opening]
	var n_wp: int = rng.randi_range(3, 5)
	for i in n_wp:
		var t: float = float(i + 1) / float(n_wp + 1)
		var wy: int = int(lerpf(float(opening.y), float(stairs.y), t))
		var wx: int = int(lerpf(float(opening.x), float(stairs.x), t))
		var swing: int = rng.randi_range(7, 16)
		if i % 2 == 0:
			wx += swing
		else:
			wx -= swing
		wx = clampi(wx, 6, width - 7)
		wy = clampi(wy, stairs.y + 2, opening.y - 2)
		waypoints.append(Vector2i(wx, wy))
	waypoints.append(stairs)

	for i in range(1, waypoints.size()):
		_carve_path(grid, width, height, waypoints[i - 1], waypoints[i], rng)

	_stamp_path(grid, width, height, stairs.x, stairs.y, 1)
	_stamp_path(grid, width, height, opening.x, opening.y, 1)

	_place_tallgrass(grid, width, height, rng)
	_place_water(grid, width, height, start, stairs, rng)

	var trees: Array[Vector2i] = []
	_place_trees(grid, width, height, start, stairs, trees, rng)

	grid[stairs.y][stairs.x] = STAIRS
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var np: Vector2i = stairs + d
		if not _inner(np.x, np.y, width, height):
			continue
		var nt: int = int(grid[np.y][np.x])
		if nt == CLIFF or nt == WATER or nt == TREE or nt == FENCE:
			grid[np.y][np.x] = DIRT

	var st: int = int(grid[start.y][start.x])
	if st != DIRT and st != GRASS and st != TALLGRASS:
		grid[start.y][start.x] = DIRT

	_ensure_path(grid, width, height, start)
	_ensure_water(grid, width, height, start, stairs)
	_ensure_tallgrass(grid, width, height, start, stairs, trees)

	var wild_count: int = rng.randi_range(4, 6)
	if floor_num >= 2:
		wild_count = rng.randi_range(6, 8)

	var spots: Array[Vector2i] = []
	for y in height:
		for x in width:
			if int(grid[y][x]) != TALLGRASS:
				continue
			var p := Vector2i(x, y)
			if p == stairs or p == start:
				continue
			if p.distance_to(start) <= 3:
				continue
			if _blocked_prop(p, trees):
				continue
			spots.append(p)

	if spots.size() < wild_count:
		for y in height:
			for x in width:
				if int(grid[y][x]) != GRASS:
					continue
				var p := Vector2i(x, y)
				if p == stairs or p.distance_to(start) <= 3:
					continue
				if _blocked_prop(p, trees):
					continue
				grid[y][x] = TALLGRASS
				spots.append(p)
				if spots.size() >= 48:
					break
			if spots.size() >= 48:
				break

	var wilds: Array[Vector2i] = []
	while wilds.size() < wild_count and spots.size() > 0:
		var idx: int = rng.randi_range(0, spots.size() - 1)
		var p: Vector2i = spots[idx]
		spots.remove_at(idx)
		if p == stairs or p == start:
			continue
		if _blocked_prop(p, trees):
			continue
		if int(grid[p.y][p.x]) == TREE or int(grid[p.y][p.x]) == FENCE:
			continue
		var taken := false
		for other in wilds:
			if other == p:
				taken = true
				break
		if taken:
			continue
		wilds.append(p)

	return {
		"grid": grid,
		"start": start,
		"stairs": stairs,
		"wilds": wilds,
		"trees": trees,
		"fence": fence,
	}


static func _inner(x: int, y: int, width: int, height: int) -> bool:
	return x >= 2 and y >= 2 and x < width - 2 and y < height - 2


static func _stamp_fence(grid: Array, fence: Array, pos: Vector2i, width: int, height: int, kind: String = "post") -> void:
	if not _inner(pos.x, pos.y, width, height):
		return
	grid[pos.y][pos.x] = FENCE
	for f in fence:
		if f["pos"] == pos:
			return
	fence.append({"pos": pos, "kind": kind})


static func _blocked_prop(p: Vector2i, trees: Array) -> bool:
	for nw in trees:
		var tpos: Vector2i = nw
		if p.x >= tpos.x and p.x <= tpos.x + 1 and p.y >= tpos.y and p.y <= tpos.y + 1:
			return true
	return false


static func _carve_path(grid: Array, width: int, height: int, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var x: int = a.x
	var y: int = a.y
	var horiz_first: bool = rng.randi() % 2 == 0
	var extra: int = rng.randi_range(0, 1)
	_stamp_path(grid, width, height, x, y, extra)
	var guard := 0
	while (x != b.x or y != b.y) and guard < 500:
		guard += 1
		if rng.randf() < 0.08 and absi(x - b.x) > 2 and absi(y - b.y) > 2:
			var jog: int = rng.randi_range(-2, 2)
			if horiz_first:
				y = clampi(y + jog, 4, height - 5)
			else:
				x = clampi(x, 4, width - 5)
				x = clampi(x + jog, 4, width - 5)
			_stamp_path(grid, width, height, x, y, extra)
			continue
		if horiz_first:
			if x != b.x:
				x += 1 if b.x > x else -1
			elif y != b.y:
				y += 1 if b.y > y else -1
		else:
			if y != b.y:
				y += 1 if b.y > y else -1
			elif x != b.x:
				x += 1 if b.x > x else -1
		_stamp_path(grid, width, height, x, y, extra)


static func _stamp_path(grid: Array, width: int, height: int, x: int, y: int, extra: int) -> void:
	_try_path(grid, width, height, x, y)
	_try_path(grid, width, height, x + extra, y)
	_try_path(grid, width, height, x, y + extra)
	if extra == 0 and ((x + y) % 7 == 0):
		_try_path(grid, width, height, x + 1, y)


static func _try_path(grid: Array, width: int, height: int, x: int, y: int) -> void:
	if not _inner(x, y, width, height):
		return
	var t: int = int(grid[y][x])
	if t == STAIRS or t == CLIFF or t == FENCE or t == TREE:
		return
	grid[y][x] = DIRT


static func _place_tallgrass(grid: Array, width: int, height: int, rng: RandomNumberGenerator) -> void:
	var path_cells: Array[Vector2i] = []
	for y in height:
		for x in width:
			if int(grid[y][x]) == DIRT:
				path_cells.append(Vector2i(x, y))
	if path_cells.is_empty():
		return
	var blobs: int = rng.randi_range(7, 10)
	for _i in blobs:
		var origin: Vector2i = path_cells[rng.randi_range(0, path_cells.size() - 1)]
		var ox: int = origin.x + rng.randi_range(-5, 5)
		var oy: int = origin.y + rng.randi_range(-4, 4)
		var bw: int = rng.randi_range(3, 6)
		var bh: int = rng.randi_range(3, 4)
		for y in range(oy, oy + bh):
			for x in range(ox, ox + bw):
				if not _inner(x, y, width, height):
					continue
				if int(grid[y][x]) != GRASS:
					continue
				if x == ox or y == oy or x == ox + bw - 1 or y == oy + bh - 1:
					if rng.randf() < 0.35:
						continue
				grid[y][x] = TALLGRASS


static func _place_water(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> void:
	var path_cells: Array[Vector2i] = []
	for y in height:
		for x in width:
			if int(grid[y][x]) == DIRT:
				path_cells.append(Vector2i(x, y))
	var placed := false
	for _attempt in 60:
		var origin: Vector2i
		if path_cells.size() > 0:
			origin = path_cells[rng.randi_range(0, path_cells.size() - 1)]
		else:
			origin = Vector2i(int(width / 2), int(height / 2))
		var side: int = -1 if rng.randf() < 0.5 else 1
		var px: int = clampi(origin.x + side * rng.randi_range(4, 10), 6, width - 10)
		var py: int = clampi(origin.y + rng.randi_range(-3, 3), 10, height - 16)
		var pw: int = rng.randi_range(5, 8)
		var ph: int = rng.randi_range(4, 6)
		var cx: float = float(px) + float(pw) / 2.0
		var cy: float = float(py) + float(ph) / 2.0
		var rx: float = float(pw) / 2.0
		var ry: float = float(ph) / 2.0
		var cells: Array[Vector2i] = []
		var blocked := false
		for y in range(py, py + ph):
			for x in range(px, px + pw):
				if not _inner(x, y, width, height):
					continue
				var nx: float = (float(x) + 0.5 - cx) / rx
				var ny: float = (float(y) + 0.5 - cy) / ry
				if nx * nx + ny * ny > 1.0:
					continue
				var t: int = int(grid[y][x])
				if t == DIRT or t == STAIRS or t == CLIFF or t == FENCE or t == TREE:
					blocked = true
					break
				var p := Vector2i(x, y)
				if p == start or p == stairs or p.distance_to(start) <= 2:
					blocked = true
					break
				if t == GRASS or t == TALLGRASS:
					cells.append(p)
			if blocked:
				break
		if blocked or cells.size() < 8:
			continue
		for p in cells:
			grid[p.y][p.x] = WATER
		placed = true
		break
	if not placed:
		_ensure_water(grid, width, height, start, stairs)


static func _ensure_path(grid: Array, width: int, height: int, start: Vector2i) -> void:
	for y in height:
		for x in width:
			if int(grid[y][x]) == DIRT:
				return
	if _inner(start.x, start.y, width, height):
		grid[start.y][start.x] = DIRT


static func _ensure_water(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i) -> void:
	for y in height:
		for x in width:
			if int(grid[y][x]) == WATER:
				return
	var fx: int = clampi(width - 14, 6, width - 10)
	var fy: int = 16
	for y in range(fy, fy + 4):
		for x in range(fx, fx + 5):
			if not _inner(x, y, width, height):
				continue
			var p := Vector2i(x, y)
			if p == start or p == stairs:
				continue
			var t: int = int(grid[y][x])
			if t == GRASS or t == TALLGRASS:
				grid[y][x] = WATER


static func _ensure_tallgrass(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, trees: Array) -> void:
	for y in height:
		for x in width:
			if int(grid[y][x]) == TALLGRASS:
				return
	var ox: int = clampi(start.x - 2, 4, width - 10)
	var oy: int = clampi(start.y - 10, 8, height - 12)
	for y in range(oy, oy + 4):
		for x in range(ox, ox + 5):
			if not _inner(x, y, width, height):
				continue
			var p := Vector2i(x, y)
			if p == start or p == stairs or _blocked_prop(p, trees):
				continue
			if int(grid[y][x]) == GRASS:
				grid[y][x] = TALLGRASS


static func _place_trees(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, trees: Array, rng: RandomNumberGenerator) -> void:
	# Woods belt just inside the 2-tile cliff (2x2 canopy).
	for x in range(2, width - 3, 2):
		_try_tree(grid, width, height, Vector2i(x, 2), start, stairs, trees)
		if Vector2i(x, height - 4).distance_to(start) > 4:
			_try_tree(grid, width, height, Vector2i(x, height - 4), start, stairs, trees)
	for y in range(4, height - 6, 3):
		_try_tree(grid, width, height, Vector2i(2, y), start, stairs, trees)
		_try_tree(grid, width, height, Vector2i(width - 4, y), start, stairs, trees)

	var groves: int = rng.randi_range(6, 9)
	for _i in groves:
		var gx: int = rng.randi_range(8, width - 10)
		var gy: int = rng.randi_range(8, height - 12)
		var n: int = rng.randi_range(3, 7)
		for _k in n:
			var tx: int = gx + rng.randi_range(-3, 3)
			var ty: int = gy + rng.randi_range(-2, 2)
			_try_tree(grid, width, height, Vector2i(tx, ty), start, stairs, trees)

	# Trees beside water so a pond shot always has canopy.
	for y in height:
		for x in width:
			if int(grid[y][x]) != WATER:
				continue
			for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 1), Vector2i(-2, 1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if rng.randf() < 0.4:
					_try_tree(grid, width, height, Vector2i(nx, ny), start, stairs, trees)


static func _try_tree(grid: Array, width: int, height: int, nw: Vector2i, start: Vector2i, stairs: Vector2i, trees: Array) -> void:
	if not _inner(nw.x, nw.y, width, height) or not _inner(nw.x + 1, nw.y + 1, width, height):
		return
	for existing in trees:
		var ex: Vector2i = existing
		if absi(ex.x - nw.x) < 2 and absi(ex.y - nw.y) < 2:
			return
	for dy in range(0, 2):
		for dx in range(0, 2):
			var p := Vector2i(nw.x + dx, nw.y + dy)
			if not _inner(p.x, p.y, width, height):
				return
			var t: int = int(grid[p.y][p.x])
			if t != GRASS:
				return
			if p == start or p == stairs:
				return
			if p.distance_to(start) <= 2 or p.distance_to(stairs) <= 1:
				return
	for dy in range(0, 2):
		for dx in range(0, 2):
			grid[nw.y + dy][nw.x + dx] = TREE
	trees.append(nw)
