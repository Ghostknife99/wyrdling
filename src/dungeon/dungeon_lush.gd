extends "res://src/dungeon/dungeon_dense.gd"
## Final forest-growth layer for Willowmere.
##
## The density pass adds quantity and feature pockets. This layer turns the
## remaining spaced-out trees into connected woodland by growing directly from
## existing groves. It runs inside the density hook, before the 16px renderer
## draws the world, so the result is still one normal playable map.

const LUSH_TREE := 6
const LUSH_GRASS := 1
const LUSH_TALLGRASS := 5
const LUSH_DIRT := 3
const LUSH_WATER := 4
const FOREST_GROWTH_TARGET := 48


func _apply_density_pass() -> void:
	super._apply_density_pass()
	_grow_connected_forest()


func _grow_connected_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xB10550 + GameState.floor_num * 7919

	# Protect gameplay objects/interactions but intentionally leave existing trees
	# out of the mask; they are the seeds that the new woodland grows from.
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

		# Tree sprites occupy 2x2 logical cells, so offsets of two make canopies
		# touch without overlapping. Diagonals are included to avoid ruler-straight
		# walls and make the belts feel naturally layered.
		var offsets: Array[Vector2i] = [
			Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
			Vector2i(2, 2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(-2, -2),
		]
		var offset: Vector2i = offsets[rng.randi_range(0, offsets.size() - 1)]
		var candidate := seed + offset
		if not _lush_tree_site_clear(candidate, protected):
			# Drop exhausted seeds occasionally so growth moves around the map rather
			# than hammering one fully surrounded tree forever.
			if attempts % 5 == 0 and frontier.size() > 24:
				frontier.remove_at(seed_index)
			continue

		# Strongly favour the outside of the route and established forest masses.
		# Inland trees can still grow, but they stop before swallowing meadow views.
		var edge_distance: int = mini(
			mini(candidate.x, GameState.MAP_W - 2 - candidate.x),
			mini(candidate.y, GameState.MAP_H - 2 - candidate.y)
		)
		var neighbours := _touching_tree_count(candidate)
		if edge_distance > 11 and neighbours < 2 and rng.randf() < 0.72:
			continue

		for dx in 2:
			GameState.grid[candidate.y + 1][candidate.x + dx] = LUSH_TREE
		GameState.trees.append(candidate)
		frontier.append(candidate)
		added += 1

	print("lush forest growth added ", added, " connected trees")


func _lush_tree_site_clear(nw: Vector2i, protected: Dictionary) -> bool:
	if not _inside(nw) or not _inside(nw + Vector2i(1, 1)):
		return false

	# Keep the actual walking route visually legible and physically generous.
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

	# Existing canopies may touch but never overlap.
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
