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
	failed += _expect(is_equal_approx(db.type_mod("Wisp", "Iron"), 1.5), "Wisp beats Iron 1.5x")
	failed += _expect(is_equal_approx(db.type_mod("Iron", "Bloom"), 1.5), "Iron beats Bloom 1.5x")
	failed += _expect(is_equal_approx(db.type_mod("Bloom", "Dusk"), 1.5), "Bloom beats Dusk 1.5x")
	failed += _expect(is_equal_approx(db.type_mod("Dusk", "Tide"), 1.5), "Dusk beats Tide 1.5x")
	failed += _expect(is_equal_approx(db.type_mod("Tide", "Wisp"), 1.5), "Tide beats Wisp 1.5x")
	failed += _expect(is_equal_approx(db.type_mod("Iron", "Wisp"), 0.7), "Iron resists Wisp 0.7x")
	failed += _expect(is_equal_approx(db.type_mod("Wisp", "Wisp"), 1.0), "same-type 1.0x")
	failed += _expect(is_equal_approx(db.type_mod("Wisp", "Bloom"), 1.0), "skip-one 1.0x")
	failed += _expect(is_equal_approx(db.type_mod("Gleam", "Dusk"), 1.5), "Gleam beats Dusk 1.5x")
	failed += _expect(is_equal_approx(db.type_mod("Dusk", "Void"), 1.5), "Dusk beats Void 1.5x")
	failed += _expect(is_equal_approx(db.type_mod("Void", "Gleam"), 1.5), "Void beats Gleam 1.5x")
	failed += _expect(is_equal_approx(db.type_mod("Dusk", "Gleam"), 0.7), "Dusk resists Gleam 0.7x")
	failed += _expect(is_equal_approx(db.type_mod("Gleam", "Tide"), 1.5), "Gleam beats Tide 1.5x")
	failed += _expect(is_equal_approx(db.type_mod("Tide", "Gleam"), 0.7), "Tide resists Gleam 0.7x")
	failed += _expect(is_equal_approx(db.type_mod("Void", "Iron"), 1.5), "Void beats Iron 1.5x")
	failed += _expect(is_equal_approx(db.type_mod("Iron", "Void"), 0.7), "Iron resists Void 0.7x")
	failed += _expect(is_equal_approx(db.type_mod("Wisp", "Void"), 1.5), "Wisp beats Void 1.5x")
	failed += _expect(is_equal_approx(db.type_mod("Void", "Wisp"), 0.7), "Void resists Wisp 0.7x")
	failed += _expect(str(db.creatures["wickmoth"]["type"]) == "Gleam", "Wickmoth is Gleam")
	failed += _expect(str(db.creatures["veilcrawler"]["type"]) == "Void", "Veilcrawler is Void")

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

	var atk: WyrdlingCreature = gs.make_creature("glimmerling", 1.0)
	var iron: WyrdlingCreature = gs.make_creature("cobbleback", 1.0)
	var super_hit: Dictionary = gs.calc_damage(atk, iron, "gleam", false)
	var resist_hit: Dictionary = gs.calc_damage(iron, atk, "rivet", false)
	failed += _expect(int(super_hit["damage"]) >= 1, "damage at least 1")
	failed += _expect(is_equal_approx(float(super_hit["mod"]), 1.5), "gleam vs Iron is super")
	failed += _expect(is_equal_approx(float(resist_hit["mod"]), 0.7), "rivet vs Wisp resists")

	var full: WyrdlingCreature = gs.make_creature("brinekit", 1.0)
	failed += _expect(is_equal_approx(gs.bind_chance(full), 0.1), "bind ~10% at full HP")
	full.hp = int(full.max_hp / 2.0)
	failed += _expect(gs.bind_chance(full) > 0.4 and gs.bind_chance(full) < 0.5, "bind ~45% at half")
	full.hp = 0
	failed += _expect(is_equal_approx(gs.bind_chance(full), 0.8), "bind ~80% at 0 HP")

	iron.hp = 1
	var hit: Dictionary = gs.calc_damage(atk, iron, "spark_pinch", false)
	iron.take_damage(int(hit["damage"]))
	failed += _expect(iron.is_ko(), "low-HP Iron falls to Spark Pinch")

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
