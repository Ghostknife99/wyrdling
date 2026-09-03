extends SceneTree

const CATALOG = preload("res://src/dungeon/npc_catalog.gd")
const ATLAS_PATH := "res://art/npcs/npc_atlas.png"


func _initialize() -> void:
	print("=== Wyrdling NPC quality test ===")
	var failed := 0

	failed += _expect(CATALOG.TYPES.size() == 20, "NPC catalog contains 20 distinct types")
	var ids: Dictionary = {}
	var names: Dictionary = {}
	for index: int in CATALOG.TYPE_COUNT:
		var npc: Dictionary = CATALOG.definition(index)
		ids[str(npc.get("id", ""))] = true
		names[str(npc.get("name", ""))] = true
	failed += _expect(ids.size() == 20, "all NPC type IDs are unique")
	failed += _expect(names.size() == 20, "all NPC display names are unique")

	failed += _expect(ResourceLoader.exists(ATLAS_PATH), "polished NPC atlas exists")
	if ResourceLoader.exists(ATLAS_PATH):
		var atlas: Texture2D = load(ATLAS_PATH)
		failed += _expect(atlas != null, "polished NPC atlas imports as a texture")
		if atlas != null:
			failed += _expect(atlas.get_width() == CATALOG.FRAME_W * 4, "NPC atlas has four directional columns")
			failed += _expect(atlas.get_height() == CATALOG.FRAME_H * CATALOG.TYPE_COUNT, "NPC atlas has twenty character rows")

		var image := Image.load_from_file(ATLAS_PATH)
		failed += _expect(image != null and not image.is_empty(), "NPC atlas pixels can be read")
		if image != null and not image.is_empty():
			var populated_frames := 0
			for variant: int in CATALOG.TYPE_COUNT:
				for facing: String in CATALOG.DIRECTIONS:
					var column := CATALOG.direction_column(facing)
					var frame := image.get_region(Rect2i(column * CATALOG.FRAME_W, variant * CATALOG.FRAME_H, CATALOG.FRAME_W, CATALOG.FRAME_H))
					if frame.get_used_rect().size != Vector2i.ZERO:
						populated_frames += 1
			failed += _expect(populated_frames == 80, "all 80 NPC directional frames contain artwork")

	var db: Node = root.get_node_or_null("DataDB")
	var gs: Node = root.get_node_or_null("GameState")
	if db == null or gs == null:
		failed += _expect(false, "NPC population test autoloads are available")
	else:
		if db.creatures.is_empty():
			db._load_data()
		gs.rng.seed = 314159
		gs.start_run("glimmerling")
		var npc_count := 0
		var variants: Dictionary = {}
		var valid_facing := true
		var interaction_ok := true
		for raw in gs.world_props:
			var prop: Dictionary = raw
			if str(prop.get("kind", "")) != "npc":
				continue
			npc_count += 1
			var variant := int(prop.get("variant", -1))
			variants[variant] = true
			var facing := str(prop.get("facing", ""))
			if not CATALOG.DIRECTIONS.has(facing):
				valid_facing = false
			var pos: Vector2i = prop.get("pos", Vector2i(-1, -1))
			var found: Dictionary = gs.interactable_at(pos)
			if found.is_empty() or int(found.get("variant", -1)) != variant:
				interaction_ok = false
		failed += _expect(npc_count >= 4, "route spawns at least four polished NPCs (%d)" % npc_count)
		failed += _expect(variants.size() == npc_count, "NPC types do not repeat on the same route")
		failed += _expect(valid_facing, "every route NPC has a valid directional facing")
		failed += _expect(interaction_ok, "every polished NPC remains interactable")

	if failed == 0:
		print("=== NPC QUALITY OK ===")
		quit(0)
	else:
		print("=== NPC QUALITY FAILED (%d) ===" % failed)
		quit(1)


func _expect(condition: bool, label: String) -> int:
	if condition:
		print("OK    ", label)
		return 0
	print("FAIL  ", label)
	return 1
