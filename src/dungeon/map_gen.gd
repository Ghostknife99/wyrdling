extends RefCounted

const WALL := 0
const FLOOR := 1
const STAIRS := 2


static func generate(width: int, height: int, floor_num: int, rng: RandomNumberGenerator) -> Dictionary:
	var grid: Array = []
	for y in height:
		var row: Array = []
		row.resize(width)
		row.fill(WALL)
		grid.append(row)

	var target_rooms: int = rng.randi_range(5, 7)
	if floor_num >= 2:
		target_rooms = rng.randi_range(6, 9)
	var rooms: Array[Rect2i] = []
	var attempts := 0
	while rooms.size() < target_rooms and attempts < 120:
		attempts += 1
		var rw: int = rng.randi_range(4, 8)
		var rh: int = rng.randi_range(3, 6)
		if floor_num >= 2:
			rw = rng.randi_range(3, 7)
			rh = rng.randi_range(3, 5)
		var rx: int = rng.randi_range(1, width - rw - 2)
		var ry: int = rng.randi_range(1, height - rh - 2)
		var rect := Rect2i(rx, ry, rw, rh)
		var ok := true
		for other in rooms:
			if rect.grow(1).intersects(other):
				ok = false
				break
		if not ok:
			continue
		rooms.append(rect)
		for y in range(ry, ry + rh):
			for x in range(rx, rx + rw):
				grid[y][x] = FLOOR

	if rooms.is_empty():
		var fallback := Rect2i(2, 2, width - 4, height - 4)
		rooms.append(fallback)
		for y in range(fallback.position.y, fallback.position.y + fallback.size.y):
			for x in range(fallback.position.x, fallback.position.x + fallback.size.x):
				grid[y][x] = FLOOR

	for i in range(1, rooms.size()):
		var a: Vector2i = rooms[i - 1].get_center()
		var b: Vector2i = rooms[i].get_center()
		_carve_corridor(grid, width, height, a, b, rng)

	var start: Vector2i = rooms[0].get_center()
	var end_room: Rect2i = rooms[rooms.size() - 1]
	var stairs: Vector2i = end_room.get_center()
	if stairs == start:
		stairs = Vector2i(end_room.position.x + 1, end_room.position.y + 1)
	grid[stairs.y][stairs.x] = STAIRS

	var wild_count: int = rng.randi_range(4, 6)
	if floor_num >= 2:
		wild_count = rng.randi_range(6, 8)

	var floor_tiles: Array[Vector2i] = []
	for y in height:
		for x in width:
			if grid[y][x] == FLOOR:
				var p := Vector2i(x, y)
				if p.distance_to(start) > 3:
					floor_tiles.append(p)

	var wilds: Array[Vector2i] = []
	while wilds.size() < wild_count and floor_tiles.size() > 0:
		var idx: int = rng.randi_range(0, floor_tiles.size() - 1)
		var p: Vector2i = floor_tiles[idx]
		floor_tiles.remove_at(idx)
		if p == stairs:
			continue
		wilds.append(p)

	return {
		"grid": grid,
		"start": start,
		"stairs": stairs,
		"wilds": wilds,
		"rooms": rooms,
	}


static func _carve_corridor(grid: Array, width: int, height: int, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var x: int = a.x
	var y: int = a.y
	var h_first: bool = rng.randi() % 2 == 0
	if h_first:
		while x != b.x:
			x += 1 if b.x > x else -1
			_carve(grid, width, height, x, y)
		while y != b.y:
			y += 1 if b.y > y else -1
			_carve(grid, width, height, x, y)
	else:
		while y != b.y:
			y += 1 if b.y > y else -1
			_carve(grid, width, height, x, y)
		while x != b.x:
			x += 1 if b.x > x else -1
			_carve(grid, width, height, x, y)


static func _carve(grid: Array, width: int, height: int, x: int, y: int) -> void:
	if x <= 0 or y <= 0 or x >= width - 1 or y >= height - 1:
		return
	if grid[y][x] != STAIRS:
		grid[y][x] = FLOOR
