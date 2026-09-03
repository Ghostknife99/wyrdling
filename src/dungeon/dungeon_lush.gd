extends "res://src/dungeon/dungeon_dense.gd"
## Final forest-growth layer for Willowmere.
##
## The density pass adds quantity and feature pockets. This layer turns the
## remaining spaced-out trees into connected woodland, fills quiet map sectors,
## and landscapes the route/landmark edges so polished features do not sit in
## empty halos of plain grass.

const LUSH_TREE := 6
const LUSH_GRASS := 1
const LUSH_TALLGRASS := 5
const LUSH_DIRT := 3
const LUSH_WATER := 4
const LUSH_CLIFF := 0
const FOREST_GROWTH_TARGET := 48
const SECTOR_SIZE := 8
const MIN_SECTOR_DENSITY := 18


func _apply_density_pass() -> void:
	super._apply_density_pass()
	_grow_connected_forest()
	_fill_sparse_sectors()
	_landscape_trail_verges()
	_dress_major_landmarks()


func _grow_connected_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xB10550 + GameState.floor_num * 7919
	var protected: Dictionary = _build_protected_cells(1, false)
	var frontier: Array[Vector2i] = []
	for tree_variant in GameState.trees:
		frontier.append(tree_variant)

	var added := 0
	var attempts := 0
	while added < FOREST_GROWTH_TARGET and not frontier.is_empty() and attempts < 2400:
		attempts += 1
		var seed_index := rng.randi_range(0, frontier.size() - 1)
		var seed: Vector2i = frontier[seed_index]
		var offsets: Array[Vector2i] = [
			Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
			Vector2i(2, 2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(-2, -2),
		]
		var candidate := seed + offsets[rng.randi_range(0, offsets.size() - 1)]
		if not _lush_tree_site_clear(candidate, protected):
			if attempts % 5 == 0 and frontier.size() > 24:
				frontier.remove_at(seed_index)
			continue

		var edge_distance: int = mini(
			mini(candidate.x, GameState.MAP_W - 2 - candidate.x),
			mini(candidate.y, GameState.MAP_H - 2 - candidate.y)
		)
		var neighbours := _touching_tree_count(candidate)
		if edge_distance > 11 and neighbours < 2 and rng.randf() < 0.72:
			continue

		_place_lush_tree(candidate)
		frontier.append(candidate)
		added += 1

	print("lush forest growth added ", added, " connected trees")


func _fill_sparse_sectors() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5EC70 + GameState.floor_num * 3571
	var protected: Dictionary = _build_protected_cells(1, false)
	var filled := 0

	for sy: int in range(2, GameState.MAP_H - 2, SECTOR_SIZE):
		for sx: int in range(2, GameState.MAP_W - 2, SECTOR_SIZE):
			var sector := Rect2i(sx, sy, mini(SECTOR_SIZE, GameState.MAP_W - 2 - sx), mini(SECTOR_SIZE, GameState.MAP_H - 2 - sy))
			if sector.size.x < 5 or sector.size.y < 5:
				continue
			if _sector_density(sector) >= MIN_SECTOR_DENSITY:
				continue
			if _sector_tile_count(sector, LUSH_DIRT) >= 12:
				continue

			var center := Vector2i(sector.position.x + int(sector.size.x / 2), sector.position.y + int(sector.size.y / 2))
			var sector_parity: int = int(sx / SECTOR_SIZE) + int(sy / SECTOR_SIZE) + GameState.floor_num
			var made_feature := false
			if sector_parity % 2 == 0:
				made_feature = _plant_sector_grove(center, sector, protected, rng)
			if not made_feature:
				made_feature = _plant_sector_undergrowth(center, sector, protected, rng)
			if not made_feature:
				made_feature = _plant_sector_grove(center, sector, protected, rng)
			if made_feature:
				filled += 1

	print("lush sparse-sector pass filled ", filled, " quiet sectors")


func _landscape_trail_verges() -> void:
	var protected: Dictionary = _build_protected_cells(1)
	var landscaped := 0
	for y: int in range(8, GameState.MAP_H - 8, 5):
		var dirt_xs: Array[int] = []
		for x: int in range(5, GameState.MAP_W - 5):
			if int(GameState.grid[y][x]) == LUSH_DIRT:
				dirt_xs.append(x)
		if dirt_xs.is_empty():
			continue

		# Pick the path cell closest to the map centre. Side branches usually sit
		# farther out and therefore do not all receive identical verge gardens.
		var path_x: int = dirt_xs[0]
		var best_distance := 9999
		for x: int in dirt_xs:
			var d := absi(x - int(GameState.MAP_W / 2))
			if d < best_distance:
				best_distance = d
				path_x = x

		var side := -1 if ((y / 5) as int + GameState.floor_num) % 2 == 0 else 1
		var center := Vector2i(path_x + side * 4, y)
		if _paint_verge_patch(center, protected):
			var accent := center + Vector2i(-side * 2, 1)
			if _soft_prop_clear(accent, protected):
				GameState.world_props.append({"kind": "flowers_a" if y % 10 == 0 else "flowers_b", "pos": accent, "blocks": []})
				protected[accent] = true
			landscaped += 1

	print("lush trail landscaping added ", landscaped, " verge pockets")


func _dress_major_landmarks() -> void:
	var protected: Dictionary = _build_protected_cells(1)
	for prop_variant in GameState.world_props.duplicate():
		var prop: Dictionary = prop_variant
		var kind := str(prop.get("kind", ""))
		if not (kind in ["cave", "lodge", "riftstone"]):
			continue
		var blocks: Array = prop.get("blocks", [])
		var anchor: Vector2i = prop.get("pos", Vector2i.ZERO)
		if not blocks.is_empty():
			var min_x := anchor.x
			var max_x := anchor.x
			var min_y := anchor.y
			var max_y := anchor.y
			for block_variant in blocks:
				var b: Vector2i = block_variant
				min_x = mini(min_x, b.x)
				max_x = maxi(max_x, b.x)
				min_y = mini(min_y, b.y)
				max_y = maxi(max_y, b.y)
			anchor = Vector2i(int((min_x + max_x) / 2), int((min_y + max_y) / 2))

		var offsets: Array[Vector2i] = [
			Vector2i(-5, -1), Vector2i(-5, 1), Vector2i(5, -1), Vector2i(5, 1),
			Vector2i(-4, 3), Vector2i(4, 3),
		]
		for i: int in offsets.size():
			var p := anchor + offsets[i]
			if i < 4:
				_paint_verge_patch(p, protected, 1)
			else:
				if _soft_prop_clear(p, protected):
					GameState.world_props.append({"kind": "mushrooms" if i % 2 == 0 else "flowers_a", "pos": p, "blocks": []})
					protected[p] = true


func _paint_verge_patch(center: Vector2i, protected: Dictionary, radius: int = 1) -> bool:
	var changed := 0
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var p := center + Vector2i(dx, dy)
			if not _inside(p) or protected.has(p):
				continue
			if int(GameState.grid[p.y][p.x]) != LUSH_GRASS:
				continue
			if _near_tile(p, LUSH_DIRT, 1) or _near_tile(p, LUSH_WATER, 0):
				continue
			GameState.grid[p.y][p.x] = LUSH_TALLGRASS
			changed += 1
	return changed >= 3


func _soft_prop_clear(p: Vector2i, protected: Dictionary) -> bool:
	if not _inside(p) or protected.has(p):
		return false
	if int(GameState.grid[p.y][p.x]) != LUSH_GRASS:
		return false
	if _near_tile(p, LUSH_DIRT, 0) or _near_tile(p, LUSH_WATER, 0):
		return false
	return true


func _sector_density(sector: Rect2i) -> int:
	var score := 0
	for y: int in range(sector.position.y, sector.end.y):
		for x: int in range(sector.position.x, sector.end.x):
			var tile: int = int(GameState.grid[y][x])
			if tile == LUSH_TALLGRASS:
				score += 1
			elif tile == LUSH_WATER or tile == LUSH_CLIFF or tile == LUSH_TREE:
				score += 1
	for tree_variant in GameState.trees:
		var tree: Vector2i = tree_variant
		if sector.has_point(tree):
			score += 5
	for prop_variant in GameState.world_props:
		var prop: Dictionary = prop_variant
		var p: Vector2i = prop.get("pos", Vector2i(-99, -99))
		if sector.has_point(p):
			var kind := str(prop.get("kind", ""))
			if kind in ["lodge", "cave", "bridge", "riftstone"]:
				score += 12
			elif kind == "npc" or kind == "sign":
				score += 5
			else:
				score += 3
	return score


func _sector_tile_count(sector: Rect2i, tile_id: int) -> int:
	var count := 0
	for y: int in range(sector.position.y, sector.end.y):
		for x: int in range(sector.position.x, sector.end.x):
			if int(GameState.grid[y][x]) == tile_id:
				count += 1
	return count


func _plant_sector_grove(center: Vector2i, sector: Rect2i, protected: Dictionary, rng: RandomNumberGenerator) -> bool:
	var offsets: Array[Vector2i] = [
		Vector2i(-2, -2), Vector2i(0, -2), Vector2i(2, -2),
		Vector2i(-2, 0), Vector2i(0, 0), Vector2i(2, 0),
		Vector2i(-2, 2), Vector2i(0, 2), Vector2i(2, 2),
	]
	var start_index := rng.randi_range(0, offsets.size() - 1)
	var planted := 0
	for i: int in offsets.size():
		var nw := center + offsets[(start_index + i) % offsets.size()]
		if not sector.has_point(nw) or not sector.has_point(nw + Vector2i(1, 1)):
			continue
		if not _lush_tree_site_clear(nw, protected):
			continue
		_place_lush_tree(nw)
		planted += 1
		if planted >= 3:
			break
	return planted >= 2


func _plant_sector_undergrowth(center: Vector2i, sector: Rect2i, protected: Dictionary, rng: RandomNumberGenerator) -> bool:
	var changed := 0
	for dy: int in range(-2, 3):
		for dx: int in range(-3, 4):
			var p := center + Vector2i(dx, dy)
			if not sector.has_point(p) or not _inside(p) or protected.has(p):
				continue
			if int(GameState.grid[p.y][p.x]) != LUSH_GRASS:
				continue
			if _near_tile(p, LUSH_DIRT, 1) or _near_tile(p, LUSH_WATER, 0):
				continue
			if absi(dx) == 3 or absi(dy) == 2:
				if (p.x * 7 + p.y * 13 + GameState.floor_num) % 3 == 0:
					continue
			GameState.grid[p.y][p.x] = LUSH_TALLGRASS
			changed += 1

	if changed >= 8:
		var accent := center + Vector2i(3 if rng.randf() < 0.5 else -3, 0)
		if sector.has_point(accent) and _soft_prop_clear(accent, protected):
			GameState.world_props.append({"kind": "flowers_a" if rng.randf() < 0.5 else "flowers_b", "pos": accent, "blocks": []})
		return true
	return false


func _place_lush_tree(candidate: Vector2i) -> void:
	for dx in 2:
		GameState.grid[candidate.y + 1][candidate.x + dx] = LUSH_TREE
	GameState.trees.append(candidate)


func _lush_tree_site_clear(nw: Vector2i, protected: Dictionary) -> bool:
	if not _inside(nw) or not _inside(nw + Vector2i(1, 1)):
		return false
	if _near_tile(nw + Vector2i(1, 1), LUSH_DIRT, 2):
		return false
	if _near_tile(nw + Vector2i(1, 1), LUSH_WATER, 1):
		return false
	for dy in 2:
		for dx in 2:
			var p := nw + Vector2i(dx, dy)
			if protected.has(p):
				return false
			var tile: int = int(GameState.grid[p.y][p.x])
			if tile != LUSH_GRASS and tile != LUSH_TALLGRASS:
				return false
	for tree_variant in GameState.trees:
		var existing: Vector2i = tree_variant
		if absi(existing.x - nw.x) < 2 and absi(existing.y - nw.y) < 2:
			return false
	return true


func _touching_tree_count(nw: Vector2i) -> int:
	var count := 0
	for tree_variant in GameState.trees:
		var existing: Vector2i = tree_variant
		var dx := absi(existing.x - nw.x)
		var dy := absi(existing.y - nw.y)
		if (dx == 2 and dy <= 2) or (dy == 2 and dx <= 2):
			count += 1
	return count
