extends SceneTree

const OUT := "/workspace/wyrdling/shots"
const W := 1280
const H := 720

var db: Node
var gs: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(W, H)
	db = root.get_node_or_null("DataDB")
	gs = root.get_node_or_null("GameState")
	if db == null or gs == null:
		print("FAIL autoloads missing ", root.get_children())
		quit(1)
		return
	if db.creatures.is_empty():
		db._load_data()
	DirAccess.make_dir_recursive_absolute(OUT)

	await _shot_scene("res://scenes/title.tscn", "gameplay_title.png")
	await _shot_scene("res://scenes/starter_select.tscn", "gameplay_starter.png")

	gs.rng.seed = 7
	gs.start_run("glimmerling")
	var start: Vector2i = gs.player_pos
	await _clear_content()
	var dungeon: Node2D = load("res://scenes/dungeon.tscn").instantiate()
	root.add_child(dungeon)
	await _wait_frames(16)
	if not dungeon.has_method("_open_combat"):
		print("FAIL dungeon script did not attach")
		quit(1)
		return

	var parked: Array = gs.wilds
	gs.wilds = []
	_pan_along_dirt(dungeon, 20)
	_stand_under_canopy(dungeon, start)
	await _wait_frames(10)
	await _capture_pair()
	print("player_pos=", gs.player_pos, " stairs=", gs.stairs_pos)

	if _focus_first_npc(dungeon):
		await _wait_frames(10)
		await _capture("gameplay_npc.png")
	else:
		print("FAIL no polished NPC available for live capture")
		quit(1)
		return

	gs.wilds = parked
	if not dungeon.combat_open:
		if gs.wilds.is_empty():
			print("FAIL no wilds")
			quit(1)
			return
		dungeon._open_combat(0)
	await _wait_frames(16)
	await _capture("gameplay_combat.png")

	print("CAPTURED title/starter/wilds/npc/combat into ", OUT)
	quit(0)


func _shot_scene(path: String, filename: String) -> void:
	await _clear_content()
	var n: Node = load(path).instantiate()
	root.add_child(n)
	if n is Control:
		n.set_anchors_preset(Control.PRESET_FULL_RECT)
		n.size = Vector2(W, H)
	await _wait_frames(16)
	await _capture(filename)


func _clear_content() -> void:
	for c in root.get_children():
		if c.name == "DataDB" or c.name == "GameState":
			continue
		c.free()
	await process_frame


func _wait_frames(n: int) -> void:
	for i in n:
		await process_frame
		await RenderingServer.frame_post_draw


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var tex: ViewportTexture = root.get_texture()
	var img: Image = tex.get_image()
	var path := "%s/%s" % [OUT, filename]
	var err := img.save_png(path)
	print("wrote ", path, " ", img.get_width(), "x", img.get_height(), " err=", err)


func _capture_pair() -> void:
	await RenderingServer.frame_post_draw
	var tex: ViewportTexture = root.get_texture()
	var img: Image = tex.get_image()
	for filename in ["gameplay_wilds.png", "gameplay_dungeon.png"]:
		var path := "%s/%s" % [OUT, filename]
		var err := img.save_png(path)
		print("wrote ", path, " ", img.get_width(), "x", img.get_height(), " err=", err)


func _focus_first_npc(dungeon: Node) -> bool:
	var npc: Dictionary = {}
	for raw in gs.world_props:
		var prop: Dictionary = raw
		if str(prop.get("kind", "")) == "npc":
			npc = prop
			break
	if npc.is_empty():
		return false

	var target: Vector2i = npc.get("pos", Vector2i.ZERO)
	var approaches: Array[Vector2i] = [
		target + Vector2i(0, 2),
		target + Vector2i(2, 0),
		target + Vector2i(-2, 0),
		target + Vector2i(0, -2),
		target + Vector2i(0, 1),
		target + Vector2i(1, 0),
		target + Vector2i(-1, 0),
		target + Vector2i(0, -1),
	]
	var chosen: Vector2i = gs.player_pos
	var found := false
	for p: Vector2i in approaches:
		if gs.walkable(p):
			chosen = p
			found = true
			break
	if not found:
		return false

	gs.player_pos = chosen
	var delta: Vector2i = target - chosen
	if absi(delta.x) >= absi(delta.y):
		dungeon.last_dir = "right" if delta.x > 0 else "left"
	else:
		dungeon.last_dir = "down" if delta.y > 0 else "up"
	if dungeon.has_method("_refresh"):
		dungeon._refresh()
	if dungeon.has_method("_update_camera"):
		dungeon._update_camera()
	print("NPC QA focus variant=", npc.get("variant", -1), " name=", npc.get("name", "NPC"), " npc=", target, " player=", chosen)
	return true


func _pan_along_dirt(dungeon: Node, steps: int) -> void:
	for _i in steps:
		var from: Vector2i = gs.player_pos
		if from == gs.stairs_pos:
			break
		var best: Vector2i = from
		var best_score := -100000
		var found := false
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
			var np: Vector2i = from + d
			if np == gs.stairs_pos:
				continue
			if not gs.walkable(np):
				continue
			var t: int = int(gs.grid[np.y][np.x])
			var score: int = -np.y * 10
			if t == 3:
				score += 28
			if np.y < from.y:
				score += 36
			if np.y > from.y:
				score -= 50
			if score > best_score:
				best_score = score
				best = np
				found = true
		if not found or best == from:
			break
		if best.x > from.x:
			dungeon.last_dir = "right"
		elif best.x < from.x:
			dungeon.last_dir = "left"
		elif best.y < from.y:
			dungeon.last_dir = "up"
		else:
			dungeon.last_dir = "down"
		gs.player_pos = best
	if dungeon.has_method("_refresh"):
		dungeon._refresh()


func _stand_under_canopy(dungeon: Node, start: Vector2i) -> void:
	var origin := Vector2i(start.x, clampi(start.y - 20, 12, gs.MAP_H - 14))
	var best := origin
	var best_score := -1000000
	for nw in gs.trees:
		var tpos: Vector2i = nw
		for dx in range(2):
			var p := Vector2i(tpos.x + dx, tpos.y)
			if not gs.walkable(p):
				continue
			if p.distance_to(origin) > 10:
				continue
			var score: int = 80 - int(p.distance_to(origin)) * 8
			for dy2 in range(-5, 6):
				for dx2 in range(-7, 8):
					var q := Vector2i(p.x + dx2, p.y + dy2)
					if q.x < 0 or q.y < 0 or q.x >= gs.MAP_W or q.y >= gs.MAP_H:
						continue
					var tt: int = int(gs.grid[q.y][q.x])
					if tt == 4:
						score += 8
					if tt == 3:
						score += 3
			for f in gs.fence:
				if f["pos"].distance_to(p) <= 8:
					score += 6
			if score > best_score:
				best_score = score
				best = p
	if best_score < 0:
		best = origin
		if not gs.walkable(best):
			best = start
	gs.player_pos = best
	dungeon.last_dir = "down"
	if dungeon.has_method("_refresh"):
		dungeon._refresh()
	print("canopy stand ", best, " origin=", origin, " start=", start, " score=", best_score)
