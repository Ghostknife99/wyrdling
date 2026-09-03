extends Node

const MAP_W := 64
const MAP_H := 48
const WORLD_COMPOSITION = preload("res://src/dungeon/world_composition.gd")
const NPC_PASS = preload("res://src/dungeon/npc_pass.gd")

var rng := RandomNumberGenerator.new()
var in_run := false
var floor_num := 1
var party: Array = []
var active_index := 0
var grid: Array = []
var player_pos := Vector2i.ZERO
var stairs_pos := Vector2i.ZERO
var wilds: Array = []
var trees: Array = []
var fence: Array = []
var world_props: Array = []
var area_name := "Rift Wilds"
var dungeon_log: PackedStringArray = PackedStringArray()


func _ready() -> void:
	rng.randomize()


func start_run(starter_id: String) -> void:
	if DataDB.creatures.is_empty():
		DataDB._load_data()
	in_run = true
	floor_num = 1
	party = [make_creature(starter_id, 1.0)]
	active_index = 0
	dungeon_log = PackedStringArray()
	generate_floor()
	if party.size() > 0 and party[0] != null:
		push_log("Bound to %s. %s opens ahead." % [party[0].display_name, area_name])


func generate_floor() -> void:
	var result: Dictionary = preload("res://src/dungeon/route_gen.gd").generate(MAP_W, MAP_H, floor_num, rng)
	result = WORLD_COMPOSITION.apply(result, MAP_W, MAP_H, floor_num, rng)
	result = NPC_PASS.apply(result, MAP_W, MAP_H, floor_num, rng)
	grid = result["grid"]
	player_pos = result["start"]
	stairs_pos = result["stairs"]
	trees = result.get("trees", [])
	fence = result.get("fence", [])
	world_props = result.get("props", [])
	area_name = str(result.get("area_name", "Rift Wilds"))
	wilds = []
	var ids: Array[String] = DataDB.wild_ids()
	var mult: float = 1.0 + float(floor_num - 1) * 0.15
	if ids.is_empty():
		push_warning("Wyrdling: no creature data; route has no wilds")
	else:
		for p in result["wilds"]:
			var sid: String = ids[rng.randi_range(0, ids.size() - 1)]
			wilds.append({"pos": p, "creature": make_creature(sid, mult)})
	push_log("%s — tall grass hides encounters." % area_name)


func make_creature(species_id: String, stat_mult: float = 1.0) -> WyrdlingCreature:
	if not DataDB.creatures.has(species_id):
		push_error("Unknown Wyrdling species: " + species_id)
		return null
	var d: Dictionary = DataDB.creatures[species_id]
	var c := WyrdlingCreature.new()
	c.species_id = species_id
	c.display_name = str(d["name"])
	c.type_ids = DataDB.types_of(d)
	if c.type_ids.size() > 0:
		c.type_id = str(c.type_ids[0])
	else:
		c.type_id = str(d.get("type", ""))
	c.max_hp = maxi(1, int(round(float(d["hp"]) * stat_mult)))
	c.hp = c.max_hp
	c.atk = maxi(1, int(round(float(d["atk"]) * stat_mult)))
	c.def = maxi(1, int(round(float(d["def"]) * stat_mult)))
	c.spd = maxi(1, int(round(float(d["spd"]) * stat_mult)))
	c.description = str(d["description"])
	c.moves = []
	for m in d["moves"]:
		c.moves.append(str(m))
	return c


func active() -> WyrdlingCreature:
	if party.is_empty():
		return null
	if active_index < 0 or active_index >= party.size() or party[active_index].is_ko():
		active_index = first_living_index()
	return party[active_index]


func first_living_index() -> int:
	for i in party.size():
		if not party[i].is_ko():
			return i
	return 0


func living_count() -> int:
	var n := 0
	for c in party:
		if not c.is_ko():
			n += 1
	return n


func all_ko() -> bool:
	return living_count() <= 0


func bind_into_party(wild: WyrdlingCreature) -> void:
	wild.hp = wild.max_hp
	party.append(wild)


func replace_member(index: int, wild: WyrdlingCreature) -> String:
	var dropped: String = party[index].display_name
	wild.hp = wild.max_hp
	party[index] = wild
	if party[active_index].is_ko():
		active_index = first_living_index()
	return dropped


func mend_party(ratio: float) -> int:
	var total := 0
	for c in party:
		var before: int = c.hp
		var heal_amt: int = maxi(1, int(ceil(float(c.max_hp) * ratio)))
		c.heal(heal_amt)
		total += c.hp - before
	return total


func descend() -> void:
	floor_num += 1
	mend_party(0.3)
	generate_floor()
	push_log("You descend. The rift knits a little of your wounds.")


func end_run() -> void:
	in_run = false
	party.clear()
	wilds.clear()
	trees.clear()
	fence.clear()
	world_props.clear()
	grid.clear()
	area_name = "Rift Wilds"
	dungeon_log = PackedStringArray()


func push_log(msg: String) -> void:
	dungeon_log.append(msg)
	if dungeon_log.size() > 8:
		dungeon_log = dungeon_log.slice(dungeon_log.size() - 8)


func wild_at(p: Vector2i) -> int:
	for i in wilds.size():
		if wilds[i]["pos"] == p:
			return i
	return -1


func walkable(p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= MAP_W or p.y >= MAP_H:
		return false
	if grid.is_empty():
		return false
	if _walkable_prop_at(p):
		return true
	var t: int = int(grid[p.y][p.x])
	if not (t == 1 or t == 2 or t == 3 or t == 5):
		return false
	return not prop_blocks(p)


func _walkable_prop_at(p: Vector2i) -> bool:
	for prop in world_props:
		if not bool(prop.get("walkable", false)):
			continue
		var blocks: Array = prop.get("blocks", [])
		for cell in blocks:
			if cell == p:
				return true
	return false


func prop_blocks(p: Vector2i) -> bool:
	for f in fence:
		if f["pos"] == p:
			return true
	for nw in trees:
		var tpos: Vector2i = nw
		if p.y == tpos.y + 1 and p.x >= tpos.x and p.x <= tpos.x + 1:
			return true
	for prop in world_props:
		if bool(prop.get("walkable", false)):
			continue
		var blocks: Array = prop.get("blocks", [])
		for cell in blocks:
			if cell == p:
				return true
	return false


func interactable_at(p: Vector2i) -> Dictionary:
	for prop in world_props:
		if not prop.has("interact_pos"):
			continue
		if prop["interact_pos"] == p:
			return prop
	return {}


func occupied_by_wild(p: Vector2i, skip: int = -1) -> bool:
	for i in wilds.size():
		if i == skip:
			continue
		if wilds[i]["pos"] == p:
			return true
	return false


func calc_damage(attacker: WyrdlingCreature, defender: WyrdlingCreature, move_id: String, vary: bool = true) -> Dictionary:
	var md: Dictionary = DataDB.moves.get(move_id, {"power": 30, "type": attacker.type_id, "name": move_id})
	var power: int = int(md["power"])
	var mtype: String = str(md["type"])
	var mod: float = DataDB.type_mod_vs(mtype, defender.type_ids)
	var raw: float = (float(attacker.atk) * float(power)) / (float(maxi(defender.def, 1)) * 1.75)
	var variance: float = rng.randf_range(0.9, 1.1) if vary else 1.0
	var dmg: int = maxi(1, int(round(raw * mod * variance)))
	return {"damage": dmg, "mod": mod, "move": md}


func bind_chance(wild: WyrdlingCreature) -> float:
	var ratio: float = float(wild.hp) / float(maxi(1, wild.max_hp))
	return clampf((1.0 - ratio) * 0.7 + 0.1, 0.1, 0.8)


func flee_chance(a: WyrdlingCreature, b: WyrdlingCreature) -> float:
	return clampf(0.45 + 0.04 * float(a.spd - b.spd), 0.25, 0.85)


func remove_wild_creature(c: WyrdlingCreature) -> void:
	for i in range(wilds.size() - 1, -1, -1):
		if wilds[i]["creature"] == c:
			wilds.remove_at(i)
