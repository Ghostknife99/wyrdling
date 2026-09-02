extends RefCounted

const CLIFF := 0
const GRASS := 1
const STAIRS := 2
const DIRT := 3
const WATER := 4
const TALL_GRASS := 5
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

	var cw := 8
	var ch := 6
	var cx: int = int(width / 2) - int(cw / 2)
	var cy: int = height - 4 - ch
	cx = clampi(cx, 4, width - cw - 4)
	cy = clampi(cy, 12, height - ch - 3)

	var opening := Vector2i(cx + int(cw / 2), cy)
	var start := Vector2i(cx + int(cw / 2), cy + int(ch / 2) + 1)

	for y in range(cy, cy + ch):
		for x in range(cx, cx + cw):
			if not _inner(x, y, width, height):
				continue
			if (x + y + floor_num) % 5 == 0:
				grid[y][x] = GRASS
			else:
				grid[y][x] = DIRT

	for x in range(cx, cx + cw):
		if _inner(x, cy + ch - 1, width, height):
			grid[cy + ch - 1][x] = FENCE
		if _inner(x, cy, width, height) and absi(x - opening.x) > 1:
			grid[cy][x] = FENCE
	for y in range(cy, cy + ch):
		if _inner(cx, y, width, height):
			grid[y][cx] = FENCE
		if _inner(cx + cw - 1, y, width, height):
			grid[y][cx + cw - 1] = FENCE
	grid[opening.y][opening.x] = DIRT
	if _inner(opening.x + 1, opening.y, width, height):
		grid[opening.y][opening.x + 1] = DIRT
	grid[start.y][start.x] = DIRT

	var stairs_x: int = int(width / 2) + rng.randi_range(-8, 8)
	stairs_x = clampi(stairs_x, 6, width - 7)
	var stairs := Vector2i(stairs_x, 4)

	var waypoints: Array[Vector2i] = [opening]
	var n_wp: int = rng.randi_range(3, 5)
	for i in n_wp:
		var t: float = float(i + 1) / float(n_wp + 1)
		var wy: int = int(lerpf(float(opening.y), float(stairs.y), t))
		var wx: int = int(lerpf(float(opening.x), float(stairs.x), t))
		var swing: int = rng.randi_range(6, 14)
		if i % 2 == 0:
			wx += swing
		else:
			wx -= swing
		wx = clampi(wx, 5, width - 6)
		wy = clampi(wy, 5, opening.y - 2)
		waypoints.append(Vector2i(wx, wy))
	waypoints.append(stairs)

	for i in range(1, waypoints.size()):
		_carve_dirt_path(grid, width, height, waypoints[i - 1], waypoints[i], rng)

	_stamp_dirt(grid, width, height, stairs.x, stairs.y, 1)
	_stamp_dirt(grid, width, height, opening.x, opening.y, 1)

	_place_tall_grass(grid, width, height, rng)
	_place_water(grid, width, height, start, stairs, rng)
	_place_trees(grid, width, height, start, stairs, rng)

	grid[stairs.y][stairs.x] = STAIRS
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var np: Vector2i = stairs + d
		if _inner(np.x, np.y, width, height):
			var nt: int = int(grid[np.y][np.x])
			if nt == CLIFF or nt == TREE or nt == WATER or nt == FENCE:
				grid[np.y][np.x] = DIRT

	if int(grid[start.y][start.x]) != DIRT and int(grid[start.y][start.x]) != GRASS:
		grid[start.y][start.x] = DIRT

	var wild_count: int = rng.randi_range(4, 6)
	if floor_num >= 2:
		wild_count = rng.randi_range(6, 8)

	var spots: Array[Vector2i] = []
	for y in height:
		for x in width:
			if int(grid[y][x]) != TALL_GRASS:
				continue
			var p := Vector2i(x, y)
			if p == stairs or p == start:
				continue
			if p.distance_to(start) > 3:
				spots.append(p)

	if spots.size() < wild_count:
		for y in height:
			for x in width:
				if int(grid[y][x]) != GRASS:
					continue
				var p := Vector2i(x, y)
				if p == stairs or p.distance_to(start) <= 3:
					continue
				spots.append(p)

	var wilds: Array[Vector2i] = []
	while wilds.size() < wild_count and spots.size() > 0:
		var idx: int = rng.randi_range(0, spots.size() - 1)
		var p: Vector2i = spots[idx]
		spots.remove_at(idx)
		if p == stairs or p == start:
			continue
		wilds.append(p)

	var tree_list: Array[Vector2i] = []
	var fence_list: Array = []
	for y in height:
		for x in width:
			var t: int = int(grid[y][x])
			if t == TREE:
				tree_list.append(Vector2i(x, y))
			elif t == FENCE:
				fence_list.append({"pos": Vector2i(x, y), "kind": "post"})

	return {
		"grid": grid,
		"start": start,
		"stairs": stairs,
		"wilds": wilds,
		"trees": tree_list,
		"fence": fence_list,
	}


static func _inner(x: int, y: int, width: int, height: int) -> bool:
	return x >= 2 and y >= 2 and x < width - 2 and y < height - 2


static func _carve_dirt_path(grid: Array, width: int, height: int, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var x: int = a.x
	var y: int = a.y
	var horiz_first: bool = rng.randi() % 2 == 0
	var extra: int = rng.randi_range(0, 1)
	_stamp_dirt(grid, width, height, x, y, extra)
	var guard := 0
	while (x != b.x or y != b.y) and guard < 400:
		guard += 1
		if rng.randf() < 0.08 and absi(x - b.x) > 2 and absi(y - b.y) > 2:
			var jog: int = rng.randi_range(-2, 2)
			if horiz_first:
				y = clampi(y + jog, 4, height - 5)
			else:
				x = clampi(x + jog, 4, width - 5)
			_stamp_dirt(grid, width, height, x, y, extra)
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
		_stamp_dirt(grid, width, height, x, y, extra)


static func _stamp_dirt(grid: Array, width: int, height: int, x: int, y: int, extra: int) -> void:
	_try_dirt(grid, width, height, x, y)
	_try_dirt(grid, width, height, x + extra, y)
	_try_dirt(grid, width, height, x, y + extra)
	if extra == 0 and ((x + y) % 7 == 0):
		_try_dirt(grid, width, height, x + 1, y)


static func _try_dirt(grid: Array, width: int, height: int, x: int, y: int) -> void:
	if not _inner(x, y, width, height):
		return
	var t: int = int(grid[y][x])
	if t == FENCE or t == STAIRS:
		return
	grid[y][x] = DIRT


static func _place_tall_grass(grid: Array, width: int, height: int, rng: RandomNumberGenerator) -> void:
	var dirt: Array[Vector2i] = []
	for y in height:
		for x in width:
			if int(grid[y][x]) == DIRT:
				dirt.append(Vector2i(x, y))
	if dirt.is_empty():
		return
	var blobs: int = rng.randi_range(6, 9)
	for _i in blobs:
		var origin: Vector2i = dirt[rng.randi_range(0, dirt.size() - 1)]
		var ox: int = origin.x + rng.randi_range(-4, 4)
		var oy: int = origin.y + rng.randi_range(-3, 3)
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
				grid[y][x] = TALL_GRASS


static func _place_water(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> void:
	var dirt: Array[Vector2i] = []
	for y in height:
		for x in width:
			if int(grid[y][x]) == DIRT:
				dirt.append(Vector2i(x, y))
	var placed := false
	for _attempt in 50:
		var origin: Vector2i = Vector2i(int(width / 2), int(height / 2))
		if dirt.size() > 0:
			origin = dirt[rng.randi_range(0, dirt.size() - 1)]
		var side: int = -1 if rng.randf() < 0.5 else 1
		var px: int = clampi(origin.x + side * rng.randi_range(4, 9), 6, width - 9)
		var py: int = clampi(origin.y + rng.randi_range(-2, 2), 10, height - 16)
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
				if t == DIRT or t == FENCE or t == STAIRS:
					blocked = true
					break
				var p := Vector2i(x, y)
				if p == start or p.distance_to(start) <= 2 or p == stairs:
					blocked = true
					break
				if t == GRASS or t == TALL_GRASS:
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
		var fx: int = clampi(width - 12, 6, width - 8)
		var fy: int = 14
		for y in range(fy, fy + 4):
			for x in range(fx, fx + 5):
				if _inner(x, y, width, height) and int(grid[y][x]) == GRASS:
					grid[y][x] = WATER


static func _place_trees(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> void:
	# Woods along the inner cliff so the border reads as trees, not a wall.
	for x in range(2, width - 2):
		if int(grid[2][x]) == GRASS and rng.randf() < 0.7:
			grid[2][x] = TREE
		if int(grid[height - 3][x]) == GRASS and rng.randf() < 0.4:
			if Vector2i(x, height - 3).distance_to(start) > 4:
				grid[height - 3][x] = TREE
	for y in range(2, height - 2):
		if int(grid[y][2]) == GRASS and rng.randf() < 0.6:
			grid[y][2] = TREE
		if int(grid[y][width - 3]) == GRASS and rng.randf() < 0.6:
			grid[y][width - 3] = TREE

	# Groves 2–4 tiles off the dirt path so they show while walking the route.
	var dirt: Array[Vector2i] = []
	for y in height:
		for x in width:
			if int(grid[y][x]) == DIRT:
				dirt.append(Vector2i(x, y))
	var planted := 0
	var attempts := 0
	while planted < 28 and attempts < 220 and dirt.size() > 0:
		attempts += 1
		var origin: Vector2i = dirt[rng.randi_range(0, dirt.size() - 1)]
		var side: int = -1 if rng.randf() < 0.5 else 1
		var tx: int = origin.x + side * rng.randi_range(2, 4)
		var ty: int = origin.y + rng.randi_range(-2, 2)
		if not _inner(tx, ty, width, height):
			continue
		if int(grid[ty][tx]) != GRASS:
			continue
		var p := Vector2i(tx, ty)
		if p == start or p == stairs or p.distance_to(start) <= 2 or p.distance_to(stairs) <= 1:
			continue
		grid[ty][tx] = TREE
		planted += 1
		# small cluster
		for _k in rng.randi_range(1, 3):
			var nx: int = tx + rng.randi_range(-1, 1)
			var ny: int = ty + rng.randi_range(-1, 1)
			if _inner(nx, ny, width, height) and int(grid[ny][nx]) == GRASS:
				if Vector2i(nx, ny).distance_to(start) > 2:
					grid[ny][nx] = TREE
					planted += 1

	# Trees beside water so a pond shot always has canopy.
	for y in height:
		for x in width:
			if int(grid[y][x]) != WATER:
				continue
			for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 1), Vector2i(-2, 1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if _inner(nx, ny, width, height) and int(grid[ny][nx]) == GRASS and rng.randf() < 0.45:
					grid[ny][nx] = TREE
