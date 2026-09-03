extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Wyrdling density test ===")
	var db: Node = root.get_node_or_null("DataDB")
	var gs: Node = root.get_node_or_null("GameState")
	if db == null or gs == null:
		printerr("density test autoloads missing")
		quit(1)
		return
	if db.creatures.is_empty():
		db._load_data()

	gs.rng.seed = 424242
	gs.start_run("glimmerling")
	var trees_before: int = gs.trees.size()
	var props_before: int = gs.world_props.size()
	var tall_before: int = _count_tile(gs, 5)

	var packed: PackedScene = load("res://scenes/dungeon.tscn")
	_expect(packed != null, "dense dungeon scene loads")
	if packed == null:
		quit(1)
		return

	var node: Node = packed.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame

	var trees_added: int = gs.trees.size() - trees_before
	var props_added: int = gs.world_props.size() - props_before
	var tall_added: int = _count_tile(gs, 5) - tall_before
	print("floor 1 density additions trees=", trees_added, " props=", props_added, " tall_grass_cells=", tall_added)

	_expect(trees_added >= 15, "forest framing adds substantial tree density (%d)" % trees_added)
	_expect(props_added >= 28, "route dressing adds substantial prop density (%d)" % props_added)
	_expect(tall_added >= 30, "tall-grass gardens fill open meadow space (%d cells)" % tall_added)
	_expect(_has_walkable_path(gs, gs.player_pos, gs.stairs_pos), "density pass preserves start-to-exit traversal")
	_expect(_interactions_have_access(gs), "landmark interactions retain adjacent walkable access")

	# Regression coverage for the PR review: GameState.descend() replaces the
	# whole generated route before the inherited dungeon repaints it. The top
	# presentation layer must therefore apply the complete scenery chain again
	# when _paint_map() is called for the new floor.
	gs.descend()
	var floor2_trees_before: int = gs.trees.size()
	var floor2_props_before: int = gs.world_props.size()
	var floor2_tall_before: int = _count_tile(gs, 5)
	node.call("_paint_map")
	await process_frame

	var floor2_trees_added: int = gs.trees.size() - floor2_trees_before
	var floor2_props_added: int = gs.world_props.size() - floor2_props_before
	var floor2_tall_added: int = _count_tile(gs, 5) - floor2_tall_before
	print("floor 2 density additions trees=", floor2_trees_added, " props=", floor2_props_added, " tall_grass_cells=", floor2_tall_added)

	_expect(gs.floor_num == 2, "descended to route 2")
	_expect(floor2_trees_added >= 10, "route 2 receives forest density (%d)" % floor2_trees_added)
	_expect(floor2_props_added >= 20, "route 2 receives prop dressing (%d)" % floor2_props_added)
	_expect(floor2_tall_added >= 20, "route 2 receives tall-grass density (%d cells)" % floor2_tall_added)
	_expect(_has_walkable_path(gs, gs.player_pos, gs.stairs_pos), "route 2 remains traversable after density")
	_expect(_interactions_have_access(gs), "route 2 landmark interactions remain accessible")

	# Repainting the same route must be idempotent. Otherwise every refresh would
	# keep stacking bushes, trees and grass until the map eventually breaks.
	var stable_trees: int = gs.trees.size()
	var stable_props: int = gs.world_props.size()
	var stable_tall: int = _count_tile(gs, 5)
	node.call("_paint_map")
	await process_frame
	_expect(gs.trees.size() == stable_trees, "same-floor repaint does not duplicate trees")
	_expect(gs.world_props.size() == stable_props, "same-floor repaint does not duplicate props")
	_expect(_count_tile(gs, 5) == stable_tall, "same-floor repaint does not duplicate tall grass")

	if is_instance_valid(node):
		node.queue_free()
	await process_frame

	if failures > 0:
		printerr("density test failed: %d checks" % failures)
		quit(1)
	else:
		print("=== DENSITY TEST OK ===")
		quit(0)


func _count_tile(gs: Node, tile_id: int) -> int:
	var total := 0
	for y: int in gs.MAP_H:
		for x: int in gs.MAP_W:
			if int(gs.grid[y][x]) == tile_id:
				total += 1
	return total


func _has_walkable_path(gs: Node, start: Vector2i, goal: Vector2i) -> bool:
	var queue: Array[Vector2i] = [start]
	var seen: Dictionary = {start: true}
	var cursor := 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while cursor < queue.size():
		var p: Vector2i = queue[cursor]
		cursor += 1
		if p == goal:
			return true
		for d: Vector2i in dirs:
			var n := p + d
			if seen.has(n) or not gs.walkable(n):
				continue
			seen[n] = true
			queue.append(n)
	return false


func _interactions_have_access(gs: Node) -> bool:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for raw in gs.world_props:
		var prop: Dictionary = raw
		if not prop.has("interact_pos"):
			continue
		var target: Vector2i = prop["interact_pos"]
		var accessible := false
		for d: Vector2i in dirs:
			if gs.walkable(target + d):
				accessible = true
				break
		if not accessible:
			print("interaction blocked: ", prop.get("kind", "prop"), " at ", target)
			return false
	return true


func _expect(ok: bool, label: String) -> void:
	if ok:
		print("OK    ", label)
	else:
		print("FAIL  ", label)
		failures += 1
