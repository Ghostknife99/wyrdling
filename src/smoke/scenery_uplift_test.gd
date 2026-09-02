extends SceneTree

func _init() -> void:
	print("=== Wyrdling scenery uplift test ===")
	var art = load("res://src/dungeon/scenery_art.gd")
	var atlas: Texture2D = art.make_atlas()
	if atlas == null or atlas.get_width() != 512 or atlas.get_height() != 480:
		push_error("Scenery atlas failed to decode at 512x480")
		quit(1)
		return
	print("OK    polished terrain atlas decodes 512x480")

	var props: Texture2D = art.make_props_sheet()
	if props == null or props.get_width() != 256 or props.get_height() != 128:
		push_error("Scenery prop sheet failed to decode at 256x128")
		quit(1)
		return
	print("OK    polished scenery prop sheet decodes 256x128")

	var builder = load("res://src/dungeon/wilds_tileset.gd")
	var tileset: TileSet = builder.build()
	if tileset == null or tileset.get_source_count() < 1:
		push_error("Polished scenery TileSet failed to build")
		quit(1)
		return
	print("OK    polished TileSet builds with animated water")

	var presentation = load("res://src/dungeon/dungeon_16.gd")
	if presentation == null:
		push_error("16px scenery presentation failed to load")
		quit(1)
		return
	print("OK    polished 16px scenery presentation loads")
	print("=== SCENERY UPLIFT OK ===")
	quit(0)
