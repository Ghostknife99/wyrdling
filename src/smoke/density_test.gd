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
	print("density additions trees=", trees_added, " props=", props_added, " tall_grass_cells=", tall_added)

	_expect(trees_added >= 15, "forest framing adds substantial tree density (%d)" % trees_added)
	_expect(props_added >= 28, "route dressing adds substantial prop density (%d)" % props_added)
	_expect(tall_added >= 30, "tall-grass gardens fill open meadow space (%d cells)" % tall_added)
	_expect(_has_walkable_path(gs, gs.player_pos, gs.stairs_pos), "density pass preserves start-to-exit traversal")
	_expect(_interactions_have_access(gs), "landmark interactions retain adjacent walkable access")

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
