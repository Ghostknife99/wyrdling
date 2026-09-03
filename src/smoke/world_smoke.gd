extends SceneTree


func _initialize() -> void:
	print("=== Wyrdling world smoke ===")
	var db: Node = root.get_node_or_null("DataDB")
	var gs: Node = root.get_node_or_null("GameState")
	if db == null or gs == null:
		print("FAIL  world smoke autoloads missing")
		quit(1)
		return
	if db.creatures.is_empty():
		db._load_data()

	gs.rng.seed = 424242
	gs.start_run("glimmerling")
	var failed := 0
	failed += _expect(not str(gs.area_name).is_empty(), "route has a name")
	failed += _expect(gs.world_props.size() >= 24, "route has substantial prop dressing (%d)" % gs.world_props.size())

	var kinds: Dictionary = {}
	var npc_count := 0
	var sign_count := 0
	var bridge: Dictionary = {}
	var riftstone: Dictionary = {}
	for raw in gs.world_props:
		var prop: Dictionary = raw
		var kind := str(prop.get("kind", ""))
		kinds[kind] = true
		if kind == "npc":
			npc_count += 1
		elif kind == "sign":
			sign_count += 1
		elif kind == "bridge":
			bridge = prop
		elif kind == "riftstone":
			riftstone = prop

	failed += _expect(kinds.has("lodge"), "Riftkeeper Lodge generated")
	failed += _expect(kinds.has("cave"), "Echo Cave generated")
	failed += _expect(kinds.has("bridge"), "Willowspan Bridge generated")
	failed += _expect(kinds.has("riftstone"), "Old Wyrdling Riftstone generated")
	failed += _expect(npc_count >= 2, "route NPCs generated (%d)" % npc_count)
	failed += _expect(sign_count >= 1, "route signs generated (%d)" % sign_count)
	failed += _expect(kinds.has("flowers_a") or kinds.has("flowers_b"), "flowers generated")
	failed += _expect(kinds.has("bush") or kinds.has("rock") or kinds.has("stump"), "solid route props generated")

	var water_count := 0
	var interior_cliffs := 0
	for y: int in gs.MAP_H:
		for x: int in gs.MAP_W:
			var tile := int(gs.grid[y][x])
			if tile == 4:
				water_count += 1
			elif tile == 0 and x >= 3 and y >= 3 and x < gs.MAP_W - 3 and y < gs.MAP_H - 3:
				interior_cliffs += 1
	failed += _expect(water_count >= 75, "river/pond water composition is substantial (%d cells)" % water_count)
	failed += _expect(interior_cliffs >= 25, "interior cliff shelves generated (%d cells)" % interior_cliffs)
	failed += _expect(gs.trees.size() >= 105, "dense forest composition generated (%d trees)" % gs.trees.size())

	if not bridge.is_empty():
		var bridge_blocks: Array = bridge.get("blocks", [])
		failed += _expect(bridge_blocks.size() >= 12, "bridge has a substantial footprint")
		var bridge_walkable := true
		var bridge_over_water := false
		for raw_cell in bridge_blocks:
			var cell: Vector2i = raw_cell
			bridge_walkable = bridge_walkable and gs.walkable(cell)
			if int(gs.grid[cell.y][cell.x]) == 4:
				bridge_over_water = true
		failed += _expect(bridge_walkable, "every bridge cell is walkable")
		failed += _expect(bridge_over_water, "bridge genuinely crosses water")

	failed += _expect(_has_walkable_path(gs, gs.player_pos, gs.stairs_pos), "walkable route still reaches the rift-gate")

	var interactive_count := 0
	var lodge_ok := false
	var riftstone_ok := false
	for raw in gs.world_props:
		var prop: Dictionary = raw
		if not prop.has("interact_pos"):
			continue
		interactive_count += 1
		var target: Vector2i = prop["interact_pos"]
		var found: Dictionary = gs.interactable_at(target)
		failed += _expect(not found.is_empty(), "%s interaction resolves" % str(prop.get("kind", "prop")))
		if str(prop.get("kind", "")) == "lodge":
			lodge_ok = gs.prop_blocks(target)
		elif str(prop.get("kind", "")) == "riftstone":
			riftstone_ok = not found.is_empty()
	failed += _expect(interactive_count >= 5, "multiple world interactions (%d)" % interactive_count)
	failed += _expect(lodge_ok, "lodge door is blocked and interactable")
	failed += _expect(riftstone_ok, "riftstone is a usable landmark")

	var active: WyrdlingCreature = gs.active()
	active.hp = 1
	var healed: int = gs.mend_party(0.35)
	failed += _expect(healed > 0 and active.hp > 1, "lodge-style party mend works")

	var first_name := str(gs.area_name)
	gs.descend()
	failed += _expect(str(gs.area_name) != first_name, "descending advances to a new named route")
	failed += _expect(gs.world_props.size() >= 24, "next route remains fully dressed")
	failed += _expect(_has_kind(gs.world_props, "bridge") and _has_kind(gs.world_props, "riftstone"), "next route keeps bridge and landmark composition")
	failed += _expect(_has_walkable_path(gs, gs.player_pos, gs.stairs_pos), "next route remains fully traversable")

	if failed == 0:
		print("=== WORLD SMOKE OK ===")
		quit(0)
	else:
		print("=== WORLD SMOKE FAILED (%d) ===" % failed)
		quit(1)


func _has_kind(props: Array, wanted: String) -> bool:
	for raw in props:
		var prop: Dictionary = raw
		if str(prop.get("kind", "")) == wanted:
			return true
	return false


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


func _expect(cond: bool, label: String) -> int:
	if cond:
		print("OK    ", label)
		return 0
	print("FAIL  ", label)
	return 1
