extends RefCounted

const CLIFF := 0
const GRASS := 1
const STAIRS := 2
const DIRT := 3
const WATER := 4
const TALLGRASS := 5
const TREE := 6
const FENCE := 7

const AREA_NAMES := [
	"Willowmere Route",
	"Mosslight Trail",
	"Cinderleaf Way",
	"Silverfen Path",
	"Briarwater Road",
	"Lanternwood Reach",
	"Windglass Route",
	"Riftbloom Trail",
]

const NPC_LINES := [
	"Tall grass is louder than it looks. If the reeds move twice, something is watching.",
	"The lodge keeper says the rift-gate changes the land each time someone passes through.",
	"I saw a Wyrdling drinking at the pond. It vanished the moment the water rippled.",
	"Caves near a rift carry strange echoes. Some delvers swear the echoes answer back.",
	"Keep a healthy Wyrdling ready. The wilds get meaner the farther you descend.",
	"These routes never stay exactly the same, but landmarks have a habit of returning.",
]


static func generate(width: int, height: int, floor_num: int, rng: RandomNumberGenerator) -> Dictionary:
	var grid: Array = []
	for y in height:
		var row: Array = []
		row.resize(width)
		row.fill(GRASS)
		grid.append(row)

	# A two-tile natural boundary gives the route a framed handheld-RPG composition.
	for y in height:
		for x in width:
			if x < 2 or y < 2 or x >= width - 2 or y >= height - 2:
				grid[y][x] = CLIFF

	var clearing_w := 11
	var clearing_h := 8
	var clearing_x: int = int(width / 2) - int(clearing_w / 2)
	var clearing_y: int = height - clearing_h - 4
	var opening := Vector2i(clearing_x + int(clearing_w / 2), clearing_y)
	var start := Vector2i(clearing_x + int(clearing_w / 2), clearing_y + clearing_h - 3)

	for y in range(clearing_y, clearing_y + clearing_h):
		for x in range(clearing_x, clearing_x + clearing_w):
			if _inner(x, y, width, height):
				grid[y][x] = DIRT

	var fence: Array = []
	_stamp_yard_fence(grid, fence, clearing_x, clearing_y, clearing_w, clearing_h, opening, width, height)
	grid[start.y][start.x] = DIRT

	var stairs_x: int = clampi(int(width / 2) + rng.randi_range(-9, 9), 8, width - 9)
	var stairs := Vector2i(stairs_x, 5)

	# Main route: deliberately readable with a few broad bends rather than a noisy maze.
	var waypoints: Array[Vector2i] = [opening]
	var bend_count := rng.randi_range(3, 4)
	for i in bend_count:
		var t: float = float(i + 1) / float(bend_count + 1)
		var wy: int = int(lerpf(float(opening.y), float(stairs.y), t))
		var wx: int = int(lerpf(float(opening.x), float(stairs.x), t))
		var swing := rng.randi_range(6, 11)
		wx += swing if i % 2 == 0 else -swing
		waypoints.append(Vector2i(clampi(wx, 7, width - 8), clampi(wy, 8, height - 12)))
	waypoints.append(stairs)
	for i in range(1, waypoints.size()):
		_carve_path(grid, width, height, waypoints[i - 1], waypoints[i], rng)
	_stamp_path(grid, width, height, stairs.x, stairs.y, 1)
	_stamp_path(grid, width, height, opening.x, opening.y, 1)

	_place_water(grid, width, height, start, stairs, rng)
	_place_tallgrass(grid, width, height, start, stairs, rng)

	var props: Array = []
	var blocked: Dictionary = {}
	_place_lodge(grid, props, blocked, clearing_x, clearing_y, clearing_w, clearing_h, start)
	var cave_info: Dictionary = _place_cave_branch(grid, props, blocked, width, height, start, stairs, rng)
	_place_signs(grid, props, blocked, opening, cave_info, width, height)
	_place_npcs(grid, props, blocked, width, height, start, stairs, rng)
	_place_decor(grid, props, blocked, width, height, start, stairs, rng)

	var trees: Array[Vector2i] = []
	_place_trees(grid, width, height, start, stairs, blocked, trees, rng)

	grid[stairs.y][stairs.x] = STAIRS
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p := stairs + d
		if _inner(p.x, p.y, width, height) and not blocked.has(p):
			if int(grid[p.y][p.x]) == WATER or int(grid[p.y][p.x]) == TALLGRASS:
				grid[p.y][p.x] = DIRT

	_ensure_tallgrass(grid, width, height, start, stairs, blocked, trees)
	_ensure_water(grid, width, height, start, stairs, blocked)

	var wild_count := rng.randi_range(4, 6) if floor_num == 1 else rng.randi_range(6, 8)
	var spots: Array[Vector2i] = []
	for y in height:
		for x in width:
			var p := Vector2i(x, y)
			if int(grid[y][x]) != TALLGRASS:
				continue
			if p == start or p == stairs or p.distance_to(start) <= 3:
				continue
			if blocked.has(p) or _blocked_tree_cell(p, trees):
				continue
			spots.append(p)

	var wilds: Array[Vector2i] = []
	while wilds.size() < wild_count and not spots.is_empty():
		var idx := rng.randi_range(0, spots.size() - 1)
		var p: Vector2i = spots[idx]
		spots.remove_at(idx)
		if not wilds.has(p):
			wilds.append(p)

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
	var x1 := x0 + w - 1
	var y1 := y0 + h - 1
	for x in range(x0, x1 + 1):
		if x < opening.x - 1 or x > opening.x + 1:
			_stamp_fence(grid, fence, Vector2i(x, y0), width, height, "h")
		_stamp_fence(grid, fence, Vector2i(x, y1), width, height, "h")
	for y in range(y0, y1 + 1):
		_stamp_fence(grid, fence, Vector2i(x0, y), width, height, "v")
		_stamp_fence(grid, fence, Vector2i(x1, y), width, height, "v")
	_label_fences(fence)


static func _stamp_fence(grid: Array, fence: Array, pos: Vector2i, width: int, height: int, kind: String) -> void:
	if not _inner(pos.x, pos.y, width, height):
		return
	for f in fence:
		if f["pos"] == pos:
			return
	fence.append({"pos": pos, "kind": kind})


static func _label_fences(fence: Array) -> void:
	var occupied: Dictionary = {}
	for f in fence:
		occupied[f["pos"]] = true
	for f in fence:
		var p: Vector2i = f["pos"]
		var n := occupied.has(p + Vector2i(0, -1))
		var s := occupied.has(p + Vector2i(0, 1))
		var e := occupied.has(p + Vector2i(1, 0))
		var w := occupied.has(p + Vector2i(-1, 0))
		if e and s and not n and not w: f["kind"] = "nw"
		elif w and s and not n and not e: f["kind"] = "ne"
		elif e and n and not s and not w: f["kind"] = "sw"
		elif w and n and not s and not e: f["kind"] = "se"
		elif (e or w) and not (n or s): f["kind"] = "h"
		elif (n or s) and not (e or w): f["kind"] = "v"
		else: f["kind"] = "post"


static func _carve_path(grid: Array, width: int, height: int, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var p := a
	var horiz_first := rng.randf() < 0.5
	var guard := 0
	while p != b and guard < 600:
		guard += 1
		_stamp_path(grid, width, height, p.x, p.y, 1)
		if horiz_first:
			if p.x != b.x: p.x += signi(b.x - p.x)
			elif p.y != b.y: p.y += signi(b.y - p.y)
		else:
			if p.y != b.y: p.y += signi(b.y - p.y)
			elif p.x != b.x: p.x += signi(b.x - p.x)
		if rng.randf() < 0.12:
			horiz_first = not horiz_first
	_stamp_path(grid, width, height, b.x, b.y, 1)


static func _stamp_path(grid: Array, width: int, height: int, x: int, y: int, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var px := x + dx
			var py := y + dy
			if not _inner(px, py, width, height):
				continue
			if int(grid[py][px]) != CLIFF:
				grid[py][px] = DIRT


static func _place_water(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> void:
	var centers := [
		Vector2i(clampi(start.x + 12, 9, width - 10), clampi(start.y - 17, 10, height - 12)),
		Vector2i(clampi(start.x - 14, 9, width - 10), clampi(start.y - 29, 9, height - 12)),
	]
	for ci in range(centers.size()):
		if ci == 1 and rng.randf() < 0.35:
			continue
		var c: Vector2i = centers[ci]
		var rx := rng.randi_range(3, 5)
		var ry := rng.randi_range(2, 4)
		for y in range(c.y - ry, c.y + ry + 1):
			for x in range(c.x - rx, c.x + rx + 1):
				if not _inner(x, y, width, height): continue
				var nx := float(x - c.x) / float(maxi(rx, 1))
				var ny := float(y - c.y) / float(maxi(ry, 1))
				if nx * nx + ny * ny > 1.05: continue
				var p := Vector2i(x, y)
				if p.distance_to(start) < 5 or p.distance_to(stairs) < 3: continue
				if int(grid[y][x]) == GRASS or int(grid[y][x]) == TALLGRASS:
					grid[y][x] = WATER


static func _place_tallgrass(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> void:
	var path_cells := _cells_of(grid, DIRT)
	var patches := rng.randi_range(8, 11)
	for _i in patches:
		if path_cells.is_empty(): break
		var anchor: Vector2i = path_cells[rng.randi_range(0, path_cells.size() - 1)]
		var side := -1 if rng.randf() < 0.5 else 1
		var ox := anchor.x + side * rng.randi_range(3, 6)
		var oy := anchor.y + rng.randi_range(-2, 2)
		var pw := rng.randi_range(4, 7)
		var ph := rng.randi_range(3, 5)
		for y in range(oy, oy + ph):
			for x in range(ox, ox + pw):
				if not _inner(x, y, width, height): continue
				var p := Vector2i(x, y)
				if p.distance_to(start) < 4 or p.distance_to(stairs) < 2: continue
				if int(grid[y][x]) == GRASS and (rng.randf() > 0.12 or (x + y) % 3 != 0):
					grid[y][x] = TALLGRASS


static func _place_lodge(grid: Array, props: Array, blocked: Dictionary, clearing_x: int, clearing_y: int, clearing_w: int, clearing_h: int, start: Vector2i) -> void:
	var pos := Vector2i(clearing_x + clearing_w - 5, clearing_y + 1)
	var blocks: Array[Vector2i] = []
	for y in range(pos.y, pos.y + 3):
		for x in range(pos.x, pos.x + 3):
			var p := Vector2i(x, y)
			if p == start: continue
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
	var path_cells := _cells_of(grid, DIRT)
	var candidates: Array[Vector2i] = []
	for p in path_cells:
		if p.y < stairs.y + 8 or p.y > start.y - 10: continue
		candidates.append(p)
	if candidates.is_empty():
		return {}
	var anchor: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
	var side := -1 if anchor.x > width / 2 else 1
	if rng.randf() < 0.35: side *= -1
	var door := Vector2i(clampi(anchor.x + side * rng.randi_range(7, 10), 6, width - 7), clampi(anchor.y + rng.randi_range(-2, 2), 8, height - 11))
	var pos := door + Vector2i(-1, -1)
	# Clear a small approach and branch from the route.
	_carve_path(grid, width, height, anchor, door + Vector2i(0, 1), rng)
	var blocks: Array[Vector2i] = []
	for y in range(pos.y, pos.y + 2):
		for x in range(pos.x, pos.x + 3):
			var p := Vector2i(x, y)
			blocks.append(p)
			blocked[p] = true
			if int(grid[y][x]) != CLIFF: grid[y][x] = GRASS
	props.append({
		"kind": "cave",
		"pos": pos,
		"blocks": blocks,
		"interact_pos": door,
		"name": "Echo Cave",
		"text": "Cold air spills from Echo Cave. Riftstone inside hums with distant Wyrdling calls.",
	})
	return {"door": door, "anchor": anchor}


static func _place_signs(grid: Array, props: Array, blocked: Dictionary, opening: Vector2i, cave_info: Dictionary, width: int, height: int) -> void:
	var first := opening + Vector2i(2, -3)
	_add_single_prop(props, blocked, "sign", first, "Route Marker", "North: rift-gate. Tall grass: wild Wyrdlings. Lodge: rest and regroup.")
	if not cave_info.is_empty():
		var anchor: Vector2i = cave_info["anchor"]
		var door: Vector2i = cave_info["door"]
		var delta := door - anchor
		var sign_pos := anchor + Vector2i(1 if delta.x < 0 else -1, 0)
		if _inner(sign_pos.x, sign_pos.y, width, height) and not blocked.has(sign_pos):
			_add_single_prop(props, blocked, "sign", sign_pos, "Weathered Sign", "Echo Cave lies off the main trail. The stone sings louder after dusk.")


static func _place_npcs(grid: Array, props: Array, blocked: Dictionary, width: int, height: int, start: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> void:
	var path_cells := _cells_of(grid, DIRT)
	var placed := 0
	var attempts := 0
	while placed < 3 and attempts < 100:
		attempts += 1
		if path_cells.is_empty(): break
		var anchor: Vector2i = path_cells[rng.randi_range(0, path_cells.size() - 1)]
		if anchor.distance_to(start) < 8 or anchor.distance_to(stairs) < 5: continue
		var side := -1 if rng.randf() < 0.5 else 1
		var p := anchor + Vector2i(side * 2, 0)
		if not _inner(p.x, p.y, width, height): continue
		if blocked.has(p) or int(grid[p.y][p.x]) == WATER: continue
		if int(grid[p.y][p.x]) != GRASS and int(grid[p.y][p.x]) != TALLGRASS: continue
		blocked[p] = true
		props.append({
			"kind": "npc",
			"variant": placed % 3,
			"pos": p,
			"blocks": [p],
			"interact_pos": p,
			"name": ["Trail Scout", "Wyrdling Watcher", "Rift Courier"][placed % 3],
			"text": NPC_LINES[rng.randi_range(0, NPC_LINES.size() - 1)],
		})
		placed += 1


static func _place_decor(grid: Array, props: Array, blocked: Dictionary, width: int, height: int, start: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> void:
	var kinds := ["flowers_a", "flowers_b", "bush", "rock", "stump"]
	var target := 26
	var attempts := 0
	var path_cells := _cells_of(grid, DIRT)
	while target > 0 and attempts < 400:
		attempts += 1
		if path_cells.is_empty(): break
		var anchor: Vector2i = path_cells[rng.randi_range(0, path_cells.size() - 1)]
		var p := anchor + Vector2i(rng.randi_range(-6, 6), rng.randi_range(-4, 4))
		if not _inner(p.x, p.y, width, height): continue
		if blocked.has(p) or p.distance_to(start) < 3 or p.distance_to(stairs) < 2: continue
		if int(grid[p.y][p.x]) != GRASS: continue
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


static func _place_trees(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, blocked: Dictionary, trees: Array, rng: RandomNumberGenerator) -> void:
	# Dense border woodland.
	for x in range(2, width - 3, 2):
		_try_tree(grid, width, height, Vector2i(x, 2), start, stairs, blocked, trees)
		_try_tree(grid, width, height, Vector2i(x, height - 4), start, stairs, blocked, trees)
	for y in range(5, height - 6, 3):
		_try_tree(grid, width, height, Vector2i(2, y), start, stairs, blocked, trees)
		_try_tree(grid, width, height, Vector2i(width - 4, y), start, stairs, blocked, trees)

	# Route-side groves create the layered, enclosed GBA-route look.
	var path_cells := _cells_of(grid, DIRT)
	for _i in range(55):
		if path_cells.is_empty(): break
		var a: Vector2i = path_cells[rng.randi_range(0, path_cells.size() - 1)]
		var side := -1 if rng.randf() < 0.5 else 1
		var nw := a + Vector2i(side * rng.randi_range(3, 6), rng.randi_range(-2, 2))
		_try_tree(grid, width, height, nw, start, stairs, blocked, trees)


static func _try_tree(grid: Array, width: int, height: int, nw: Vector2i, start: Vector2i, stairs: Vector2i, blocked: Dictionary, trees: Array) -> void:
	if not _inner(nw.x, nw.y, width, height) or not _inner(nw.x + 1, nw.y + 1, width, height): return
	for existing in trees:
		var e: Vector2i = existing
		if absi(e.x - nw.x) < 2 and absi(e.y - nw.y) < 2: return
	for dy in range(2):
		for dx in range(2):
			var p := nw + Vector2i(dx, dy)
			if blocked.has(p) or p == start or p == stairs: return
			if p.distance_to(start) < 3 or p.distance_to(stairs) < 2: return
			var t := int(grid[p.y][p.x])
			if t != GRASS and t != TALLGRASS: return
	for dx in range(2):
		grid[nw.y + 1][nw.x + dx] = TREE
	trees.append(nw)


static func _blocked_tree_cell(p: Vector2i, trees: Array) -> bool:
	for nw in trees:
		var t: Vector2i = nw
		if p.x >= t.x and p.x <= t.x + 1 and p.y >= t.y and p.y <= t.y + 1:
			return true
	return false


static func _ensure_tallgrass(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, blocked: Dictionary, trees: Array) -> void:
	if not _cells_of(grid, TALLGRASS).is_empty(): return
	for y in range(start.y - 12, start.y - 8):
		for x in range(start.x - 6, start.x - 1):
			if not _inner(x, y, width, height): continue
			var p := Vector2i(x, y)
			if blocked.has(p) or _blocked_tree_cell(p, trees) or p == stairs: continue
			if int(grid[y][x]) == GRASS: grid[y][x] = TALLGRASS


static func _ensure_water(grid: Array, width: int, height: int, start: Vector2i, stairs: Vector2i, blocked: Dictionary) -> void:
	if not _cells_of(grid, WATER).is_empty(): return
	var c := Vector2i(clampi(start.x + 11, 8, width - 9), clampi(start.y - 16, 9, height - 10))
	for y in range(c.y - 2, c.y + 3):
		for x in range(c.x - 3, c.x + 4):
			if not _inner(x, y, width, height): continue
			var p := Vector2i(x, y)
			if blocked.has(p) or p == stairs: continue
			if int(grid[y][x]) == GRASS: grid[y][x] = WATER


static func _cells_of(grid: Array, tile_id: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in grid.size():
		for x in grid[y].size():
			if int(grid[y][x]) == tile_id:
				out.append(Vector2i(x, y))
	return out
