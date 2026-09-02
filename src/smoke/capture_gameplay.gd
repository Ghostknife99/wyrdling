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
	await _clear_content()
	var dungeon: Node2D = load("res://scenes/dungeon.tscn").instantiate()
	root.add_child(dungeon)
	await _wait_frames(16)

	var parked: Array = gs.wilds
	gs.wilds = []
	_walk_north_along_path(dungeon, 16)
	await _wait_frames(10)
	await _capture_pair()
	print("player_pos=", gs.player_pos, " stairs=", gs.stairs_pos)
	gs.wilds = parked

	if not dungeon.combat_open:
		if gs.wilds.is_empty():
			print("FAIL no wilds")
			quit(1)
			return
		dungeon._open_combat(0)
	await _wait_frames(16)
	await _capture("gameplay_combat.png")

	print("CAPTURED title/starter/wilds/combat into ", OUT)
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


func _walk_north_along_path(dungeon: Node, steps: int) -> void:
	var last := Vector2i(0, -1)
	for _i in steps:
		if dungeon.combat_open:
			return
		var from: Vector2i = gs.player_pos
		var chosen := Vector2i.ZERO
		var best := -99999
		var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]
		for d in dirs:
			var np: Vector2i = from + d
			if np == gs.stairs_pos:
				continue
			if not gs.walkable(np):
				continue
			if gs.wild_at(np) >= 0:
				continue
			var t: int = int(gs.grid[np.y][np.x])
			var score: int = -np.y * 4
			if t == 3:
				score += 20
			elif t == 1:
				score += 2
			if d == last:
				score += 3
			if d.y > 0:
				score -= 30
			if score > best:
				best = score
				chosen = d
		if chosen == Vector2i.ZERO:
			return
		last = chosen
		if chosen.x > 0:
			dungeon.last_dir = "right"
		elif chosen.x < 0:
			dungeon.last_dir = "left"
		elif chosen.y < 0:
			dungeon.last_dir = "up"
		else:
			dungeon.last_dir = "down"
		dungeon._try_step(chosen)
