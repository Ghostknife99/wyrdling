extends RefCounted
## Replaces the three prototype route NPCs after world composition with a
## larger, directional 20-role population. Major route generation remains
## untouched; this pass only owns NPC selection and placement.

const GRASS := 1
const DIRT := 3
const TALLGRASS := 5
const NPC_TARGET := 4
const NPC_CATALOG = preload("res://src/dungeon/npc_catalog.gd")


static func apply(result: Dictionary, width: int, height: int, floor_num: int, rng: RandomNumberGenerator) -> Dictionary:
	if result.is_empty() or not result.has("grid"):
		return result

	var grid: Array = result["grid"]
	var start: Vector2i = result["start"]
	var stairs: Vector2i = result["stairs"]
	var props: Array = result.get("props", [])
	var trees: Array = result.get("trees", [])
	var fence: Array = result.get("fence", [])

	# Remove the old three-variant prototype NPCs before placing the polished set.
	for i: int in range(props.size() - 1, -1, -1):
		var existing: Dictionary = props[i]
		if str(existing.get("kind", "")) == "npc":
			props.remove_at(i)

	var blocked := _build_blocked(props, trees, fence, start, stairs)
	var candidates := _build_candidates(grid, blocked, width, height, start, stairs)
	var variants: Array[int] = []
	for index: int in NPC_CATALOG.TYPE_COUNT:
		variants.append(index)

	var placed_positions: Array[Vector2i] = []
	var target := NPC_TARGET + (1 if floor_num >= 4 else 0)
	_place_from_candidates(props, candidates, variants, placed_positions, target, 5.0, rng)
	# Dense seeds occasionally leave fewer widely separated spots. Relax spacing,
	# never collision rules, so every route still gets its population.
	if placed_positions.size() < target:
		_place_from_candidates(props, candidates, variants, placed_positions, target, 2.0, rng)

	result["props"] = props
	return result


static func _build_blocked(props: Array, trees: Array, fence: Array, start: Vector2i, stairs: Vector2i) -> Dictionary:
	var blocked: Dictionary = {start: true, stairs: true}
	for raw_fence in fence:
		var f: Dictionary = raw_fence
		blocked[f.get("pos", Vector2i.ZERO)] = true
	for raw_tree in trees:
		var nw: Vector2i = raw_tree
		for dy: int in 2:
			for dx: int in 2:
				blocked[nw + Vector2i(dx, dy)] = true
	for raw_prop in props:
		var prop: Dictionary = raw_prop
		blocked[prop.get("pos", Vector2i.ZERO)] = true
		for raw_cell in prop.get("blocks", []):
			blocked[raw_cell] = true
		if prop.has("interact_pos"):
			blocked[prop["interact_pos"]] = true
	return blocked


static func _build_candidates(grid: Array, blocked: Dictionary, width: int, height: int, start: Vector2i, stairs: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	var offsets: Array[Vector2i] = [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]

	for y: int in range(4, height - 4):
		for x: int in range(4, width - 4):
			if int(grid[y][x]) != DIRT:
				continue
			var anchor := Vector2i(x, y)
			if anchor.distance_to(start) < 7.0 or anchor.distance_to(stairs) < 4.0:
				continue
			for offset: Vector2i in offsets:
				var p := anchor + offset
				if not _inner(p, width, height) or blocked.has(p) or seen.has(p):
					continue
				if int(grid[p.y][p.x]) != GRASS:
					continue
				seen[p] = true
				out.append({"pos": p, "anchor": anchor, "facing": _face_toward(p, anchor)})
	return out


static func _place_from_candidates(props: Array, candidates: Array[Dictionary], variants: Array[int], placed_positions: Array[Vector2i], target: int, spacing: float, rng: RandomNumberGenerator) -> void:
	var attempts := 0
	while placed_positions.size() < target and not candidates.is_empty() and not variants.is_empty() and attempts < 500:
		attempts += 1
		var candidate_index := rng.randi_range(0, candidates.size() - 1)
		var candidate: Dictionary = candidates[candidate_index]
		candidates.remove_at(candidate_index)
		var p: Vector2i = candidate["pos"]

		var spaced := true
		for other: Vector2i in placed_positions:
			if p.distance_to(other) < spacing:
				spaced = false
				break
		if not spaced:
			continue

		var variant_slot := rng.randi_range(0, variants.size() - 1)
		var variant: int = variants[variant_slot]
		variants.remove_at(variant_slot)
		var npc: Dictionary = NPC_CATALOG.definition(variant)
		props.append({
			"kind": "npc",
			"variant": variant,
			"npc_id": npc["id"],
			"role": npc["role"],
			"facing": candidate["facing"],
			"pos": p,
			"blocks": [p],
			"interact_pos": p,
			"name": npc["name"],
			"text": npc["text"],
		})
		placed_positions.append(p)


static func _face_toward(from: Vector2i, target: Vector2i) -> String:
	var delta := target - from
	if absi(delta.x) >= absi(delta.y):
		return "right" if delta.x > 0 else "left"
	return "down" if delta.y > 0 else "up"


static func _inner(p: Vector2i, width: int, height: int) -> bool:
	return p.x >= 3 and p.y >= 3 and p.x < width - 3 and p.y < height - 3
