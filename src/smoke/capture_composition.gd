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
	dungeon = load("res://scenes/dungeon.tscn").instantiate()
	root.add_child(dungeon)
	await _wait_frames(16)

	var bridge := _find_prop("bridge")
	var riftstone := _find_prop("riftstone")
	if bridge.is_empty() or riftstone.is_empty():
		print("FAIL composition landmarks missing")
		quit(1)
		return

	_focus_prop(bridge)
	await _wait_frames(10)
	await _capture("composition_bridge.png")

	_focus_prop(riftstone)
	await _wait_frames(10)
	await _capture("composition_riftstone.png")

	print("CAPTURED composition landmarks")
	quit(0)


func _find_prop(kind: String) -> Dictionary:
	for raw in gs.world_props:
		var prop: Dictionary = raw
		if str(prop.get("kind", "")) == kind:
			return prop
	return {}


func _focus_prop(prop: Dictionary) -> void:
	var target: Vector2i = prop.get("interact_pos", prop.get("pos", gs.player_pos))
	var best := gs.player_pos
	var best_distance := 99999.0
	for radius: int in range(0, 6):
		for y: int in range(target.y - radius, target.y + radius + 1):
			for x: int in range(target.x - radius, target.x + radius + 1):
				var p := Vector2i(x, y)
				if not gs.walkable(p):
					continue
				var d := p.distance_to(target)
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
	print("focus ", prop.get("kind", "prop"), " player=", best, " target=", target)


func _wait_frames(n: int) -> void:
	for _i in n:
		await process_frame
		await RenderingServer.frame_post_draw


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var path := "%s/%s" % [OUT, filename]
	var err := img.save_png(path)
	print("wrote ", path, " err=", err)
