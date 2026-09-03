extends "res://src/dungeon/dungeon_16.gd"
## Final Willowmere density pass.
##
## The underlying route generator stays responsible for progression and major
## landmarks. This layer fills the unused grass between those landmarks with
## authored-looking undergrowth, forest framing and small prop clusters before
## the normal 16px renderer builds the scene.

const DENSE_GRASS := 1
const DENSE_DIRT := 3
const DENSE_WATER := 4
const DENSE_TALLGRASS := 5
const DENSE_TREE := 6

const TALL_GRASS_PATCHES := 12
const EXTRA_TREE_TARGET := 34
const SOLID_PROP_TARGET := 15
const SOFT_PROP_TARGET := 34


func _ready() -> void:
	_apply_density_pass()
	super._ready()


func _apply_density_pass() -> void:
	if GameState.grid.is_empty():
		return

	# Keep density deterministic for a given floor without consuming GameState's
	# encounter RNG. Reloading a route therefore gives the same scenery dressing.
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x57A11 + GameState.floor_num * 10007

	var protected := _build_protected_cells(1)
	_add_tall_grass_gardens(rng, protected)

	protected = _build_protected_cells(1)
	_add_forest_frame(rng, protected)

	protected = _build_protected_cells(1)
	_add_solid_prop_clusters(rng, protected)

	protected = _build_protected_cells(0)
	_add_soft_ground_detail(rng, protected)
	_dress_riverbanks(rng, protected)


func _build_protected_cells(radius: int) -> Dictionary:
	var raw: Dictionary = {}
	raw[GameState.player_pos] = true
	raw[GameState.stairs_pos] = true

	for wild in GameState.wilds:
		raw[wild.get("pos", Vector2i.ZERO)] = true

	for fence_item in GameState.fence:
		raw[fence_item.get("pos", Vector2i.ZERO)] = true

	for prop_variant in GameState.world_props:
		var prop: Dictionary = prop_variant
		for cell_variant in prop.get("blocks", []):
			raw[cell_variant] = true
		if prop.has("interact_pos"):
			raw[prop["interact_pos"]] = true

	for nw_variant in GameState.trees:
		var nw: Vector2i = nw_variant
		for dy in 2:
			for dx in 2:
				raw[nw + Vector2i(dx, dy)] = true

	if radius <= 0:
		return raw

	var expanded: Dictionary = {}
	for cell_variant in raw.keys():
		var cell: Vector2i = cell_variant
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				expanded[cell + Vector2i(dx, dy)] = true
	return expanded


func _add_tall_grass_gardens(rng: RandomNumberGenerator, protected: Dictionary) -> void:
	var centers: Array[Vector2i] = []
	var attempts := 0
	while centers.size() < TALL_GRASS_PATCHES and attempts < 550:
		attempts += 1
		var center := Vector2i(
			rng.randi_range(5, GameState.MAP_W - 6),
			rng.randi_range(5, GameState.MAP_H - 6)
		)
		if protected.has(center) or int(GameState.grid[center.y][center.x]) != DENSE_GRASS:
			continue

		# The reference look gets much of its density from chunky grass gardens
		# bordering the path. Prefer those, but leave some deeper meadow patches too.
		var near_path := _near_tile(center, DENSE_DIRT, 5)
		if not near_path and rng.randf() < 0.62:
			continue
		if _near_tile(center, DENSE_WATER, 1):
			continue

		var spaced := true
		for other: Vector2i in centers:
			if center.distance_to(other) < 6.0:
				spaced = false
				break
		if not spaced:
			continue
		centers.append(center)

	for center: Vector2i in centers:
		var rx := rng.randi_range(2, 4)
		var ry := rng.randi_range(2, 3)
		for y: int in range(center.y - ry, center.y + ry + 1):
			for x: int in range(center.x - rx, center.x + rx + 1):
				var p := Vector2i(x, y)
				if not _inside(p) or protected.has(p):
					continue
				if int(GameState.grid[y][x]) != DENSE_GRASS:
					continue
				var nx := float(x - center.x) / float(maxi(rx, 1))
				var ny := float(y - center.y) / float(maxi(ry, 1))
				if nx * nx + ny * ny > 1.12:
					continue
				# Broken edges stop each patch looking like a stamped rectangle.
				if nx * nx + ny * ny > 0.58 and ((x * 19 + y * 31 + GameState.floor_num * 7) % 5 == 0):
					continue
				GameState.grid[y][x] = DENSE_TALLGRASS


func _add_forest_frame(rng: RandomNumberGenerator, protected: Dictionary) -> void:
	var added := 0
	var attempts := 0
	while added < EXTRA_TREE_TARGET and attempts < 1300:
		attempts += 1
		var nw := Vector2i(
			rng.randi_range(3, GameState.MAP_W - 5),
			rng.randi_range(3, GameState.MAP_H - 5)
		)
		if not _tree_site_clear(nw, protected):
			continue

		var edge_distance: int = mini(mini(nw.x, GameState.MAP_W - 2 - nw.x), mini(nw.y, GameState.MAP_H - 2 - nw.y))
		var near_existing_tree := _near_existing_tree(nw, 6)
		# Heavily favour map edges and existing forest so trees form masses/walls
		# rather than another layer of evenly scattered singles.
		if edge_distance > 12 and not near_existing_tree and rng.randf() < 0.82:
			continue
		if edge_distance > 8 and not near_existing_tree and rng.randf() < 0.48:
			continue

		for dx in 2:
			GameState.grid[nw.y + 1][nw.x + dx] = DENSE_TREE
		GameState.trees.append(nw)
		for dy in 2:
			for dx in 2:
				protected[nw + Vector2i(dx, dy)] = true
		added += 1


func _tree_site_clear(nw: Vector2i, protected: Dictionary) -> bool:
	if not _inside(nw) or not _inside(nw + Vector2i(1, 1)):
		return false
	if _near_tile(nw + Vector2i(1, 1), DENSE_DIRT, 2):
		return false
	if _near_tile(nw + Vector2i(1, 1), DENSE_WATER, 1):
		return false
	for dy in 2:
		for dx in 2:
			var p := nw + Vector2i(dx, dy)
			if protected.has(p):
				return false
			var tile := int(GameState.grid[p.y][p.x])
			if tile != DENSE_GRASS and tile != DENSE_TALLGRASS:
				return false
	for existing_variant in GameState.trees:
		var existing: Vector2i = existing_variant
		if absi(existing.x - nw.x) < 2 and absi(existing.y - nw.y) < 2:
			return false
	return true


func _near_existing_tree(p: Vector2i, radius: int) -> bool:
	for existing_variant in GameState.trees:
		var existing: Vector2i = existing_variant
		if absi(existing.x - p.x) <= radius and absi(existing.y - p.y) <= radius:
			return true
	return false


func _add_solid_prop_clusters(rng: RandomNumberGenerator, protected: Dictionary) -> void:
	var kinds: Array[String] = ["rock", "stump", "bush", "rock", "stump"]
	var placed := 0
	var attempts := 0
	while placed < SOLID_PROP_TARGET and attempts < 800:
		attempts += 1
		var p := Vector2i(
			rng.randi_range(4, GameState.MAP_W - 5),
			rng.randi_range(4, GameState.MAP_H - 5)
		)
		if protected.has(p) or int(GameState.grid[p.y][p.x]) != DENSE_GRASS:
			continue
		if _near_tile(p, DENSE_DIRT, 2):
			continue
		# Put solids where scenery already has structure: forest edges, riverbanks
		# and cliff pockets. This reads as intentional composition rather than noise.
		var scenic := _near_existing_tree(p, 5) or _near_tile(p, DENSE_WATER, 3) or _near_tile(p, 0, 3)
		if not scenic and rng.randf() < 0.75:
			continue

		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		GameState.world_props.append({"kind": kind, "pos": p, "blocks": [p]})
		protected[p] = true
		placed += 1

	# Fallen logs give the forest a few wider shapes, which is important when the
	# rest of the scenery is built from mostly 1- and 2-tile objects.
	var log_count := 0
	attempts = 0
	while log_count < 5 and attempts < 500:
		attempts += 1
		var p := Vector2i(
			rng.randi_range(4, GameState.MAP_W - 7),
			rng.randi_range(4, GameState.MAP_H - 5)
		)
		var right := p + Vector2i(1, 0)
		if protected.has(p) or protected.has(right):
			continue
		if int(GameState.grid[p.y][p.x]) != DENSE_GRASS or int(GameState.grid[right.y][right.x]) != DENSE_GRASS:
			continue
		if _near_tile(p, DENSE_DIRT, 3) or not _near_existing_tree(p, 6):
			continue
		GameState.world_props.append({"kind": "fallen_log", "pos": p, "blocks": [p, right]})
		protected[p] = true
		protected[right] = true
		log_count += 1


func _add_soft_ground_detail(rng: RandomNumberGenerator, protected: Dictionary) -> void:
	var kinds: Array[String] = ["flowers_a", "flowers_b", "mushrooms", "flowers_a", "flowers_b"]
	var placed := 0
	var attempts := 0
	while placed < SOFT_PROP_TARGET and attempts < 1100:
		attempts += 1
		var p := Vector2i(
			rng.randi_range(3, GameState.MAP_W - 4),
			rng.randi_range(3, GameState.MAP_H - 4)
		)
		if protected.has(p) or int(GameState.grid[p.y][p.x]) != DENSE_GRASS:
			continue
		if _near_tile(p, DENSE_DIRT, 0):
			continue
		var scenic := _near_tile(p, DENSE_TALLGRASS, 2) or _near_existing_tree(p, 4) or _near_tile(p, DENSE_WATER, 3)
		if not scenic and rng.randf() < 0.68:
			continue
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		GameState.world_props.append({"kind": kind, "pos": p, "blocks": []})
		protected[p] = true
		placed += 1


func _dress_riverbanks(rng: RandomNumberGenerator, protected: Dictionary) -> void:
	var candidates: Array[Vector2i] = []
	for y: int in range(3, GameState.MAP_H - 3):
		for x: int in range(3, GameState.MAP_W - 3):
			var p := Vector2i(x, y)
			if protected.has(p) or int(GameState.grid[y][x]) != DENSE_GRASS:
				continue
			if not _near_tile(p, DENSE_WATER, 1):
				continue
			if _near_tile(p, DENSE_DIRT, 1):
				continue
			candidates.append(p)

	# Shuffle by random removal and only use a subset, so the river is detailed
	# without getting a dotted outline around every single water cell.
	var placed := 0
	while placed < 14 and not candidates.is_empty():
		var idx := rng.randi_range(0, candidates.size() - 1)
		var p: Vector2i = candidates[idx]
		candidates.remove_at(idx)
		var kind := "rock" if placed % 4 == 0 else ("mushrooms" if placed % 3 == 0 else "flowers_b")
		var blocks: Array = [p] if kind == "rock" else []
		GameState.world_props.append({"kind": kind, "pos": p, "blocks": blocks})
		protected[p] = true
		placed += 1


func _near_tile(p: Vector2i, tile_id: int, radius: int) -> bool:
	for y: int in range(maxi(0, p.y - radius), mini(GameState.MAP_H, p.y + radius + 1)):
		for x: int in range(maxi(0, p.x - radius), mini(GameState.MAP_W, p.x + radius + 1)):
			if int(GameState.grid[y][x]) == tile_id:
				return true
	return false


func _inside(p: Vector2i) -> bool:
	return p.x >= 2 and p.y >= 2 and p.x < GameState.MAP_W - 2 and p.y < GameState.MAP_H - 2
