extends SceneTree

func _initialize() -> void:
	print("=== Wyrdling smoke test ===")
	var db: Node = root.get_node_or_null("DataDB")
	var gs: Node = root.get_node_or_null("GameState")
	if db == null or gs == null:
		print("FAIL  autoloads missing. children=", root.get_children())
		quit(1)
		return
	var failed := 0
	if db.creatures.is_empty():
		db._load_data()
	failed += _expect(db.creatures.size() == 170, "loaded 170 creatures")
	failed += _expect(db.moves.size() >= 15, "loaded moves")
	failed += _expect(db.starters.size() == 3, "three starters")
	failed += _expect(db.TYPES.size() == 16, "16 types")
	failed += _expect(is_equal_approx(db.type_mod("Light", "Blight"), 1.5), "Light beats Blight")
	failed += _expect(is_equal_approx(db.type_mod("Void", "Light"), 1.5), "Void beats Light")
	failed += _expect(is_equal_approx(db.type_mod("Light", "Void"), 0.7), "Light resists Void")
	failed += _expect(is_equal_approx(db.type_mod("Flame", "Metal"), 1.5), "Flame beats Metal")
	failed += _expect(is_equal_approx(db.type_mod("Metal", "Flame"), 0.7), "Metal resists Flame")
	failed += _expect(is_equal_approx(db.type_mod("Tide", "Flame"), 1.5), "Tide beats Flame")
	failed += _expect(is_equal_approx(db.type_mod("Nature", "Terra"), 1.5), "Nature beats Terra")
	failed += _expect(is_equal_approx(db.type_mod("Metal", "Nature"), 1.5), "Metal beats Nature")
	failed += _expect(is_equal_approx(db.type_mod("Nature", "Metal"), 0.7), "Nature resists Metal")
	failed += _expect(is_equal_approx(db.type_mod("Primal", "Mind"), 1.5), "Primal beats Mind")
	failed += _expect(is_equal_approx(db.type_mod("Arcane", "Storm"), 1.5), "Arcane beats Storm")
	failed += _expect(is_equal_approx(db.type_mod("Light", "Light"), 1.0), "same-type 1.0x")
	failed += _expect(is_equal_approx(db.type_mod("Light", "Flame"), 1.0), "unrelated 1.0x")
	failed += _expect(str(db.creatures["glimmerling"]["type"]) == "Light", "Glimmerling is Light")
	failed += _expect(str(db.creatures["wickmoth"]["type"]) == "Light", "Wickmoth is Light")
	failed += _expect(str(db.creatures["cobbleback"]["type"]) == "Metal", "Cobbleback is Metal")
	failed += _expect(str(db.creatures["nailbit"]["type"]) == "Metal", "Nailbit is Metal")
	failed += _expect(str(db.creatures["briarseed"]["type"]) == "Nature", "Briarseed is Nature")
	failed += _expect(str(db.creatures["marrowl"]["type"]) == "Spirit", "Marrowl is Spirit")
	failed += _expect(str(db.creatures["veilcrawler"]["type"]) == "Void", "Veilcrawler is Void")
	failed += _expect(str(db.creatures["brinekit"]["type"]) == "Tide", "Brinekit is Tide")

	var n_leg := 0
	var n_myth := 0
	for id in db.creature_order:
		var rar := str(db.creatures[id].get("rarity", ""))
		if rar == "legendary":
			n_leg += 1
		elif rar == "mythical":
			n_myth += 1
	failed += _expect(n_leg == 8, "exactly 8 legendaries (got %d)" % n_leg)
	failed += _expect(n_myth == 3, "exactly 3 mythicals (got %d)" % n_myth)

	for t in db.TYPES:
		var n := 0
		for id in db.creature_order:
			if str(db.creatures[id]["type"]) == t:
				n += 1
		failed += _expect(n >= 8 and n <= 12, "%s primary count %d" % [t, n])

	gs.rng.seed = 42
	gs.start_run("glimmerling")
	failed += _expect(gs.party.size() == 1, "starter party size 1")
	failed += _expect(gs.party[0].display_name == "Glimmerling", "starter is Glimmerling")
	failed += _expect(gs.floor_num == 1, "floor 1")
	failed += _expect(not gs.grid.is_empty(), "grid generated")
	failed += _expect(gs.walkable(gs.player_pos), "player on walkable tile")
	failed += _expect(int(gs.grid[gs.stairs_pos.y][gs.stairs_pos.x]) == 2, "stairs tile placed")
	var wc: int = gs.wilds.size()
	failed += _expect(wc >= 4 and wc <= 8, "4-8 wilds (got %d)" % wc)
	failed += _expect(gs.wild_at(gs.player_pos) < 0, "no wild on player")
	failed += _expect(_no_legend_myth(gs, db), "floor 1 wilds exclude legendary/mythical")

	gs.descend()
	var wc2: int = gs.wilds.size()
	failed += _expect(gs.floor_num == 2, "descended to floor 2")
	failed += _expect(wc2 >= 4 and wc2 <= 8, "floor 2 wilds 4-8 (got %d)" % wc2)
	failed += _expect(_no_legend_myth(gs, db), "floor 2 wilds exclude legendary/mythical")
	var later_ok := true
	for _i in 4:
		gs.descend()
		if not _no_legend_myth(gs, db):
			later_ok = false
			failed += _expect(false, "floor %d wilds exclude legendary/mythical" % gs.floor_num)
			break
	if later_ok:
		failed += _expect(true, "floors 3-6 wilds exclude legendary/mythical")

	var atk: WyrdlingCreature = gs.make_creature("cobbleback", 1.0)
	var nature: WyrdlingCreature = gs.make_creature("briarseed", 1.0)
	var super_hit: Dictionary = gs.calc_damage(atk, nature, "rivet", false)
	var resist_hit: Dictionary = gs.calc_damage(nature, atk, "thorn_shot", false)
	failed += _expect(int(super_hit["damage"]) >= 1, "damage at least 1")
	failed += _expect(is_equal_approx(float(super_hit["mod"]), 1.5), "Metal vs Nature is super")
	failed += _expect(is_equal_approx(float(resist_hit["mod"]), 0.7), "Nature vs Metal resists")

	var gelvra: WyrdlingCreature = gs.make_creature("gelvra", 1.0)
	failed += _expect(gelvra.type_ids.size() == 2, "Gelvra is dual-type")
	failed += _expect(is_equal_approx(db.type_mod_vs("Light", gelvra.type_ids), 0.7), "Light vs Gelvra (Void/Frost) 0.7")
	var sol: WyrdlingCreature = gs.make_creature("solcairn", 1.0)
	failed += _expect(sol.type_ids.size() == 2, "Solcairn is dual-type")
	failed += _expect(is_equal_approx(db.type_mod_vs("Blight", sol.type_ids), 1.05), "Blight vs Solcairn 0.7x1.5=1.05")
	var sig: WyrdlingCreature = gs.make_creature("sigildra", 1.0)
	failed += _expect(sig.type_ids.size() == 2, "Sigildra is dual-type")
	failed += _expect(is_equal_approx(db.type_mod_vs("Flame", sig.type_ids), 1.5), "Flame vs Sigildra (Metal/Arcane) 1.5")

	var full: WyrdlingCreature = gs.make_creature("brinekit", 1.0)
	failed += _expect(is_equal_approx(gs.bind_chance(full), 0.1), "bind ~10% at full HP")
	full.hp = int(full.max_hp / 2.0)
	failed += _expect(gs.bind_chance(full) > 0.4 and gs.bind_chance(full) < 0.5, "bind ~45% at half")
	full.hp = 0
	failed += _expect(is_equal_approx(gs.bind_chance(full), 0.8), "bind ~80% at 0 HP")

	atk.hp = 1
	var pinch: WyrdlingCreature = gs.make_creature("glimmerling", 1.0)
	var hit: Dictionary = gs.calc_damage(pinch, atk, "spark_pinch", false)
	atk.take_damage(int(hit["damage"]))
	failed += _expect(atk.is_ko(), "low-HP Metal falls to Spark Pinch")

	if failed == 0:
		print("=== SMOKE OK ===")
		quit(0)
	else:
		print("=== SMOKE FAILED (%d) ===" % failed)
		quit(1)


func _no_legend_myth(gs: Node, db: Node) -> bool:
	for w in gs.wilds:
		var c: WyrdlingCreature = w["creature"]
		var rar := str(db.creatures[c.species_id].get("rarity", ""))
		if rar == "legendary" or rar == "mythical":
			return false
	return true


func _expect(cond: bool, label: String) -> int:
	if cond:
		print("OK    ", label)
		return 0
	print("FAIL  ", label)
	return 1
