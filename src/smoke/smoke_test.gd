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
	failed += _expect(db.creatures.size() == 8, "loaded 8 creatures")
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

	gs.descend()
	var wc2: int = gs.wilds.size()
	failed += _expect(gs.floor_num == 2, "descended to floor 2")
	failed += _expect(wc2 >= 4 and wc2 <= 8, "floor 2 wilds 4-8 (got %d)" % wc2)

	var atk: WyrdlingCreature = gs.make_creature("cobbleback", 1.0)
	var nature: WyrdlingCreature = gs.make_creature("briarseed", 1.0)
	var super_hit: Dictionary = gs.calc_damage(atk, nature, "rivet", false)
	var resist_hit: Dictionary = gs.calc_damage(nature, atk, "thorn_shot", false)
	failed += _expect(int(super_hit["damage"]) >= 1, "damage at least 1")
	failed += _expect(is_equal_approx(float(super_hit["mod"]), 1.5), "Metal vs Nature is super")
	failed += _expect(is_equal_approx(float(resist_hit["mod"]), 0.7), "Nature vs Metal resists")

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


func _expect(cond: bool, label: String) -> int:
	if cond:
		print("OK    ", label)
		return 0
	print("FAIL  ", label)
	return 1
