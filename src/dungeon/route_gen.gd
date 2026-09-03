extends RefCounted

const CLIFF: int = 0
const GRASS: int = 1
const STAIRS: int = 2
const DIRT: int = 3
const WATER: int = 4
const TALLGRASS: int = 5
const TREE: int = 6
const FENCE: int = 7

const AREA_NAMES: Array[String] = [
	"Willowmere Route",
	"Mosslight Trail",
	"Cinderleaf Way",
	"Silverfen Path",
	"Briarwater Road",
	"Lanternwood Reach",
	"Windglass Route",
	"Riftbloom Trail",
]

const NPC_LINES: Array[String] = [
	"Tall grass is louder than it looks. If the reeds move twice, something is watching.",
	"The lodge keeper says the rift-gate changes the land each time someone passes through.",
	"I saw a Wyrdling drinking at the pond. It vanished the moment the water rippled.",
	"Caves near a rift carry strange echoes. Some delvers swear the echoes answer back.",
	"Keep a healthy Wyrdling ready. The wilds get meaner the farther you descend.",
	"These routes never stay exactly the same, but landmarks have a habit of returning.",
]


static func generate(width: int, height: int, floor_num: int, rng: RandomNumberGenerator) -> Dictionary:
	var grid: Array = []
	for y: int in height:
		var row: Array = []
		row.resize(width)
		row.fill(GRASS)
		grid.append(row)

	# A two-tile natural boundary frames each generated route.
	for y: int in height:
		for x: int in width:
			if x < 2 or y < 2 or x >= width - 2 or y >= height - 2:
				grid[y][x] = CLIFF

	var clearing_w: int = 11
	var clearing_h: int = 8
	var clearing_x: int = int(width / 2) - int(clearing_w / 2)
	var clearing_y: int = height - clearing_h - 4
	var opening: Vector2i = Vector2i(clearing_x + int(clearing_w / 2), clearing_y)
	var start: Vector2i = Vector2i(clearing_x + int(clearing_w / 2), clearing_y + clearing_h - 3)

	for y: int in range(clearing_y, clearing_y + clearing_h):
		for x: int in range(clearing_x, clearing_x + clearing_w):
			if _inner(x, y, width, height):
				grid[y][x] = DIRT

	var fence: Array = []
	_stamp_yard_fence(grid, fence, clearing_x, clearing_y, clearing_w, clearing_h, opening, width, height)
	grid[start.y][start.x] = DIRT

	var stairs_x: int = clampi(int(width / 2) + rng.randi_range(-9, 9), 8, width - 9)
	var stairs: Vector2i = Vector2i(stairs_x, 5)

	# The main route now follows one northbound cubic sweep. Y never reverses,
	# so the trail cannot fold back into itself and create the large dirt masses
	# produced by tightly alternating waypoint segments.
	_carve_main_trail(grid, width, height, opening, stairs, rng)
	_stamp_path(grid, width, height, stairs.x, stairs.y, 1)
	_stamp_path(grid, width, height, opening.x, opening.y, 1)

	_place_water(grid, width, height, start, stairs, rng)
	_place_tallgrass(grid, width, height, start, stairs, rng)

	var props: Array = []
	var blocked: Dictionary = {}
	_place_lodge(grid, props, blocked, clearing_x, clearing_y, clearing_w, clearing_h, start)
	var cave_info: Dictionary = _place_cave_branch(grid, props, blocked, width, height, start, stairs, rng)
	_place_signs(props, blocked, opening, cave_info, width, height)
	_place_npcs(grid, props, blocked, width, height, start, stairs, rng)
	_place_decor(grid, props, blocked, width, height, start, stairs, rng)

	var trees: Array[Vector2i] = []
	_place_trees(grid, width, height, start, stairs, blocked, trees, rng)

	grid[stairs.y][stairs.x] = STAIRS
	var stair_dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for d: Vector2i in stair_dirs:
		var near_stairs: Vector2i = stairs + d
		if _inner(near_stairs.x, near_stairs.y, width, height) and not blocked.has(near_stairs):
			var tile: int = int(grid[near_stairs.y][near_stairs.x])
			if tile == WATER or tile == TALLGRASS:
				grid[near_stairs.y][near_stairs.x] = DIRT

	_ensure_tallgrass(grid, width, height, start, stairs, blocked, trees)
	_ensure_water(grid, width, height, start, stairs, blocked)

	var wild_count: int = rng.randi_range(4, 6) if floor_num == 1 else rng.randi_range(6, 8)
	var spots: Array[Vector2i] = []
	for y: int in height:
		for x: int in width:
			var cell: Vector2i = Vector2i(x, y)
			if int(grid[y][x]) != TALLGRASS:
				continue
			if cell == start or cell == stairs or cell.distance_to(start) <= 3.0:
				continue
			if blocked.has(cell) or _blocked_tree_cell(cell, trees):
				continue
			spots.append(cell)

	var wilds: Array[Vector2i] = []
	while wilds.size() < wild_count and not spots.is_empty():
		var idx: int = rng.randi_range(0, spots.size() - 1)
		var wild_pos: Vector2i = spots[idx]
		spots.remove_at(idx)
		if not wilds.has(wild_pos):
			wilds.append(wild_pos)

	return {
		"grid": grid,
		"start": start,
		"stairs": stairs,
		"wilds": wilds,
		"trees": trees,
		"fence": fence,
		"props": props,
		"area_name": AREA_NAMES[(floor_num - 1) % AREA_NAMES.size()],
	}


static func _inner(x: int, y: int, width: int, height: int) -> bool:
	return x >= 2 and y >= 2 and x < width - 2 and y < height - 2


static func _stamp_yard_fence(grid: Array, fence: Array, x0: int, y0: int, w: int, h: int, opening: Vector2i, width: int, height: int) -> void:
	var x1: int = x0 + w - 1
	var y1: int = y0 + h - 1
	for x: int in range(x0, x1 + 1):
		if x < opening.x - 1 or x > opening.x + 1:
			_stamp_fence(fence, Vector2i(x, y0), width, height, "h")
		_stamp_fence(fence, Vector2i(x, y1), width, height, "h")
	for y: int in range(y0, y1 + 1):
		_stamp_fence(fence, Vector2i(x0, y), width, height, "v")
		_stamp_fence(fence, Vector2i(x1, y), width, height, "v")
	_label_fences(fence)


static func _stamp_fence(fence: Array, pos: Vector2i, width: int, height: int, kind: String) -> void:
	if not _inner(pos.x, pos.y, width, height):
		return
	for f: Dictionary in fence:
		if f["pos"] == pos:
			return
	fence.append({"pos": pos, "kind": kind})


static func _label_fences(fence: Array) -> void:
	var occupied: Dictionary = {}
	for f: Dictionary in fence:
		occupied[f["pos"]] = true
	for f: Dictionary in fence:
		var p: Vector2i = f["pos"]
		var n: bool = occupied.has(p + Vector2i(0, -1))
		var s: bool = occupied.has(p + Vector2i(0, 1))
		var e: bool = occupied.has(p + Vector2i(1, 0))
		var w: bool = occupied.has(p + Vector2i(-1, 0))
		if e and s and not n and not w:
			f["kind"] = "nw"
		elif w and s and not n and not e:
			f["kind"] = "ne"
		elif e and n and not s and not w:
			f["kind"] = "sw"
		elif w and n and not s and not e:
			f["kind"] = "se"
		elif (e or w) and not (n or s):
			f["kind"] = "h"
		elif (n or s) and not (e or w):
			f["kind"] = "v"
		else:
			f["kind"] = "post"


static func _carve_main_trail(grid: Array, width: int, height: int, opening: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> void:
	var span_y: int = maxi(opening.y - stairs.y, 1)
	var midpoint: float = (float(opening.x) + float(stairs.x)) * 0.5
	var sweep_side: int = -1 if rng.randf() < 0.5 else 1
	var control_1: float = clampf(midpoint + float(sweep_side * rng.randi_range(8, 13)), 7.0, float(width - 8))
	var control_2: float = clampf(midpoint - float(sweep_side * rng.randi_range(6, 11)), 7.0, float(width - 8))
	if rng.randf() < 0.28:
		# Some routes make one long crescent instead of an S-bend.
		control_2 = clampf(midpoint + float(sweep_side * rng.randi_range(2, 7)), 7.0, float(width - 8))

	var phase: float = rng.randf_range(0.0, TAU)
	var p: Vector2i = opening
	var shoulder_side: int = -1 if rng.randf() < 0.5 else 1
	var next_shoulder_flip: int = rng.randi_range(6, 9)
	var step_index := 0

	for y: int in range(opening.y, stairs.y - 1, -1):
		var t: float = float(opening.y - y) / float(span_y)
		var u: float = 1.0 - t
		var curve_x: float = (
			u * u * u * float(opening.x)
			+ 3.0 * u * u * t * control_1
			+ 3.0 * u * t * t * control_2
			+ t * t * t * float(stairs.x)
		)
		curve_x += sin(t * TAU * 1.35 + phase) * 0.55
		var target_x: int = clampi(int(round(curve_x)), 6, width - 7)

		while p.x != target_x:
			var direction := Vector2i(signi(target_x - p.x), 0)
			_stamp_trail_cell(grid, width, height, p, direction, shoulder_side, step_index, rng)
			p += direction
			step_index += 1
			if step_index >= next_shoulder_flip:
				shoulder_side *= -1
				next_shoulder_flip += rng.randi_range(6, 9)

		if p.y > y:
			var direction := Vector2i(0, -1)
			_stamp_trail_cell(grid, width, height, p, direction, shoulder_side, step_index, rng)
			p += direction
			step_index += 1
			if step_index >= next_shoulder_flip:
				shoulder_side *= -1
				next_shoulder_flip += rng.randi_range(6, 9)

	_carve_path(grid, width, height, p, stairs, rng)


static func _carve_path(grid: Array, width: int, height: int, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var p: Vector2i = a
	var total_dx: int = maxi(absi(b.x - a.x), 1)
	var total_dy: int = maxi(absi(b.y - a.y), 1)
	var shoulder_side: int = -1 if rng.randf() < 0.5 else 1
	var next_shoulder_flip: int = rng.randi_range(6, 9)
	var step_index := 0
	var guard := 0

	while p != b and guard < 600:
		guard += 1
		var remain_x: int = absi(b.x - p.x)
		var remain_y: int = absi(b.y - p.y)
		var move_x := false
		if remain_y == 0:
			move_x = true
		elif remain_x == 0:
			move_x = false
		else:
			var x_pressure: float = float(remain_x) / float(total_dx)
			var y_pressure: float = float(remain_y) / float(total_dy)
			move_x = x_pressure + rng.randf_range(-0.06, 0.06) >= y_pressure

		var next := p
		if move_x:
			next.x += signi(b.x - p.x)
		else:
			next.y += signi(b.y - p.y)
		var direction: Vector2i = next - p

		_stamp_trail_cell(grid, width, height, p, direction, shoulder_side, step_index, rng)
		p = next
		step_index += 1
		if step_index >= next_shoulder_flip:
			shoulder_side *= -1
			next_shoulder_flip += rng.randi_range(6, 9)

	_stamp_trail_cell(grid, width, height, b, Vector2i(0, -1), shoulder_side, step_index, rng)


static func _stamp_trail_cell(grid: Array, width: int, height: int, p: Vector2i, direction: Vector2i, shoulder_side: int, step_index: int, rng: RandomNumberGenerator) -> void:
	_set_dirt(grid, width, height, p)
	if direction == Vector2i.ZERO:
		return

	var perpendicular := Vector2i(-direction.y, direction.x)
	# A broken shoulder gives mostly two-tile trail width, with frequent one-tile
	# pinches that make the edges read as walked ground rather than road paving.
	if step_index % 5 != 2 or rng.randf() < 0.18:
		_set_dirt(grid, width, height, p + perpendicular * shoulder_side)
	if step_index % 17 == 0 and rng.randf() < 0.32:
		_set_dirt(grid, width, height, p - perpendicular * shoulder_side)


static func _set_dirt(grid: Array, width: int, height: int, p: Vector2i) -> void:
	if not _inner(p.x, p.y, width, height):
		return
	if int(grid[p.y][p.x]) != CLIFF:
		grid[p.y][p.x] = DIRT


static func _stamp_path(grid: Array, width: int, height: int, x: int, y: int, radius: int) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			_set_dirt(grid, width, height, Vector2i(x + dx, y + dy))


static func _place_water(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> void:
	var centers: Array[Vector2i] = [
		Vector2i(clampi(start.x + 12, 9, width - 10), clampi(start.y - 17, 10, height - 12)),
		Vector2i(clampi(start.x - 14, 9, width - 10), clampi(start.y - 29, 9, height - 12)),
	]
	for ci: int in range(centers.size()):
		if ci == 1 and rng.randf() < 0.35:
			continue
		var c: Vector2i = centers[ci]
		var rx: int = rng.randi_range(3, 5)
		var ry: int = rng.randi_range(2, 4)
		for y: int in range(c.y - ry, c.y + ry + 1):
			for x: int in range(c.x - rx, c.x + rx + 1):
				if not _inner(x, y, width, height):
					continue
				var nx: float = float(x - c.x) / float(maxi(rx, 1))
				var ny: float = float(y - c.y) / float(maxi(ry, 1))
				if nx * nx + ny * ny > 1.05:
					continue
				var p: Vector2i = Vector2i(x, y)
				if p.distance_to(start) < 5.0 or p.distance_to(stairs) < 3.0:
					continue
				var tile: int = int(grid[y][x])
				if tile == GRASS or tile == TALLGRASS:
					grid[y][x] = WATER


static func _place_tallgrass(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> void:
	var path_cells: Array[Vector2i] = _cells_of(grid, DIRT)
	var patches: int = rng.randi_range(8, 11)
	for _i: int in patches:
		if path_cells.is_empty():
			break
		var anchor: Vector2i = path_cells[rng.randi_range(0, path_cells.size() - 1)]
		var side: int = -1 if rng.randf() < 0.5 else 1
		var ox: int = anchor.x + side * rng.randi_range(3, 6)
		var oy: int = anchor.y + rng.randi_range(-2, 2)
		var pw: int = rng.randi_range(4, 7)
		var ph: int = rng.randi_range(3, 5)
		for y: int in range(oy, oy + ph):
			for x: int in range(ox, ox + pw):
				if not _inner(x, y, width, height):
					continue
				var p: Vector2i = Vector2i(x, y)
				if p.distance_to(start) < 4.0 or p.distance_to(stairs) < 2.0:
					continue
				if int(grid[y][x]) == GRASS and (rng.randf() > 0.12 or (x + y) % 3 != 0):
					grid[y][x] = TALLGRASS


static func _place_lodge(grid: Array, props: Array, blocked: Dictionary, clearing_x: int, clearing_y: int, clearing_w: int, clearing_h: int, start: Vector2i) -> void:
	var pos: Vector2i = Vector2i(clearing_x + clearing_w - 5, clearing_y + 1)
	var blocks: Array[Vector2i] = []
	for y: int in range(pos.y, pos.y + 3):
		for x: int in range(pos.x, pos.x + 3):
			var p: Vector2i = Vector2i(x, y)
			if p == start:
				continue
			blocks.append(p)
			blocked[p] = true
			grid[y][x] = DIRT
	props.append({
		"kind": "lodge",
		"pos": pos,
		"blocks": blocks,
		"interact_pos": pos + Vector2i(1, 2),
		"name": "Riftkeeper Lodge",
		"text": "A warm lantern glows in the lodge window. Rest here to mend your party.",
	})


static func _place_cave_branch(grid: Array, props: Array, blocked: Dictionary, width: int, height: int, start: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var path_cells: Array[Vector2i] = _cells_of(grid, DIRT)
	var candidates: Array[Vector2i] = []
	for p: Vector2i in path_cells:
		if p.y < stairs.y + 8 or p.y > start.y - 10:
			continue
		candidates.append(p)
	if candidates.is_empty():
		return {}

	var anchor: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
	var side: int = -1 if anchor.x > int(width / 2) else 1
	if rng.randf() < 0.35:
		side *= -1
	var door: Vector2i = Vector2i(
		clampi(anchor.x + side * rng.randi_range(7, 10), 6, width - 7),
		clampi(anchor.y + rng.randi_range(-2, 2), 8, height - 11)
	)
	var pos: Vector2i = door + Vector2i(-1, -1)
	_carve_path(grid, width, height, anchor, door + Vector2i(0, 1), rng)

	var blocks: Array[Vector2i] = []
	for y: int in range(pos.y, pos.y + 2):
		for x: int in range(pos.x, pos.x + 3):
			var p: Vector2i = Vector2i(x, y)
			blocks.append(p)
			blocked[p] = true
			if int(grid[y][x]) != CLIFF:
				grid[y][x] = GRASS

	props.append({
		"kind": "cave",
		"pos": pos,
		"blocks": blocks,
		"interact_pos": door,
		"name": "Echo Cave",
		"text": "Cold air spills from Echo Cave. Riftstone inside hums with distant Wyrdling calls.",
	})
	return {"door": door, "anchor": anchor}


static func _place_signs(props: Array, blocked: Dictionary, opening: Vector2i, cave_info: Dictionary, width: int, height: int) -> void:
	var first: Vector2i = opening + Vector2i(2, -3)
	if _inner(first.x, first.y, width, height) and not blocked.has(first):
		_add_single_prop(props, blocked, "sign", first, "Route Marker", "North: rift-gate. Tall grass: wild Wyrdlings. Lodge: rest and regroup.")

	if cave_info.is_empty():
		return
	var anchor: Vector2i = cave_info["anchor"]
	var door: Vector2i = cave_info["door"]
	var delta: Vector2i = door - anchor
	var sign_pos: Vector2i = anchor + Vector2i(1 if delta.x < 0 else -1, 0)
	if _inner(sign_pos.x, sign_pos.y, width, height) and not blocked.has(sign_pos):
		_add_single_prop(props, blocked, "sign", sign_pos, "Weathered Sign", "Echo Cave lies off the main trail. The stone sings louder after dusk.")


static func _place_npcs(grid: Array, props: Array, blocked: Dictionary, width: int, height: int, start: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> void:
	var path_cells: Array[Vector2i] = _cells_of(grid, DIRT)
	var placed: int = 0
	var attempts: int = 0
	while placed < 3 and attempts < 120:
		attempts += 1
		if path_cells.is_empty():
			break
		var anchor: Vector2i = path_cells[rng.randi_range(0, path_cells.size() - 1)]
		if anchor.distance_to(start) < 8.0 or anchor.distance_to(stairs) < 5.0:
			continue
		var side: int = -1 if rng.randf() < 0.5 else 1
		var p: Vector2i = anchor + Vector2i(side * 2, 0)
		if not _inner(p.x, p.y, width, height) or blocked.has(p):
			continue
		var tile: int = int(grid[p.y][p.x])
		if tile != GRASS and tile != TALLGRASS:
			continue
		blocked[p] = true
		var npc_names: Array[String] = ["Trail Scout", "Wyrdling Watcher", "Rift Courier"]
		props.append({
			"kind": "npc",
			"variant": placed % 3,
			"pos": p,
			"blocks": [p],
			"interact_pos": p,
			"name": npc_names[placed % npc_names.size()],
			"text": NPC_LINES[rng.randi_range(0, NPC_LINES.size() - 1)],
		})
		placed += 1


static func _place_decor(grid: Array, props: Array, blocked: Dictionary, width: int, height: int, start: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> void:
	var kinds: Array[String] = ["flowers_a", "flowers_b", "bush", "rock", "stump"]
	var target: int = 26
	var attempts: int = 0
	var path_cells: Array[Vector2i] = _cells_of(grid, DIRT)
	while target > 0 and attempts < 450:
		attempts += 1
		if path_cells.is_empty():
			break
		var anchor: Vector2i = path_cells[rng.randi_range(0, path_cells.size() - 1)]
		var p: Vector2i = anchor + Vector2i(rng.randi_range(-6, 6), rng.randi_range(-4, 4))
		if not _inner(p.x, p.y, width, height):
			continue
		if blocked.has(p) or p.distance_to(start) < 3.0 or p.distance_to(stairs) < 2.0:
			continue
		if int(grid[p.y][p.x]) != GRASS:
			continue
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		var blocks: Array[Vector2i] = []
		if kind == "bush" or kind == "rock" or kind == "stump":
			blocked[p] = true
			blocks.append(p)
		props.append({"kind": kind, "pos": p, "blocks": blocks})
		target -= 1


static func _add_single_prop(props: Array, blocked: Dictionary, kind: String, p: Vector2i, name: String, text: String) -> void:
	blocked[p] = true
	props.append({"kind": kind, "pos": p, "blocks": [p], "interact_pos": p, "name": name, "text": text})


static func _place_trees(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, blocked: Dictionary, trees: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for x: int in range(2, width - 3, 2):
		_try_tree(grid, width, height, Vector2i(x, 2), start, stairs, blocked, trees)
		_try_tree(grid, width, height, Vector2i(x, height - 4), start, stairs, blocked, trees)
	for y: int in range(5, height - 6, 3):
		_try_tree(grid, width, height, Vector2i(2, y), start, stairs, blocked, trees)
		_try_tree(grid, width, height, Vector2i(width - 4, y), start, stairs, blocked, trees)

	var path_cells: Array[Vector2i] = _cells_of(grid, DIRT)
	for _i: int in range(55):
		if path_cells.is_empty():
			break
		var a: Vector2i = path_cells[rng.randi_range(0, path_cells.size() - 1)]
		var side: int = -1 if rng.randf() < 0.5 else 1
		var nw: Vector2i = a + Vector2i(side * rng.randi_range(3, 6), rng.randi_range(-2, 2))
		_try_tree(grid, width, height, nw, start, stairs, blocked, trees)


static func _try_tree(grid: Array, width: int, height: int, nw: Vector2i, start: Vector2i, stairs: Vector2i, blocked: Dictionary, trees: Array[Vector2i]) -> void:
	if not _inner(nw.x, nw.y, width, height) or not _inner(nw.x + 1, nw.y + 1, width, height):
		return
	for existing: Vector2i in trees:
		if absi(existing.x - nw.x) < 2 and absi(existing.y - nw.y) < 2:
			return
	for dy: int in range(2):
		for dx: int in range(2):
			var p: Vector2i = nw + Vector2i(dx, dy)
			if blocked.has(p) or p == start or p == stairs:
				return
			if p.distance_to(start) < 3.0 or p.distance_to(stairs) < 2.0:
				return
			var tile: int = int(grid[p.y][p.x])
			if tile != GRASS and tile != TALLGRASS:
				return
	for dx: int in range(2):
		grid[nw.y + 1][nw.x + dx] = TREE
	trees.append(nw)


static func _blocked_tree_cell(p: Vector2i, trees: Array[Vector2i]) -> bool:
	for nw: Vector2i in trees:
		if p.x >= nw.x and p.x <= nw.x + 1 and p.y >= nw.y and p.y <= nw.y + 1:
			return true
	return false


static func _ensure_tallgrass(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, blocked: Dictionary, trees: Array[Vector2i]) -> void:
	if not _cells_of(grid, TALLGRASS).is_empty():
		return
	for y: int in range(start.y - 12, start.y - 8):
		for x: int in range(start.x - 6, start.x - 1):
			if not _inner(x, y, width, height):
				continue
			var p: Vector2i = Vector2i(x, y)
			if blocked.has(p) or _blocked_tree_cell(p, trees) or p == stairs:
				continue
			if int(grid[y][x]) == GRASS:
				grid[y][x] = TALLGRASS


static func _ensure_water(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, blocked: Dictionary) -> void:
	if not _cells_of(grid, WATER).is_empty():
		return
	var c: Vector2i = Vector2i(clampi(start.x + 11, 8, width - 9), clampi(start.y - 16, 9, height - 10))
	for y: int in range(c.y - 2, c.y + 3):
		for x: int in range(c.x - 3, c.x + 4):
			if not _inner(x, y, width, height):
				continue
			var p: Vector2i = Vector2i(x, y)
			if blocked.has(p) or p == stairs:
				continue
			if int(grid[y][x]) == GRASS:
				grid[y][x] = WATER


static func _cells_of(grid: Array, tile_id: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in grid.size():
		var row: Array = grid[y]
		for x: int in row.size():
			if int(row[x]) == tile_id:
				out.append(Vector2i(x, y))
	return out
