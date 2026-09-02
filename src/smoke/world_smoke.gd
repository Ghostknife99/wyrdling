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
	failed += _expect(gs.world_props.size() >= 20, "route has substantial prop dressing (%d)" % gs.world_props.size())

	var kinds: Dictionary = {}
	var npc_count := 0
	var sign_count := 0
	for raw in gs.world_props:
		var prop: Dictionary = raw
		var kind := str(prop.get("kind", ""))
		kinds[kind] = true
		if kind == "npc":
			npc_count += 1
		elif kind == "sign":
			sign_count += 1

	failed += _expect(kinds.has("lodge"), "Riftkeeper Lodge generated")
	failed += _expect(kinds.has("cave"), "Echo Cave generated")
	failed += _expect(npc_count >= 2, "route NPCs generated (%d)" % npc_count)
	failed += _expect(sign_count >= 1, "route signs generated (%d)" % sign_count)
	failed += _expect(kinds.has("flowers_a") or kinds.has("flowers_b"), "flowers generated")
	failed += _expect(kinds.has("bush") or kinds.has("rock") or kinds.has("stump"), "solid route props generated")

	var interactive_count := 0
	var lodge_ok := false
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
	failed += _expect(interactive_count >= 4, "multiple world interactions (%d)" % interactive_count)
	failed += _expect(lodge_ok, "lodge door is blocked and interactable")

	var active: WyrdlingCreature = gs.active()
	active.hp = 1
	var healed: int = gs.mend_party(0.35)
	failed += _expect(healed > 0 and active.hp > 1, "lodge-style party mend works")

	var first_name := str(gs.area_name)
	gs.descend()
	failed += _expect(str(gs.area_name) != first_name, "descending advances to a new named route")
	failed += _expect(gs.world_props.size() >= 20, "next route remains fully dressed")

	if failed == 0:
		print("=== WORLD SMOKE OK ===")
		quit(0)
	else:
		print("=== WORLD SMOKE FAILED (%d) ===" % failed)
		quit(1)


func _expect(cond: bool, label: String) -> int:
	if cond:
		print("OK    ", label)
		return 0
	print("FAIL  ", label)
	return 1
