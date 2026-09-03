extends SceneTree

const OUT := "/workspace/wyrdling/shots"
const W := 1280
const H := 720

var db: Node
var gs: Node
var dungeon: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(W, H)
	db = root.get_node_or_null("DataDB")
	gs = root.get_node_or_null("GameState")
	if db == null or gs == null:
		quit(1)
		return
	if db.creatures.is_empty():
		db._load_data()
	DirAccess.make_dir_recursive_absolute(OUT)

	gs.rng.seed = 7
	gs.start_run("glimmerling")
	gs.wilds = []
	_print_geometry_diagnostics()
	dungeon = load("res://scenes/dungeon.tscn").instantiate()
	root.add_child(dungeon)
	await _wait_frames(16)

	var mid: Vector2i = _best_mid_trail_cell()
	_focus(mid)
	await _wait_frames(10)
	await _capture("route_mid.png")

	var bridge: Dictionary = _find_prop("bridge")
	if not bridge.is_empty():
		var bridge_pos: Vector2i = bridge.get("pos", mid)
		_focus(bridge_pos + Vector2i(1, 4))
		await _wait_frames(10)
		await _capture("route_bridge.png")

	var cave: Dictionary = _find_prop("cave")
	var riftstone: Dictionary = _find_prop("riftstone")
	if not cave.is_empty() and not riftstone.is_empty():
		var cave_pos: Vector2i = cave.get("interact_pos", cave.get("pos", mid))
		var rift_pos: Vector2i = riftstone.get("interact_pos", riftstone.get("pos", mid))
		var landmark_mid := Vector2i(
			int(round((cave_pos.x + rift_pos.x) * 0.5)),
			int(round((cave_pos.y + rift_pos.y) * 0.5))
		)
		_focus(landmark_mid)
		await _wait_frames(10)
		await _capture("route_landmarks.png")

	print("CAPTURED route geometry")
	quit(0)


func _print_geometry_diagnostics() -> void:
	print("GEOMETRY player=", gs.player_pos, " stairs=", gs.stairs_pos)
	for raw in gs.world_props:
		var prop: Dictionary = raw
		var kind: String = str(prop.get("kind", ""))
		if kind in ["bridge", "riftstone", "cave", "lodge"]:
			print("PROP ", kind, " pos=", prop.get("pos"), " interact=", prop.get("interact_pos"), " blocks=", prop.get("blocks", []).size())
	for y: int in range(gs.MAP_H):
		var runs: Array[String] = []
		var run_start: int = -1
		for x: int in range(gs.MAP_W + 1):
			var dirt: bool = x < gs.MAP_W and int(gs.grid[y][x]) == 3
			if dirt and run_start < 0:
				run_start = x
			elif not dirt and run_start >= 0:
				runs.append("%d-%d" % [run_start, x - 1])
				run_start = -1
		if not runs.is_empty():
			print("DIRT y=", y, " runs=", ",".join(runs))


func _best_mid_trail_cell() -> Vector2i:
	var target := Vector2i(int(gs.MAP_W / 2), int(gs.MAP_H / 2))
	var best: Vector2i = gs.player_pos
	var best_score := 999999
	for y: int in range(9, gs.MAP_H - 11):
		for x: int in range(5, gs.MAP_W - 5):
			if int(gs.grid[y][x]) != 3:
				continue
			var p := Vector2i(x, y)
			if not gs.walkable(p):
				continue
			var score := int(p.distance_to(target) * 10.0)
			if score < best_score:
				best_score = score
				best = p
	return best


func _find_prop(kind: String) -> Dictionary:
	for raw in gs.world_props:
		var prop: Dictionary = raw
		if str(prop.get("kind", "")) == kind:
			return prop
	return {}


func _focus(target: Vector2i) -> void:
	var best: Vector2i = target
	if not gs.walkable(best):
		var best_distance: float = 99999.0
		for radius: int in range(1, 7):
			for y: int in range(target.y - radius, target.y + radius + 1):
				for x: int in range(target.x - radius, target.x + radius + 1):
					var p := Vector2i(x, y)
					if not gs.walkable(p):
						continue
					var d: float = p.distance_to(target)
					if d < best_distance:
						best_distance = d
						best = p
			if best_distance < 99999.0:
				break
	gs.player_pos = best
	dungeon.last_dir = "up"
	if dungeon.has_method("_refresh"):
		dungeon._refresh()
	if dungeon.has_method("_update_camera"):
		dungeon._update_camera()


func _wait_frames(n: int) -> void:
	for _i in n:
		await process_frame
		await RenderingServer.frame_post_draw


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png("%s/%s" % [OUT, filename])
	if err != OK:
		quit(1)
