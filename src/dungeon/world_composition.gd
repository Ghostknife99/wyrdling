extends RefCounted
## Post-processes the generated route into a stronger authored-looking composition.
## RouteGen still owns progression and the guaranteed trail; this pass adds a
## real river crossing, interior cliff shelves, forest masses and a memorable
## riftstone landmark without changing the run structure.

const CLIFF := 0
const GRASS := 1
const STAIRS := 2
const DIRT := 3
const WATER := 4
const TALLGRASS := 5
const TREE := 6

const DISPOSABLE_DECOR: Array[String] = [
	"flowers_a", "flowers_b", "bush", "rock", "stump", "mushrooms", "fallen_log",
]


static func apply(result: Dictionary, width: int, height: int, floor_num: int, rng: RandomNumberGenerator) -> Dictionary:
	if result.is_empty() or not result.has("grid"):
		return result

	var grid: Array = result["grid"]
	var start: Vector2i = result["start"]
	var stairs: Vector2i = result["stairs"]
	var props: Array = result.get("props", [])
	var trees: Array = result.get("trees", [])
	var fence: Array = result.get("fence", [])
	var requested_wilds: int = int(result.get("wilds", []).size())

	_slim_cave_spur(grid, props, fence, start, stairs, width, height)
	var critical: Dictionary = _critical_cells(props, fence, start, stairs)
	var bridge_info: Dictionary = _place_river_crossing(grid, props, trees, critical, width, height, start, stairs, floor_num, rng)
	critical = _critical_cells(props, fence, start, stairs)
	var landmark_info: Dictionary = _place_riftstone_landmark(grid, props, trees, critical, width, height, start, stairs, bridge_info, rng)
	critical = _critical_cells(props, fence, start, stairs)

	_place_cliff_shelves(grid, props, critical, width, height, start, stairs, floor_num, rng)
	critical = _critical_cells(props, fence, start, stairs)
	_place_forest_masses(grid, trees, critical, width, height, start, stairs, rng)
	_place_composition_decor(grid, props, critical, width, height, bridge_info, landmark_info, rng)

	result["grid"] = grid
	result["props"] = props
	result["trees"] = trees
	result["wilds"] = _reseed_wild_spots(grid, props, trees, requested_wilds, width, height, start, stairs, rng)
	return result


static func _critical_cells(props: Array, fence: Array, start: Vector2i, stairs: Vector2i) -> Dictionary:
	var out: Dictionary = {start: true, stairs: true}
	for raw_fence in fence:
		var f: Dictionary = raw_fence
		out[f.get("pos", Vector2i.ZERO)] = true
	for raw_prop in props:
		var prop: Dictionary = raw_prop
		var kind: String = str(prop.get("kind", ""))
		if kind in DISPOSABLE_DECOR:
			continue
		for raw_cell in prop.get("blocks", []):
			out[raw_cell] = true
		if prop.has("interact_pos"):
			out[prop["interact_pos"]] = true
	return out


static func _place_river_crossing(grid: Array, props: Array, trees: Array, critical: Dictionary, width: int, height: int, start: Vector2i, stairs: Vector2i, floor_num: int, rng: RandomNumberGenerator) -> Dictionary:
	var crossing: Vector2i = _find_bridge_crossing(grid, critical, width, height, start, stairs)
	if crossing.x < 0:
		return {}

	var river_cells: Dictionary = {}
	for x: int in range(3, width - 3):
		var wave: int = int(round(sin(float(x + floor_num * 7) * 0.37) * 1.6))
		if absi(x - crossing.x) <= 3:
			wave = 0
		var center_y: int = clampi(crossing.y + wave, 8, height - 9)
		var radius: int = 2 if ((x + floor_num * 5) % 17 == 0) else 1
		if absi(x - crossing.x) <= 2:
			radius = 2
		for y: int in range(center_y - radius, center_y + radius + 1):
			if _inner(x, y, width, height):
				river_cells[Vector2i(x, y)] = true

	_remove_disposable_props(props, river_cells)
	_remove_trees_in_cells(grid, trees, river_cells)

	var bridge_blocks: Array[Vector2i] = []
	for y: int in range(crossing.y - 2, crossing.y + 3):
		for x: int in range(crossing.x - 1, crossing.x + 2):
			bridge_blocks.append(Vector2i(x, y))

	var bridge_lookup: Dictionary = {}
	for cell: Vector2i in bridge_blocks:
		bridge_lookup[cell] = true

	for raw_cell in river_cells.keys():
		var p: Vector2i = raw_cell
		if critical.has(p):
			continue
		var tile: int = int(grid[p.y][p.x])
		if tile == CLIFF or tile == STAIRS:
			continue
		# Keep unrelated trail branches as shallow natural fords. The selected main
		# crossing is deliberately flooded so the bridge is a real gameplay object.
		if tile == DIRT and not bridge_lookup.has(p):
			continue
		grid[p.y][p.x] = WATER

	# The bridge still gets a readable landing on each bank, but the landings now
	# echo the narrow trail instead of stamping two solid 3x4 dirt rectangles.
	var approach_side: int = -1 if (crossing.x + crossing.y) % 2 == 0 else 1
	for y: int in range(crossing.y - 6, crossing.y - 2):
		_stamp_dirt(grid, crossing.x, y, 0, width, height)
		if (crossing.y - y) % 3 != 0:
			_stamp_dirt(grid, crossing.x + approach_side, y, 0, width, height)
	for y: int in range(crossing.y + 3, crossing.y + 7):
		_stamp_dirt(grid, crossing.x, y, 0, width, height)
		if (y - crossing.y) % 3 != 0:
			_stamp_dirt(grid, crossing.x - approach_side, y, 0, width, height)

	props.append({
		"kind": "bridge",
		"pos": Vector2i(crossing.x - 1, crossing.y - 2),
		"blocks": bridge_blocks,
		"walkable": true,
		"name": "Willowspan Bridge",
		"text": "Old cedar planks cross the cold riftwater. Blue motes gather beneath the rails.",
	})

	var sign_pos := Vector2i(crossing.x + 3, crossing.y + 3)
	if _inner(sign_pos.x, sign_pos.y, width, height) and not critical.has(sign_pos):
		grid[sign_pos.y][sign_pos.x] = GRASS
		props.append({
			"kind": "sign",
			"pos": sign_pos,
			"blocks": [sign_pos],
			"interact_pos": sign_pos,
			"name": "Willowspan Marker",
			"text": "Willowspan Bridge — Riftkeeper Lodge south, old riftstone east of the trail.",
		})

	return {"crossing": crossing, "river": river_cells, "bridge_blocks": bridge_blocks}


static func _find_bridge_crossing(grid: Array, critical: Dictionary, width: int, height: int, start: Vector2i, stairs: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := 999999
	for y: int in range(12, height - 12):
		for x: int in range(7, width - 7):
			var p := Vector2i(x, y)
			if int(grid[y][x]) != DIRT or critical.has(p):
				continue
			if p.distance_to(start) < 12.0 or p.distance_to(stairs) < 8.0:
				continue
			var vertical_hits := 0
			for dy: int in [-3, -2, -1, 1, 2, 3]:
				if int(grid[y + dy][x]) == DIRT:
					vertical_hits += 1
			if vertical_hits < 4:
				continue
			var score: int = absi(y - int(height / 2)) * 3 + absi(x - int(width / 2)) - vertical_hits * 2
			if score < best_score:
				best_score = score
				best = p

	if best.x >= 0:
		return best

	# Fallback for an unusually horizontal seed.
	for y: int in range(12, height - 12):
		for x: int in range(7, width - 7):
			var p := Vector2i(x, y)
			if int(grid[y][x]) == DIRT and not critical.has(p) and p.distance_to(start) >= 10.0 and p.distance_to(stairs) >= 7.0:
				return p
	return best


static func _place_riftstone_landmark(grid: Array, props: Array, trees: Array, critical: Dictionary, width: int, height: int, start: Vector2i, stairs: Vector2i, bridge_info: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var path_cells: Array[Vector2i] = _cells_of(grid, DIRT)
	var chosen_anchor := Vector2i(-1, -1)
	var chosen_top_left := Vector2i(-1, -1)
	var chosen_side := 1
	var crossing: Vector2i = bridge_info.get("crossing", Vector2i(-99, -99))
	var cave_door := Vector2i(-99, -99)
	for raw_prop in props:
		var prop: Dictionary = raw_prop
		if str(prop.get("kind", "")) == "cave" and prop.has("interact_pos"):
			cave_door = prop["interact_pos"]
			break

	# Pass one keeps the preferred authored composition: the Riftstone peels off
	# well north of Echo Cave. If a seed puts the cave too close to the exit for
	# that to be possible, pass two keeps the landmark on the opposite side of
	# the main trail instead. That guarantees the feature without rebuilding the
	# giant cave/riftstone crossroads this geometry pass was meant to remove.
	for strict_separation: bool in [true, false]:
		var best_score := 999999
		for anchor: Vector2i in path_cells:
			if anchor.y < 10 or anchor.y > height - 13:
				continue
			if anchor.distance_to(start) < 11.0 or anchor.distance_to(stairs) < 7.0 or anchor.distance_to(crossing) < 8.0:
				continue
			if not _looks_like_main_trail(grid, anchor):
				continue
			if strict_separation:
				if cave_door.x > -90 and anchor.y > cave_door.y - 5:
					continue
				if anchor.distance_to(cave_door) < 6.0:
					continue
			else:
				if anchor.distance_to(cave_door) < 7.0:
					continue

			var sides: Array[int] = [-1, 1]
			if not strict_separation and cave_door.x > -90:
				var away_side: int = 1 if cave_door.x < anchor.x else -1
				sides = [away_side]

			for side: int in sides:
				var center := anchor + Vector2i(side * 7, 0)
				var top_left := center + Vector2i(-1, -2)
				if not _landmark_area_ok(grid, critical, top_left, width, height):
					continue
				var score := absi(anchor.y - int(height * 0.48)) * 2 + absi(center.x - int(width / 2))
				score += maxi(0, 10 - int(anchor.distance_to(cave_door)))
				if not strict_separation:
					score += maxi(0, 4 - absi(anchor.y - cave_door.y)) * 4
				if score < best_score:
					best_score = score
					chosen_anchor = anchor
					chosen_top_left = top_left
					chosen_side = side
		if chosen_anchor.x >= 0:
			break

	if chosen_anchor.x < 0:
		return {}

	var clearing: Dictionary = {}
	for y: int in range(chosen_top_left.y - 2, chosen_top_left.y + 5):
		for x: int in range(chosen_top_left.x - 2, chosen_top_left.x + 5):
			if _inner(x, y, width, height):
				clearing[Vector2i(x, y)] = true
	_remove_disposable_props(props, clearing)
	_remove_trees_in_cells(grid, trees, clearing)
	for raw_cell in clearing.keys():
		var p: Vector2i = raw_cell
		if critical.has(p):
			continue
		var tile := int(grid[p.y][p.x])
		if tile == GRASS or tile == TALLGRASS or tile == TREE:
			grid[p.y][p.x] = GRASS

	var blocks: Array[Vector2i] = []
	for y: int in range(chosen_top_left.y, chosen_top_left.y + 3):
		for x: int in range(chosen_top_left.x, chosen_top_left.x + 3):
			blocks.append(Vector2i(x, y))
			if int(grid[y][x]) != CLIFF and int(grid[y][x]) != WATER:
				grid[y][x] = GRASS

	var interact_pos: Vector2i
	var front: Vector2i
	if chosen_side > 0:
		interact_pos = chosen_top_left + Vector2i(0, 2)
		front = chosen_top_left + Vector2i(-1, 2)
	else:
		interact_pos = chosen_top_left + Vector2i(2, 2)
		front = chosen_top_left + Vector2i(3, 2)
	_carve_spur(grid, trees, critical, chosen_anchor, front, width, height)

	props.append({
		"kind": "riftstone",
		"pos": chosen_top_left,
		"blocks": blocks,
		"interact_pos": interact_pos,
		"name": "Old Wyrdling Riftstone",
		"text": "A weathered binding rune glows beneath the moss. Something small has left fresh pawprints around the base.",
	})

	# A deliberate little shrine garden gives the landmark a readable silhouette.
	var accents: Array[Dictionary] = [
		{"kind": "flowers_a", "delta": Vector2i(-2, 0)},
		{"kind": "flowers_b", "delta": Vector2i(4, 1)},
		{"kind": "mushrooms", "delta": Vector2i(-1, 4)},
		{"kind": "rock", "delta": Vector2i(3, -1)},
	]
	for accent: Dictionary in accents:
		var p: Vector2i = chosen_top_left + accent["delta"]
		if _inner(p.x, p.y, width, height) and int(grid[p.y][p.x]) == GRASS:
			props.append({"kind": accent["kind"], "pos": p, "blocks": []})

	return {"top_left": chosen_top_left, "anchor": chosen_anchor}


static func _landmark_area_ok(grid: Array, critical: Dictionary, top_left: Vector2i, width: int, height: int) -> bool:
	for y: int in range(top_left.y - 2, top_left.y + 5):
		for x: int in range(top_left.x - 2, top_left.x + 5):
			if not _inner(x, y, width, height):
				return false
			var p := Vector2i(x, y)
			if critical.has(p):
				return false
			var tile := int(grid[y][x])
			if tile == WATER or tile == CLIFF or tile == STAIRS:
				return false
	return true


static func _place_cliff_shelves(grid: Array, props: Array, critical: Dictionary, width: int, height: int, start: Vector2i, stairs: Vector2i, floor_num: int, rng: RandomNumberGenerator) -> void:
	var anchors: Array[Vector2i] = [
		Vector2i(10 + (floor_num % 3), 12),
		Vector2i(width - 14, 15 + (floor_num % 4)),
		Vector2i(12, height - 18),
		Vector2i(width - 15, height - 16),
	]
	for i: int in anchors.size():
		var c: Vector2i = anchors[i] + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
		if c.distance_to(start) < 8.0 or c.distance_to(stairs) < 6.0:
			continue
		var rx: int = rng.randi_range(4, 6)
		var ry: int = rng.randi_range(2, 4)
		for y: int in range(c.y - ry, c.y + ry + 1):
			for x: int in range(c.x - rx, c.x + rx + 1):
				if not _inner(x, y, width, height):
					continue
				var p := Vector2i(x, y)
				if critical.has(p):
					continue
				var nx: float = float(x - c.x) / float(maxi(rx, 1))
				var ny: float = float(y - c.y) / float(maxi(ry, 1))
				if nx * nx + ny * ny > 1.0:
					continue
				var tile := int(grid[y][x])
				if tile != GRASS and tile != TALLGRASS:
					continue
				# Broken edges avoid perfect oval "islands" and read more like shelves.
				if ((x * 17 + y * 29 + floor_num * 11) % 9 == 0) and nx * nx + ny * ny > 0.55:
					continue
				grid[y][x] = CLIFF

		# Loose rocks at the foot of each shelf help sell the height change.
		for dx: int in [-rx - 1, rx + 1]:
			var p := Vector2i(c.x + dx, c.y + ry)
			if _inner(p.x, p.y, width, height) and not critical.has(p) and int(grid[p.y][p.x]) == GRASS:
				props.append({"kind": "rock", "pos": p, "blocks": []})


static func _place_forest_masses(grid: Array, trees: Array, critical: Dictionary, width: int, height: int, start: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> void:
	var candidates: Array[Vector2i] = []
	for y: int in range(6, height - 7, 2):
		for x: int in range(6, width - 7, 2):
			var p := Vector2i(x, y)
			if int(grid[y][x]) != GRASS or critical.has(p):
				continue
			if p.distance_to(start) < 8.0 or p.distance_to(stairs) < 6.0:
				continue
			if _near_tile(grid, p, DIRT, 4) or _near_tile(grid, p, WATER, 2) or _near_tile(grid, p, CLIFF, 2):
				continue
			candidates.append(p)

	var centers: Array[Vector2i] = []
	var attempts := 0
	while centers.size() < 5 and not candidates.is_empty() and attempts < 100:
		attempts += 1
		var idx := rng.randi_range(0, candidates.size() - 1)
		var c: Vector2i = candidates[idx]
		candidates.remove_at(idx)
		var spaced := true
		for other: Vector2i in centers:
			if c.distance_to(other) < 9.0:
				spaced = false
				break
		if spaced:
			centers.append(c)

	var target_added := 42
	var added := 0
	for center: Vector2i in centers:
		for _i: int in 28:
			if added >= target_added:
				break
			var nw := center + Vector2i(rng.randi_range(-5, 5), rng.randi_range(-4, 4))
			if _try_add_tree(grid, trees, critical, nw, width, height, start, stairs):
				added += 1


static func _try_add_tree(grid: Array, trees: Array, critical: Dictionary, nw: Vector2i, width: int, height: int, start: Vector2i, stairs: Vector2i) -> bool:
	if not _inner(nw.x, nw.y, width, height) or not _inner(nw.x + 1, nw.y + 1, width, height):
		return false
	for raw_tree in trees:
		var existing: Vector2i = raw_tree
		if absi(existing.x - nw.x) < 2 and absi(existing.y - nw.y) < 2:
			return false
	for dy: int in 2:
		for dx: int in 2:
			var p := nw + Vector2i(dx, dy)
			if critical.has(p) or p.distance_to(start) < 4.0 or p.distance_to(stairs) < 3.0:
				return false
			var tile := int(grid[p.y][p.x])
			if tile != GRASS and tile != TALLGRASS:
				return false
	for dx: int in 2:
		grid[nw.y + 1][nw.x + dx] = TREE
	trees.append(nw)
	return true


static func _place_composition_decor(grid: Array, props: Array, critical: Dictionary, width: int, height: int, bridge_info: Dictionary, landmark_info: Dictionary, rng: RandomNumberGenerator) -> void:
	if not bridge_info.is_empty():
		var c: Vector2i = bridge_info["crossing"]
		var bank_offsets: Array[Vector2i] = [
			Vector2i(-5, -4), Vector2i(5, 4), Vector2i(-6, 4), Vector2i(6, -4),
			Vector2i(-3, 4), Vector2i(4, -4),
		]
		for i: int in bank_offsets.size():
			var p := c + bank_offsets[i]
			if not _inner(p.x, p.y, width, height) or critical.has(p) or int(grid[p.y][p.x]) != GRASS:
				continue
			var kind := "flowers_a" if i % 3 == 0 else ("mushrooms" if i % 3 == 1 else "rock")
			props.append({"kind": kind, "pos": p, "blocks": []})

	# A few deliberate fallen logs live inside the forest, not on the main path.
	var placed_logs := 0
	var tries := 0
	while placed_logs < 4 and tries < 180:
		tries += 1
		var p := Vector2i(rng.randi_range(5, width - 8), rng.randi_range(6, height - 7))
		var right := p + Vector2i(1, 0)
		if critical.has(p) or critical.has(right):
			continue
		if int(grid[p.y][p.x]) != GRASS or int(grid[right.y][right.x]) != GRASS:
			continue
		if _near_tile(grid, p, DIRT, 3):
			continue
		props.append({"kind": "fallen_log", "pos": p, "blocks": [p, right]})
		placed_logs += 1


static func _reseed_wild_spots(grid: Array, props: Array, trees: Array, requested: int, width: int, height: int, start: Vector2i, stairs: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var blocked: Dictionary = {}
	for raw_prop in props:
		var prop: Dictionary = raw_prop
		if bool(prop.get("walkable", false)):
			continue
		for raw_cell in prop.get("blocks", []):
			blocked[raw_cell] = true
	for raw_tree in trees:
		var nw: Vector2i = raw_tree
		for dy: int in 2:
			for dx: int in 2:
				blocked[nw + Vector2i(dx, dy)] = true

	var candidates: Array[Vector2i] = []
	for y: int in range(3, height - 3):
		for x: int in range(3, width - 3):
			var p := Vector2i(x, y)
			if int(grid[y][x]) != TALLGRASS or blocked.has(p):
				continue
			if p.distance_to(start) <= 3.0 or p.distance_to(stairs) <= 2.0:
				continue
			candidates.append(p)

	var out: Array[Vector2i] = []
	while out.size() < requested and not candidates.is_empty():
		var idx := rng.randi_range(0, candidates.size() - 1)
		out.append(candidates[idx])
		candidates.remove_at(idx)
	return out


static func _remove_disposable_props(props: Array, cells: Dictionary) -> void:
	for i: int in range(props.size() - 1, -1, -1):
		var prop: Dictionary = props[i]
		if not (str(prop.get("kind", "")) in DISPOSABLE_DECOR):
			continue
		var p: Vector2i = prop.get("pos", Vector2i.ZERO)
		var remove := cells.has(p)
		if not remove:
			for raw_cell in prop.get("blocks", []):
				if cells.has(raw_cell):
					remove = true
					break
		if remove:
			props.remove_at(i)


static func _remove_trees_in_cells(grid: Array, trees: Array, cells: Dictionary) -> void:
	for i: int in range(trees.size() - 1, -1, -1):
		var nw: Vector2i = trees[i]
		var hit := false
		for dy: int in 2:
			for dx: int in 2:
				if cells.has(nw + Vector2i(dx, dy)):
					hit = true
		if not hit:
			continue
		for dx: int in 2:
			var p := nw + Vector2i(dx, 1)
			if int(grid[p.y][p.x]) == TREE:
				grid[p.y][p.x] = GRASS
		trees.remove_at(i)


static func _slim_cave_spur(grid: Array, props: Array, fence: Array, start: Vector2i, stairs: Vector2i, width: int, height: int) -> void:
	var cave_door := Vector2i(-1, -1)
	for raw_prop in props:
		var prop: Dictionary = raw_prop
		if str(prop.get("kind", "")) == "cave" and prop.has("interact_pos"):
			cave_door = prop["interact_pos"]
			break
	if cave_door.x < 0:
		return

	var trail_start := cave_door + Vector2i(0, 1)
	var path_cells: Array[Vector2i] = _cells_of(grid, DIRT)
	var main_lookup: Dictionary = {}
	var main_anchor := Vector2i(-1, -1)
	var best_distance := 99999.0
	for p: Vector2i in path_cells:
		if not _looks_like_main_trail(grid, p):
			continue
		main_lookup[p] = true
		var distance: float = p.distance_to(trail_start)
		if distance < best_distance:
			best_distance = distance
			main_anchor = p
	if main_anchor.x < 0 or best_distance > 16.0:
		return

	var corridor: Dictionary = {}
	var cursor := trail_start
	var guard := 0
	while cursor.x != main_anchor.x and guard < 40:
		corridor[cursor] = true
		cursor.x += signi(main_anchor.x - cursor.x)
		guard += 1
	while cursor.y != main_anchor.y and guard < 80:
		corridor[cursor] = true
		cursor.y += signi(main_anchor.y - cursor.y)
		guard += 1
	corridor[main_anchor] = true

	var protected: Dictionary = _critical_cells(props, fence, start, stairs)
	var min_x: int = mini(trail_start.x, main_anchor.x) - 2
	var max_x: int = maxi(trail_start.x, main_anchor.x) + 2
	var min_y: int = mini(trail_start.y, main_anchor.y) - 2
	var max_y: int = maxi(trail_start.y, main_anchor.y) + 2
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			if not _inner(x, y, width, height):
				continue
			var p := Vector2i(x, y)
			if int(grid[y][x]) != DIRT:
				continue
			if corridor.has(p) or main_lookup.has(p) or protected.has(p):
				continue
			grid[y][x] = GRASS

	for raw_cell in corridor.keys():
		var p: Vector2i = raw_cell
		if not _inner(p.x, p.y, width, height):
			continue
		var tile := int(grid[p.y][p.x])
		if tile != CLIFF and tile != STAIRS and tile != WATER:
			grid[p.y][p.x] = DIRT


static func _carve_spur(grid: Array, trees: Array, critical: Dictionary, a: Vector2i, b: Vector2i, width: int, height: int) -> void:
	var corridor: Dictionary = {}
	var p := a
	var guard := 0
	while p != b and guard < 80:
		guard += 1
		corridor[p] = true
		var direction := Vector2i.ZERO
		if p.x != b.x:
			direction = Vector2i(signi(b.x - p.x), 0)
		elif p.y != b.y:
			direction = Vector2i(0, signi(b.y - p.y))
		p += direction
	corridor[b] = true

	_remove_trees_in_cells(grid, trees, corridor)
	for raw_cell in corridor.keys():
		var c: Vector2i = raw_cell
		if critical.has(c):
			continue
		var tile := int(grid[c.y][c.x])
		if tile == GRASS or tile == TALLGRASS or tile == TREE:
			grid[c.y][c.x] = DIRT


static func _stamp_dirt(grid: Array, x: int, y: int, radius: int, width: int, height: int) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var p := Vector2i(x + dx, y + dy)
			if not _inner(p.x, p.y, width, height):
				continue
			var tile := int(grid[p.y][p.x])
			if tile != CLIFF and tile != STAIRS and tile != WATER:
				grid[p.y][p.x] = DIRT


static func _looks_like_main_trail(grid: Array, p: Vector2i) -> bool:
	var north_hits := 0
	var south_hits := 0
	for distance: int in [1, 2, 3]:
		var north_y: int = p.y - distance
		var south_y: int = p.y + distance
		if north_y >= 0:
			for x: int in range(maxi(0, p.x - 1), mini(grid[north_y].size(), p.x + 2)):
				if int(grid[north_y][x]) == DIRT:
					north_hits += 1
					break
		if south_y < grid.size():
			for x: int in range(maxi(0, p.x - 1), mini(grid[south_y].size(), p.x + 2)):
				if int(grid[south_y][x]) == DIRT:
					south_hits += 1
					break
	return north_hits >= 2 and south_hits >= 2


static func _near_tile(grid: Array, p: Vector2i, tile_id: int, radius: int) -> bool:
	for y: int in range(maxi(0, p.y - radius), mini(grid.size(), p.y + radius + 1)):
		var row: Array = grid[y]
		for x: int in range(maxi(0, p.x - radius), mini(row.size(), p.x + radius + 1)):
			if int(grid[y][x]) == tile_id:
				return true
	return false


static func _cells_of(grid: Array, tile_id: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in grid.size():
		var row: Array = grid[y]
		for x: int in row.size():
			if int(row[x]) == tile_id:
				out.append(Vector2i(x, y))
	return out


static func _inner(x: int, y: int, width: int, height: int) -> bool:
	return x >= 2 and y >= 2 and x < width - 2 and y < height - 2